import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission, LocationAccuracy, LocationSettings, Position;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/responder_models.dart';
import '../services/supabase_service.dart';
import '../services/onesignal_service.dart';
import '../utils/synopsis_helper.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  final MapController _mapController = MapController();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy • h:mm a');
  
  // Open Field coordinates (walkable area)
  static const latlong.LatLng _openFieldCenter = latlong.LatLng(14.262689, 121.398464);

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _updatingAvailability = false;
  bool _updatingLocation = false;
  String? _errorMessage;
  String? _updatingAssignmentId;
  int _selectedIndex = 0;

  ResponderProfile? _profile;
  List<ResponderAssignment> _assignments = [];
  CoordinatePoint? _deviceLocation;
  CoordinatePoint? _pendingMapTarget;
  String? _pendingMapLabel;
  List<latlong.LatLng> _routePolyline = [];
  bool _isFetchingRoute = false;
  String? _routeError;
  double? _routeDistanceKm;
  double? _routeDurationMin;

  // Realtime walking: position stream so map keeps updating as responder moves
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastRouteRecalcTime;
  CoordinatePoint? _lastRouteRecalcOrigin;
  DateTime? _lastSupabaseLocationUpdate;

  String? _responderSynopsisMessage;

  bool _isSecurityGuard = false;
  List<Map<String, dynamic>> _ongoingReports = [];
  bool _ongoingLoading = false;

  // Realtime subscriptions
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _reportsChannel;
  RealtimeChannel? _assignmentsChannel;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _mapController.dispose();
    _notificationsChannel?.unsubscribe();
    _reportsChannel?.unsubscribe();
    _assignmentsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    if (_profile == null) return;

    // Subscribe to notifications table for this responder
    _notificationsChannel = SupabaseService.client
        .channel('responder-notifications-mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_type',
            value: 'responder',
          ),
          callback: (payload) {
            final notification = payload.newRecord;
            if (notification['target_id'] == _profile?.id) {
              debugPrint('🔔 New notification received: $notification');
              _showNotificationSnackbar(notification);
              _syncNotifications();
            }
          },
        )
        .subscribe();

    // Subscribe to reports table
    _reportsChannel = SupabaseService.client
        .channel('responder-reports-mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reports',
          callback: (payload) {
            debugPrint('📢 Report updated: ${payload.newRecord}');
            _loadPage(showLoader: false);
          },
        )
        .subscribe();

    // Subscribe to assignments table
    _assignmentsChannel = SupabaseService.client
        .channel('responder-assignments-mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assignment',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'responder_id',
            value: _profile!.id,
          ),
          callback: (payload) {
            debugPrint('📋 Assignment updated: ${payload.newRecord}');
            _loadPage(showLoader: false);
          },
        )
        .subscribe();

    debugPrint('✅ Realtime subscriptions setup complete for responder ${_profile?.id}');
  }

  Future<void> _syncNotifications() async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'sync-notifications',
        body: {
          'limit': 20,
          'unreadOnly': false,
        },
      );

      debugPrint('✅ Synced notifications: ${response.data}');
    } catch (e) {
      debugPrint('❌ Failed to sync notifications: $e');
    }
  }

  void _showNotificationSnackbar(Map<String, dynamic> notification) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['title'] ?? 'New Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (notification['message'] != null)
              Text(notification['message']),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _loadPage({bool showLoader = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoader) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('Please sign in to access the responder dashboard.');
      }

      // Ensure OneSignal player ID is registered (helps new responders receive assignment notifications)
      OneSignalService().retrySavePlayerIdToSupabase();

      var profileRaw = await SupabaseService.client
          .from('responder')
          .select('id, name, role, status, phone, is_available, last_location, leader_id, team_name, leader:leader_id(name)')
          .eq('user_id', userId)
          .maybeSingle();

      // If no responder row but user is a responder (e.g. just verified), create one so dashboard can load
      if (profileRaw == null) {
        final userProfile = await SupabaseService.client
            .from('user_profiles')
            .select('role, name')
            .eq('user_id', userId)
            .maybeSingle();
        final userRole = userProfile?['role'] as String?;
        if (userRole == 'responder') {
          final name = userProfile?['name'] as String? ?? SupabaseService.currentUser?.email?.split('@').first ?? 'Responder';
          final phonePlaceholder = 'mobile-$userId';
          final insertResult = await SupabaseService.client
              .from('responder')
              .insert({
                'user_id': userId,
                'name': name,
                'phone': phonePlaceholder,
                'role': 'Emergency Responder',
                'status': 'active',
                'is_available': true,
              })
              .select('id, name, role, status, phone, is_available, last_location, leader_id, team_name, leader:leader_id(name)')
              .maybeSingle();
          if (insertResult != null) {
            profileRaw = insertResult;
          }
        }
        if (profileRaw == null) {
          throw Exception(
            'No responder profile is linked to this account yet. Please contact an administrator.',
          );
        }
      }

      final profileMap = Map<String, dynamic>.from(profileRaw);
      final profile = ResponderProfile.fromMap(profileMap);

      // Security guards see "Ongoing incidents" for awareness and cooperation
      bool isSecurityGuard = false;
      try {
        final profileRow = await SupabaseService.client
            .from('user_profiles')
            .select('user_type')
            .eq('user_id', userId)
            .maybeSingle();
        final userType = profileRow?['user_type'] as String?;
        isSecurityGuard = (userType ?? '').toLowerCase() == 'security_guard';
      } catch (_) {}

      final assignmentsResponse = await SupabaseService.client
          .from('assignment')
          .select('''
            id,
            status,
            assigned_at,
            accepted_at,
            completed_at,
            notes,
            responder_id,
            reports:reports!assignment_report_id_fkey (
              id,
              type,
              message,
              status,
              location,
              reporter_name,
              image_path,
              created_at
            )
          ''')
          .eq('responder_id', profile.id)
          .order('assigned_at', ascending: false);

      final assignmentsRaw = assignmentsResponse as List<dynamic>? ?? [];
      final assignments = assignmentsRaw
          .whereType<Map<String, dynamic>>()
          .map(ResponderAssignment.fromMap)
          .toList();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _assignments = assignments;
        _isSecurityGuard = isSecurityGuard;
        _isLoading = false;
        _isRefreshing = false;
      });

      // Load readiness synopsis (prepare / be ready / inspect)
      _loadResponderSynopsis();

      // Setup realtime subscriptions after profile is loaded
      _setupRealtimeSubscriptions();

      // Prefer live device GPS; if we don't have it yet, try to capture once here.
      if (_deviceLocation != null) {
        _animateMapTo(_deviceLocation!);
      } else {
        // This will ask for permission if needed and set _deviceLocation from the phone.
        _captureLocation();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadResponderSynopsis() async {
    try {
      final reports = await SupabaseService.getReportsForSynopsis();
      final synopsis = SynopsisHelper.getSynopsisForRole(reports, 'responder');
      if (mounted) {
        setState(() {
          _responderSynopsisMessage = synopsis['responderMessage'];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _responderSynopsisMessage = 'Keep equipment inspected and stay ready for anything.';
        });
      }
    }
  }

  List<ResponderAssignment> get _activeAssignments =>
      _assignments.where((assignment) => assignment.isActive).toList();

  List<ResponderAssignment> get _completedAssignments =>
      _assignments.where((assignment) => assignment.isCompleted).toList();

  double? get _averageResponseMinutes {
    final completedWithDuration = _completedAssignments
        .map((assignment) => assignment.responseDuration)
        .whereType<Duration>()
        .toList();

    if (completedWithDuration.isEmpty) {
      return null;
    }

    final totalMinutes =
        completedWithDuration.fold<double>(0, (sum, duration) => sum + duration.inMinutes);
    return totalMinutes / completedWithDuration.length;
  }

  Future<void> _toggleAvailability() async {
    final responder = _profile;
    if (responder == null || _updatingAvailability) return;

    setState(() => _updatingAvailability = true);

    try {
      final newAvailability = !responder.isAvailable;
      await SupabaseService.client
          .from('responder')
          .update({'is_available': newAvailability})
          .eq('id', responder.id);

      if (!mounted) return;
      setState(() {
        _profile = responder.copyWith(
          isAvailable: newAvailability,
          status: newAvailability ? 'available' : 'unavailable',
        );
        _updatingAvailability = false;
      });
      _showSnack('Status updated to ${newAvailability ? 'Available' : 'Unavailable'}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingAvailability = false);
      _showSnack('Failed to update availability: ${_cleanError(e)}', isError: true);
    }
  }

  Future<void> _updateAssignmentStatus(
    ResponderAssignment assignment,
    String newStatus, {
    String? notes,
  }) async {
    if (_updatingAssignmentId != null) return;
    setState(() => _updatingAssignmentId = assignment.id);

    try {
      final responderId = _profile?.id;
      if (responderId == null) {
        _showSnack('Responder ID not found', isError: true);
        return;
      }

      // Handle 'accepted' status - use accept-assignment function
      if (newStatus == 'accepted' && assignment.status == 'assigned') {
        debugPrint('📞 Calling accept-assignment edge function...');
        final response = await SupabaseService.client.functions.invoke(
          'accept-assignment',
          body: {
            'assignment_id': assignment.id,
            'responder_id': responderId,
            'action': 'accept',
          },
        );

        if (response.data == null || response.data['success'] != true) {
          throw Exception(response.data?['error'] ?? 'Failed to accept assignment');
        }

        debugPrint('✅ Assignment accepted via edge function: ${response.data}');
      } 
      // Handle other status updates - use update-assignment-status function
      else if (['enroute', 'on_scene', 'resolved'].contains(newStatus)) {
        debugPrint('📞 Calling update-assignment-status edge function for status: $newStatus...');
        final body = <String, dynamic>{
          'assignment_id': assignment.id,
          'responder_id': responderId,
          'status': newStatus,
        };
        if (notes != null && notes.trim().isNotEmpty) {
          body['notes'] = notes.trim();
        }
        final response = await SupabaseService.client.functions.invoke(
          'update-assignment-status',
          body: body,
        );

        if (response.data == null || response.data['success'] != true) {
          throw Exception(response.data?['error'] ?? 'Failed to update assignment status');
        }

        debugPrint('✅ Assignment status updated via edge function: ${response.data}');
      } 
      // Fallback for other statuses (shouldn't happen, but keep for safety)
      else {
        debugPrint('⚠️ Status $newStatus not handled by edge functions, updating directly');
        final now = DateTime.now().toUtc().toIso8601String();
        final Map<String, dynamic> updateData = {
          'status': newStatus,
          'updated_at': now,
        };

        if (newStatus == 'resolved' || newStatus == 'completed') {
          updateData['completed_at'] = now;
        }
        if (notes != null && notes.trim().isNotEmpty) {
          updateData['notes'] = notes.trim();
        }

        await SupabaseService.client
            .from('assignment')
            .update(updateData)
            .eq('id', assignment.id);

        if ((newStatus == 'resolved' || newStatus == 'completed') &&
            assignment.report.id.isNotEmpty) {
          try {
            await SupabaseService.client
                .from('reports')
                .update({'status': 'completed'})
                .eq('id', assignment.report.id);
          } catch (_) {
            // If the report update fails we continue; assignment remains updated.
          }
        }
      }

      await _loadPage(showLoader: false);
      _showSnack('Assignment marked as ${newStatus.toUpperCase()}');
    } catch (e) {
      debugPrint('❌ Error updating assignment status: $e');
      _showSnack('Failed to update assignment: ${_cleanError(e)}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingAssignmentId = null);
      }
    }
  }

  Future<void> _showResolveNoteDialog(ResponderAssignment assignment) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a note about what happened (optional). This will be saved with the emergency report.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'e.g. Arrived on scene, provided first aid. Patient transferred to hospital.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateAssignmentStatus(
                assignment,
                'resolved',
                notes: controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _captureLocation() async {
    final responder = _profile;
    if (responder == null || _updatingLocation) return;

    setState(() => _updatingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to share your position.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final payload = {
        'lat': position.latitude,
        'lng': position.longitude,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final geoJsonPoint = {
        'type': 'Point',
        'coordinates': [position.longitude, position.latitude],
        'properties': payload,
      };

      await SupabaseService.client
          .from('responder')
          .update({'last_location': geoJsonPoint})
          .eq('id', responder.id);

      final point =
          CoordinatePoint(latitude: position.latitude, longitude: position.longitude);

      if (!mounted) return;

      setState(() {
        _profile = responder.copyWith(lastLocation: geoJsonPoint);
        _deviceLocation = point;
        _updatingLocation = false;
      });

      _animateMapTo(point);
      _showSnack('Location updated');

      if (_pendingMapTarget != null) {
        _lastRouteRecalcTime = DateTime.now();
        _lastRouteRecalcOrigin = point;
        _fetchRoute(point, _pendingMapTarget!);
      }
      _startLocationStream();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingLocation = false);
      _showSnack('Failed to capture location: ${_cleanError(e)}', isError: true);
    }
  }

  void _animateMapTo(CoordinatePoint point) {
    final target = latlong.LatLng(point.latitude, point.longitude);
    try {
      _mapController.move(target, 15);
    } catch (_) {
      // Map might not be mounted yet. Ignore.
    }
  }

  /// Start real-time position updates so the map keeps changing as the responder walks.
  void _startLocationStream() {
    if (_positionStreamSubscription != null || _profile == null) return;

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // meters – update often so small movements feel real-time
    );
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      if (!mounted) return;
      final point = CoordinatePoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      setState(() => _deviceLocation = point);

      // Real-time map follow: when on Map View tab, keep camera centered on user with automatic zoom
      final isOnMapTab = _selectedIndex == (_isSecurityGuard ? 3 : 2);
      if (isOnMapTab) {
        try {
          _mapController.move(
            latlong.LatLng(point.latitude, point.longitude),
            18, // zoomed in like campus-level view so route and pins are clear
          );
        } catch (_) {}
      }

      // Recalculate route from current position to destination periodically
      final dest = _pendingMapTarget;
      if (dest != null && !_isFetchingRoute) {
        final now = DateTime.now();
        final shouldRecalc = _lastRouteRecalcTime == null ||
            now.difference(_lastRouteRecalcTime!).inSeconds >= 20 ||
            (_lastRouteRecalcOrigin != null &&
                Geolocator.distanceBetween(
                  point.latitude,
                  point.longitude,
                  _lastRouteRecalcOrigin!.latitude,
                  _lastRouteRecalcOrigin!.longitude,
                ) > 25);
        if (shouldRecalc) {
          _lastRouteRecalcTime = now;
          _lastRouteRecalcOrigin = point;
          _fetchRoute(point, dest);
        }
      }

      // Update Supabase so dispatchers see live position (throttle to ~every 12 s)
      final responder = _profile;
      if (responder != null) {
        final last = _lastSupabaseLocationUpdate;
        if (last == null ||
            DateTime.now().difference(last).inSeconds >= 12) {
          _lastSupabaseLocationUpdate = DateTime.now();
          final geoJsonPoint = {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
            'properties': {
              'lat': position.latitude,
              'lng': position.longitude,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          };
          SupabaseService.client
              .from('responder')
              .update({'last_location': geoJsonPoint})
              .eq('id', responder.id)
              .then((_) {})
              .catchError((_) {});
        }
      }
    });
  }

  String _cleanError(Object error) {
    final text = error.toString();
    return text.replaceFirst('Exception: ', '').trim();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2563EB),
      ),
    );
  }
  void _showAssignmentOnMap(AssignmentReportSummary report) {
    final coords = report.coordinates;
    if (coords == null) {
      _showSnack('No location provided for this report', isError: true);
      return;
    }
    setState(() {
      _pendingMapTarget = coords;
      _pendingMapLabel = report.type ?? 'Destination';
      _routePolyline = [];
      _routeError = null;
      _routeDistanceKm = null;
      _routeDurationMin = null;
      _selectedIndex = _isSecurityGuard ? 3 : 2; // Switch to Map View tab
    });

    // Use live location as origin; if missing, request it then fetch route when ready
    final origin = _deviceLocation;
    if (origin == null) {
      _showSnack('Getting your location to build the route...');
      _captureLocation();
      return;
    }
    _fetchRoute(origin, coords);
  }

  // Check if a coordinate is near the Open Field (walkable area)
  bool _isNearOpenField(latlong.LatLng point) {
    final distanceMeters = Geolocator.distanceBetween(
      _openFieldCenter.latitude,
      _openFieldCenter.longitude,
      point.latitude,
      point.longitude,
    );
    return distanceMeters < 100; // Within 100 meters of Open Field center
  }

  // Create a direct route through the open field (walkable area)
  List<latlong.LatLng> _createDirectFieldRoute(
    latlong.LatLng from,
    latlong.LatLng to,
  ) {
    final distanceMeters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    
    // Create a smooth direct path with intermediate points
    final numSegments = (distanceMeters / 20).ceil().clamp(3, 20); // 3-20 segments
    
    List<latlong.LatLng> route = [from];
    
    for (int i = 1; i < numSegments; i++) {
      final ratio = i / numSegments;
      final lat = from.latitude + (to.latitude - from.latitude) * ratio;
      final lng = from.longitude + (to.longitude - from.longitude) * ratio;
      route.add(latlong.LatLng(lat, lng));
    }
    
    route.add(to);
    return route;
  }

  Future<void> _fetchRoute(CoordinatePoint origin, CoordinatePoint destination) async {
    setState(() {
      _isFetchingRoute = true;
      _routeError = null;
      _routePolyline = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });

    final originLatLng = latlong.LatLng(origin.latitude, origin.longitude);
    final destLatLng = latlong.LatLng(destination.latitude, destination.longitude);

    // Check if routing through Open Field (walkable area) - use direct path
    if (_isNearOpenField(originLatLng) && _isNearOpenField(destLatLng)) {
      final directRoute = _createDirectFieldRoute(originLatLng, destLatLng);
      final totalDistance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      
      if (!mounted) return;
      setState(() {
        _routePolyline = directRoute;
        _routeDistanceKm = totalDistance / 1000;
        _routeDurationMin = (totalDistance / 1000 / 5) * 60; // 5 km/h walking speed
        _isFetchingRoute = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
          'https://routing.openstreetmap.de/routed-foot/route/v1/foot/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Routing service unavailable (${response.statusCode})');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        throw Exception('No route available');
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = (route['geometry'] ?? {}) as Map<String, dynamic>;
      final coordinates = (geometry['coordinates'] ?? []) as List<dynamic>;
      final polyline = coordinates
          .whereType<List>()
          .where((pair) => pair.length >= 2)
          .map((pair) => latlong.LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _routePolyline = polyline;
        _routeDistanceKm = ((route['distance'] as num?) ?? 0) / 1000;
        _routeDurationMin = ((route['duration'] as num?) ?? 0) / 60;
        _isFetchingRoute = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = e.toString();
        _isFetchingRoute = false;
        _routePolyline = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF3b82f6),
          foregroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipOval(
              child: Image.asset(
                'assets/images/udrrmo-logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: const Text('Kapiyu Responder'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _loadPage(showLoader: true),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.warning_rounded, size: 56, color: Colors.amber.shade700),
            const SizedBox(height: 16),
            Text(
              'Unable to load dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadPage(showLoader: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipOval(
            child: Image.asset(
              'assets/images/udrrmo-logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: const Text(
          'Kapiyu Responder',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () => _loadPage(showLoader: false),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _isSecurityGuard
              ? [
                  _buildDashboardTab(),
                  _buildAssignmentsTab(),
                  _buildOngoingTab(),
                  _buildMapTab(),
                ]
              : [
                  _buildDashboardTab(),
                  _buildAssignmentsTab(),
                  _buildMapTab(),
                ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (_isSecurityGuard && index == 2 && _ongoingReports.isEmpty && !_ongoingLoading) {
              _loadOngoingReports();
            }
          });
        },
        selectedItemColor: const Color(0xFF3b82f6),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: _isSecurityGuard
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_customize),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'My Assignments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.campaign_outlined),
                  label: 'Ongoing',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Map View',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_customize),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'My Assignments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Map View',
                ),
              ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _buildReadinessNoticeCard(),
        const SizedBox(height: 24),
        _buildAvailabilityCard(),
      ],
    );
  }

  Widget _buildReadinessNoticeCard() {
    final message = _responderSynopsisMessage ??
        'Keep equipment inspected and stay ready for anything.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf0fdf4), Color(0xFFecfdf5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: const Color(0xFF059669), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: const Color(0xFF059669), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Readiness Notice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on recent system reports (last 30 days)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildAssignmentsSection(),
        const SizedBox(height: 24),
        _buildCompletedSection(),
      ],
    );
  }

  Widget _buildMapTab() {
    _focusMapIfNeeded();
    _autoShowRoutesIfNeeded();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildMapCard(),
      ],
    );
  }

  Widget _buildOngoingTab() {
    if (_ongoingReports.isEmpty && !_ongoingLoading) {
      _loadOngoingReports();
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFeff6ff),
            borderRadius: BorderRadius.circular(16),
            border: const Border(left: BorderSide(color: Color(0xFF3b82f6), width: 4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ongoing Incidents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1e40af)),
              ),
              SizedBox(height: 4),
              Text(
                'All active emergencies — stay aware and cooperate with response teams.',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_ongoingLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_ongoingReports.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No ongoing incidents at the moment.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._ongoingReports.map<Widget>((report) {
            final type = report['type']?.toString() ?? 'Emergency';
            final status = report['status']?.toString() ?? 'pending';
            final location = report['location'];
            String locationText = 'Location not set';
            if (location != null) {
              if (location is Map) {
                final lat = location['latitude'] ?? location['lat'];
                final lng = location['longitude'] ?? location['lng'];
                final addr = location['address'] ?? location['formatted_address'];
                if (addr != null && addr.toString().isNotEmpty) {
                  locationText = addr.toString();
                } else if (lat != null && lng != null) {
                  locationText = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
                }
              } else if (location is String) {
                locationText = location;
              }
            }
            final createdAt = report['created_at'];
            final timeStr = createdAt != null
                ? DateFormat('MMM d, h:mm a').format(DateTime.parse(createdAt.toString()))
                : '—';
            final responderName = report['responder_name'] ?? (report['responder'] is Map ? (report['responder'] as Map)['name'] : null);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  type.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(locationText, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    Text('Reported: $timeStr • ${status.toUpperCase()}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    if (responderName != null && responderName.toString().isNotEmpty)
                      Text('Assigned to: $responderName', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final loc = report['location'];
                  latlong.LatLng? coords;
                  if (loc is Map && loc['latitude'] != null && loc['longitude'] != null) {
                    coords = latlong.LatLng(
                      (loc['latitude'] as num).toDouble(),
                      (loc['longitude'] as num).toDouble(),
                    );
                  } else if (loc is Map && loc['lat'] != null && loc['lng'] != null) {
                    coords = latlong.LatLng(
                      (loc['lat'] as num).toDouble(),
                      (loc['lng'] as num).toDouble(),
                    );
                  }
                  if (coords != null) {
                    final c = coords;
                    setState(() {
                      _pendingMapTarget = CoordinatePoint(latitude: c.latitude, longitude: c.longitude);
                      _pendingMapLabel = type;
                      _selectedIndex = 3;
                      _routePolyline = [];
                      _routeError = null;
                      _routeDistanceKm = null;
                      _routeDurationMin = null;
                    });
                    if (_deviceLocation != null) {
                      _fetchRoute(_deviceLocation!, CoordinatePoint(latitude: c.latitude, longitude: c.longitude));
                    }
                  }
                },
              ),
            );
          }).toList(),
      ],
    );
  }

  Future<void> _loadOngoingReports() async {
    if (_ongoingLoading || !mounted) return;
    setState(() => _ongoingLoading = true);
    try {
      const ongoingStatuses = ['pending', 'processing', 'classified', 'assigned', 'in-progress'];
      final response = await SupabaseService.client
          .from('reports')
          .select('id, type, corrected_type, message, status, location, reporter_name, created_at, responder_id, responder:responder_id(id, name)')
          .inFilter('status', ongoingStatuses)
          .order('created_at', ascending: false);
      final list = response as List<dynamic>? ?? [];
      final maps = list.whereType<Map<String, dynamic>>().where((r) {
        final type = (r['type'] as String? ?? '').toLowerCase();
        final correctedType = (r['corrected_type'] as String? ?? '').toLowerCase();
        return type != 'false_alarm' && correctedType != 'false_alarm';
      }).toList();
      if (mounted) {
        setState(() {
          _ongoingReports = maps;
          _ongoingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ongoingReports = [];
          _ongoingLoading = false;
        });
      }
    }
  }

  void _autoShowRoutesIfNeeded() {
    // Automatically show route to first active assignment if available
    if (_pendingMapTarget == null && _activeAssignments.isNotEmpty && !_isFetchingRoute) {
      final firstAssignment = _activeAssignments.first;
      final coords = firstAssignment.report.coordinates;
      if (coords != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Only use live device location for routing
          final origin = _deviceLocation;
          if (origin != null && _routePolyline.isEmpty) {
            setState(() {
              _pendingMapTarget = coords;
              _pendingMapLabel = firstAssignment.report.type ?? 'Destination';
            });
            _fetchRoute(origin, coords);
          }
        });
      }
    }
  }

  void _focusMapIfNeeded() {
    if (_pendingMapTarget == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingMapTarget == null) return;
      try {
        _mapController.move(
          latlong.LatLng(
            _pendingMapTarget!.latitude,
            _pendingMapTarget!.longitude,
          ),
          16,
        );
      } catch (_) {}
    });
  }

  Widget _buildHeader() {
    final responder = _profile;
    if (responder == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              responder.initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  responder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  responder.role,
                  style: const TextStyle(
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                if (responder.teamName != null || responder.leaderName != null) ...[
                  const SizedBox(height: 6),
                  if (responder.teamName != null)
                    Text(
                      'Team: ${responder.teamName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  if (responder.teamName != null && responder.leaderName != null) const SizedBox(height: 2),
                  if (responder.leaderName != null)
                    Text(
                      'Leader: ${responder.leaderName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: responder.isAvailable ? Colors.green : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    responder.isAvailable ? 'Available for dispatch' : 'Unavailable',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final assigned = _activeAssignments.length;
    final completed = _completedAssignments.length;
    final responseTime = _averageResponseMinutes;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.75,
      children: [
        _buildStatCard(
          title: 'Assigned Reports',
          value: assigned.toString(),
          icon: Icons.assignment_rounded,
          color: const Color(0xFF2563EB),
          subtitle: 'Active right now',
        ),
        _buildStatCard(
          title: 'Completed',
          value: completed.toString(),
          icon: Icons.verified_rounded,
          color: const Color(0xFF10B981),
          subtitle: 'Resolved successfully',
        ),
        _buildStatCard(
          title: 'Avg Response',
          value: responseTime == null ? '--' : '${responseTime.round()} min',
          icon: Icons.timer_rounded,
          color: const Color(0xFFF97316),
          subtitle: responseTime == null ? 'Need more data' : 'Based on resolved tasks',
        ),
        _buildStatCard(
          title: 'Coverage Radius',
          value: '5 km',
          icon: Icons.radar_rounded,
          color: const Color(0xFFA855F7),
          subtitle: 'Sta. Cruz Campus',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    final responder = _profile;
    if (responder == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.toggle_on_rounded, color: Color(0xFF2563EB), size: 28),
              const SizedBox(width: 8),
              Text(
                'My Availability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Switch.adaptive(
                value: responder.isAvailable,
                onChanged: _updatingAvailability ? null : (_) => _toggleAvailability(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pendingMapTarget != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Focusing on ${_pendingMapLabel ?? 'selected location'}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            responder.isAvailable
                ? 'You are visible to dispatchers and can receive new assignments.'
                : 'You are hidden from dispatchers until you toggle availability back on.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.phone_android, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 8),
              Text(
                responder.phone ?? 'No phone number on file',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _syncOneSignalPlayerId,
              icon: const Icon(Icons.notifications_active, size: 20),
              label: const Text('Sync Notifications (OneSignal)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10b981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncOneSignalPlayerId() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userId = SupabaseService.currentUserId;
      
      if (userId == null) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          _showSnack('❌ Not logged in. Please login first.', isError: true);
        }
        return;
      }

      debugPrint('🔄 Manual sync: Saving OneSignal Player ID...');
      await OneSignalService().retrySavePlayerIdToSupabase();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showSnack('✅ Notifications synced successfully!');
      }
    } catch (e) {
      debugPrint('❌ Error syncing OneSignal Player ID: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showSnack('❌ Sync failed: $e', isError: true);
      }
    }
  }

  Widget _buildAssignmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Assignments',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _activeAssignments.isEmpty
              ? 'No ongoing assignments. Stay alert for new dispatches.'
              : 'Stay coordinated and update the status as you move.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        if (_activeAssignments.isEmpty)
          _buildEmptyState(
            icon: Icons.assignment_turned_in_rounded,
            message: 'You have no active assignments right now.',
          )
        else
          ..._activeAssignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAssignmentCard(assignment),
            ),
          ),
      ],
    );
  }

  Widget _buildAssignmentCard(ResponderAssignment assignment) {
    final statusColor = _statusColor(assignment.status);
    final locationText = _formatLocation(assignment.report);

    final primaryTarget = _primaryStatusTarget(assignment.status);
    final primaryLabel = _primaryStatusLabel(assignment.status);
    final canResolve = !assignment.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _typeEmoji(assignment.report.type),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.report.type?.toUpperCase() ?? 'EMERGENCY',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        assignment.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor.darken(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Navigate',
                icon: const Icon(Icons.navigation_rounded),
                color: const Color(0xFF2563EB),
                onPressed: assignment.report.coordinates == null
                    ? null
                    : () => _showAssignmentOnMap(assignment.report),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            assignment.report.message ?? 'No description provided.',
            style: TextStyle(color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.place_outlined, color: Colors.grey.shade500, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationText,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: Colors.grey.shade500, size: 18),
              const SizedBox(width: 6),
              Text(
                _formatDate(assignment.assignedAt),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (primaryTarget != null)
                ElevatedButton.icon(
                  onPressed: _updatingAssignmentId == assignment.id
                      ? null
                      : () => _updateAssignmentStatus(assignment, primaryTarget),
                  icon: _updatingAssignmentId == assignment.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(primaryLabel),
                ),
              if (canResolve)
                OutlinedButton.icon(
                  onPressed: _updatingAssignmentId == assignment.id
                      ? null
                      : () => _showResolveNoteDialog(assignment),
                  icon: const Icon(Icons.flag_circle_outlined),
                  label: const Text('Mark Resolved'),
                ),
              TextButton.icon(
                onPressed: assignment.report.imagePath == null
                    ? null
                    : () => _showImagePreview(assignment.report.imagePath!),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('View Photo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection() {
    if (_completedAssignments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed Assignments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Assignments you finish will appear here for quick reference.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildEmptyState(
            icon: Icons.inbox_outlined,
            message: 'Nothing completed yet. Finish an assignment to build your record.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed Assignments',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Great job! Here is a quick log of your resolved responses.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ..._completedAssignments.take(5).map(
              (assignment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCompletedTile(assignment),
              ),
            ),
      ],
    );
  }

  Widget _buildCompletedTile(ResponderAssignment assignment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF10B981)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.report.type?.toUpperCase() ?? 'EMERGENCY',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed ${_formatDate(assignment.completedAt)}',
                  style: const TextStyle(color: Color(0xFF047857)),
                ),
                if (assignment.notes != null && assignment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 16, color: Colors.green.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            assignment.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final markers = _buildMarkers();
    final center = _mapCenter();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Map View',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _updatingLocation ? null : _captureLocation,
                icon: _updatingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text(
                  'Update',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _deviceLocation != null ? 18 : 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.lspu.responder',
                    tileProvider: NetworkTileProvider(
                      headers: {
                        'Cache-Control': 'no-cache, no-store, must-revalidate',
                        'Pragma': 'no-cache',
                        'Expires': '0',
                      },
                    ),
                  ),
                  if (_routePolyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePolyline,
                          strokeWidth: 5,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            markers.isEmpty
                ? 'Location data is not available yet. Update your location to help dispatchers.'
                : _routePolyline.isEmpty && _activeAssignments.isNotEmpty
                    ? 'Blue pin shows your position. Red pins highlight active assignments. Tap "Update" to enable routing.'
                    : 'Blue pin shows your position. Red pins highlight active assignments.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (_isFetchingRoute)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text('Building navigation route...'),
                ),
              ],
            )
          else if (_routePolyline.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route ready: ${_routeDistanceKm?.toStringAsFixed(1) ?? '--'} km • '
                  '${_routeDurationMin?.toStringAsFixed(0) ?? '--'} min',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Follow the highlighted line to reach the destination.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            )
          else if (_routeError != null)
            Text(
              'Route error: $_routeError',
              style: const TextStyle(color: Colors.redAccent),
            ),
          if (_pendingMapTarget != null && !_isFetchingRoute)
            TextButton.icon(
              onPressed: () {
                final origin = _deviceLocation;
                if (origin == null) {
                  _showSnack(
                    'Share your live location first by tapping "Update" in the map view.',
                    isError: true,
                  );
                  return;
                }
                _fetchRoute(origin, _pendingMapTarget!);
              },
              icon: const Icon(Icons.route),
              label: const Text('Recalculate route'),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    // Show only the responder phone's current location as "me"
    final myPoint = _deviceLocation;
    if (myPoint != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(myPoint.latitude, myPoint.longitude),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: _buildMapMarker(
            color: const Color(0xFF2563EB),
            icon: Icons.person_pin_circle,
          ),
        ),
      );
    }

    for (final assignment in _activeAssignments) {
      final coord = assignment.report.coordinates;
      if (coord == null) continue;
      markers.add(
        Marker(
          point: latlong.LatLng(coord.latitude, coord.longitude),
          width: 44,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: _buildMapMarker(
            color: Colors.redAccent,
            icon: Icons.warning_amber_outlined,
          ),
        ),
      );
    }

    if (_pendingMapTarget != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(
            _pendingMapTarget!.latitude,
            _pendingMapTarget!.longitude,
          ),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: _buildMapMarker(
            color: Colors.orangeAccent,
            icon: Icons.flag_rounded,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMapMarker({required Color color, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  latlong.LatLng _mapCenter() {
    // Prefer pending target, then live device location; fall back to any report
    CoordinatePoint? point = _pendingMapTarget ?? _deviceLocation;
    if (point == null) {
      for (final assignment in _assignments) {
        final coords = assignment.report.coordinates;
        if (coords != null) {
          point = coords;
          break;
        }
      }
    }
    if (point != null) {
      return latlong.LatLng(point.latitude, point.longitude);
    }
    return latlong.LatLng(14.26284, 121.39743); // LSPU Sta. Cruz Campus fallback
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFFF59E0B);
      case 'enroute':
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'on_scene':
        return const Color(0xFF0EA5E9);
      case 'resolved':
      case 'completed':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _primaryStatusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Accept assignment';
      case 'accepted':
        return 'Mark en route';
      case 'enroute':
        return 'Mark on scene';
      case 'on_scene':
        return 'Close assignment';
      default:
        return 'Update status';
    }
  }

  String? _primaryStatusTarget(String status) {
    switch (status) {
      case 'assigned':
        return 'accepted';
      case 'accepted':
        return 'enroute';
      case 'enroute':
        return 'on_scene';
      case 'on_scene':
        return 'resolved';
      default:
        return null;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Time unknown';
    return _dateFormat.format(date.toLocal());
  }

  String _formatLocation(AssignmentReportSummary report) {
    final coord = report.coordinates;
    if (coord != null) {
      return 'Lat ${coord.latitude.toStringAsFixed(4)}, Lng ${coord.longitude.toStringAsFixed(4)}';
    }
    return 'Location not specified';
  }

  String _typeEmoji(String? type) {
    switch (type?.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'accident':
        return '🚗';
      case 'flood':
        return '🌊';
      case 'storm':
        return '⛈️';
      case 'earthquake':
        return '🌍';
      default:
        return '⚠️';
    }
  }

  Future<void> _openInMaps(CoordinatePoint point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Unable to open Google Maps', isError: true);
    }
  }

  /// Resolve report image path to a loadable URL (Supabase storage path → public URL).
  String _resolveReportImageUrl(String imagePath) {
    if (imagePath.isEmpty) return imagePath;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    final path = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '${SupabaseService.supabaseUrl}/storage/v1/object/public/reports-images/$path';
  }

  void _showImagePreview(String imageUrl) {
    final resolvedUrl = _resolveReportImageUrl(imageUrl);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade100,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: const Text('Unable to load image'),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_id');
              await prefs.remove('user_email');
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

extension _ColorShade on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    return Color.lerp(this, Colors.black, amount) ?? this;
  }
}

