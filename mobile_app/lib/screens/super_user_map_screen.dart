import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/responder_models.dart';

class SuperUserMapScreen extends StatefulWidget {
  const SuperUserMapScreen({super.key});

  @override
  State<SuperUserMapScreen> createState() => _SuperUserMapScreenState();
}

class _SuperUserMapScreenState extends State<SuperUserMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _allReports = []; // Store all reports
  List<Map<String, dynamic>> _reports = []; // Filtered reports
  List<ResponderProfile> _responders = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String _currentFilter = 'active'; // 'all', 'active', 'completed' - default to 'active'
  RealtimeChannel? _reportsChannel;
  RealtimeChannel? _respondersChannel;
  RealtimeChannel? _assignmentsChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _reportsChannel?.unsubscribe();
    _respondersChannel?.unsubscribe();
    _assignmentsChannel?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadReports(),
        _loadResponders(),
        _loadAssignments(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReports() async {
    try {
      final response = await SupabaseService.client
          .from('reports')
          .select('id, type, status, location, message, created_at, reporter_name, corrected_type, priority, severity')
          .order('created_at', ascending: false)
          .limit(100);

      if (response != null && mounted) {
        setState(() {
          _allReports = List<Map<String, dynamic>>.from(response);
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
  }

  void _applyFilter() {
    // Filter out non-emergency reports first
    final emergencyReports = _allReports.where((report) {
      final effectiveType = (report['corrected_type'] ?? report['type'] ?? '').toString().toLowerCase().trim();
      return effectiveType != 'non_emergency';
    }).toList();

    switch (_currentFilter) {
      case 'active':
        _reports = emergencyReports.where((report) {
          final status = (report['status'] ?? '').toString().toLowerCase();
          return status == 'pending' ||
              status == 'processing' ||
              status == 'classified' ||
              status == 'assigned' ||
              status == 'in-progress' ||
              status == 'enroute' ||
              status == 'on_scene';
        }).toList();
        break;
      case 'completed':
        _reports = emergencyReports.where((report) {
          final status = (report['status'] ?? '').toString().toLowerCase();
          return status == 'completed' || status == 'resolved';
        }).toList();
        break;
      case 'all':
      default:
        _reports = emergencyReports;
        break;
    }
  }

  void _setFilter(String filter) {
    if (mounted) {
      setState(() {
        _currentFilter = filter;
        _applyFilter();
        // Update assignments based on filter - for active filter, show all active assignments
        // For other filters, we might want to filter assignments too
        if (filter == 'active') {
          // Keep all active assignments visible
        } else if (filter == 'completed') {
          // Hide assignment lines for completed filter
        } else {
          // Show all assignments for 'all' filter
        }
      });
    }
  }

  Future<void> _loadResponders() async {
    try {
      final response = await SupabaseService.client
          .from('responder')
          .select('id, name, role, status, is_available, last_location, updated_at');

      if (response != null && mounted) {
        setState(() {
          _responders = (response as List)
              .map((r) => ResponderProfile.fromMap(Map<String, dynamic>.from(r)))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading responders: $e');
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final response = await SupabaseService.client
          .from('assignment')
          .select('''
            id,
            status,
            assigned_at,
            accepted_at,
            completed_at,
            report_id,
            responder_id,
            reports:reports!assignment_report_id_fkey (
              id,
              type,
              message,
              location,
              status,
              reporter_name,
              created_at,
              image_path,
              corrected_type,
              priority,
              severity
            ),
            responder:responder!assignment_responder_id_fkey (
              id,
              name,
              role,
              last_location,
              is_available
            )
          ''')
          .inFilter('status', ['assigned', 'accepted', 'enroute', 'on_scene']);

      if (response != null && mounted) {
        setState(() {
          _assignments = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading assignments: $e');
    }
  }

  void _setupRealtimeUpdates() {
    // Subscribe to reports changes
    _reportsChannel = SupabaseService.client
        .channel('super-user-reports')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reports',
          callback: (payload) {
            _loadReports();
          },
        )
        .subscribe();

    // Subscribe to responders changes
    _respondersChannel = SupabaseService.client
        .channel('super-user-responders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'responder',
          callback: (payload) {
            _loadResponders();
          },
        )
        .subscribe();

    // Subscribe to assignments changes
    _assignmentsChannel = SupabaseService.client
        .channel('super-user-assignments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assignment',
          callback: (payload) {
            _loadAssignments();
            _loadResponders(); // Reload responders to update their status
          },
        )
        .subscribe();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Add emergency/report markers (filtered)
    for (final report in _reports) {
      final location = report['location'];
      if (location == null) continue;

      final coords = coordinateFrom(location);
      if (coords == null) continue;

      final type = report['type']?.toString() ?? 'unknown';
      final status = report['status']?.toString() ?? 'unknown';

      markers.add(
        Marker(
          point: latlong.LatLng(coords.latitude, coords.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showReportDetails(report),
            child: _buildEmergencyMarker(type, status, report),
          ),
        ),
      );
    }

    // Always show responder markers (they should always be visible)
    // Especially important for active filter to see responders with assignments
    for (final responder in _responders) {
      final coords = responder.coordinates;
      if (coords == null) continue;

      // Find active assignment for this responder
      final activeAssignment = _assignments.firstWhere(
        (a) => a['responder_id'] == responder.id &&
            ['assigned', 'accepted', 'enroute', 'on_scene']
                .contains(a['status']),
        orElse: () => <String, dynamic>{},
      );

      // For active filter, prioritize showing responders with assignments
      // For other filters, show all responders
      if (_currentFilter == 'active') {
        // Show all responders in active filter (they might have assignments)
      } else if (_currentFilter == 'completed') {
        // Still show responders even in completed filter
      }

      markers.add(
        Marker(
          point: latlong.LatLng(coords.latitude, coords.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showResponderInfo(responder, activeAssignment),
            child: _buildResponderMarker(responder, activeAssignment),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    // Only show assignment lines for active filter or all filter
    if (_currentFilter == 'completed') {
      return polylines; // Don't show assignment lines for completed filter
    }

    for (final assignment in _assignments) {
      final reportData = assignment['reports'];
      final responderData = assignment['responder'];

      if (reportData == null || responderData == null) continue;

      final reportLocation = coordinateFrom(reportData['location']);
      final responderLocation = coordinateFrom(responderData['last_location']);

      if (reportLocation == null || responderLocation == null) continue;

      // For active filter, only show lines for reports that are in the filtered list
      if (_currentFilter == 'active') {
        final reportId = reportData['id']?.toString();
        final isReportInFilter = _reports.any((r) => r['id']?.toString() == reportId);
        if (!isReportInFilter) continue;
      }

      final status = assignment['status']?.toString() ?? 'assigned';
      final color = _getAssignmentLineColor(status);

      polylines.add(
        Polyline(
          points: [
            latlong.LatLng(responderLocation.latitude, responderLocation.longitude),
            latlong.LatLng(reportLocation.latitude, reportLocation.longitude),
          ],
          strokeWidth: 4,
          color: color,
        ),
      );
    }

    return polylines;
  }

  Color _getAssignmentLineColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return const Color(0xFFf59e0b); // Amber
      case 'accepted':
        return const Color(0xFF3b82f6); // Blue
      case 'enroute':
        return const Color(0xFF06b6d4); // Cyan
      case 'on_scene':
        return const Color(0xFF10b981); // Green
      default:
        return const Color(0xFF6b7280); // Gray
    }
  }

  Widget _buildEmergencyMarker(String type, String status, Map<String, dynamic> report) {
    Color color;
    IconData icon;
    String emoji = _getTypeEmoji(type);

    // Determine color and icon based on status
    switch (status.toLowerCase()) {
      case 'active':
      case 'pending':
        color = const Color(0xFFef4444); // Red
        icon = Icons.warning_rounded;
        break;
      case 'assigned':
      case 'processing':
      case 'classified':
        color = const Color(0xFFf97316); // Orange
        icon = Icons.access_time_rounded;
        break;
      case 'in-progress':
      case 'enroute':
        color = const Color(0xFF3b82f6); // Blue
        icon = Icons.local_fire_department_rounded;
        break;
      case 'completed':
      case 'resolved':
        color = const Color(0xFF10b981); // Green
        icon = Icons.check_circle_rounded;
        break;
      default:
        color = const Color(0xFF3b82f6); // Blue
        icon = Icons.info_rounded;
    }

    // Determine color based on emergency type if status is pending
    if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'active') {
      switch (type.toLowerCase()) {
        case 'fire':
          color = const Color(0xFFdc2626); // Dark red
          break;
        case 'medical':
          color = const Color(0xFFef4444); // Red
          break;
        case 'accident':
          color = const Color(0xFFf97316); // Orange
          break;
        case 'flood':
          color = const Color(0xFF3b82f6); // Blue
          break;
        case 'storm':
          color = const Color(0xFF6366f1); // Indigo
          break;
        case 'earthquake':
          color = const Color(0xFF7c3aed); // Purple
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResponderMarker(
      ResponderProfile responder, Map<String, dynamic> assignment) {
    Color color;
    IconData icon;
    String statusText;

    if (assignment.isNotEmpty) {
      final status = assignment['status']?.toString() ?? 'assigned';
      switch (status.toLowerCase()) {
        case 'assigned':
          color = const Color(0xFFf59e0b); // Amber
          icon = Icons.assignment_rounded;
          statusText = 'Assigned';
          break;
        case 'accepted':
          color = const Color(0xFF3b82f6); // Blue
          icon = Icons.check_circle_rounded;
          statusText = 'Accepted';
          break;
        case 'enroute':
          color = const Color(0xFF06b6d4); // Cyan
          icon = Icons.airport_shuttle_rounded;
          statusText = 'En Route';
          break;
        case 'on_scene':
          color = const Color(0xFF10b981); // Green
          icon = Icons.location_on_rounded;
          statusText = 'On Scene';
          break;
        default:
          color = const Color(0xFF6b7280);
          icon = Icons.person_rounded;
          statusText = 'Active';
      }
    } else if (responder.isAvailable) {
      color = const Color(0xFF10b981); // Green
      icon = Icons.person_rounded;
      statusText = 'Available';
    } else {
      color = const Color(0xFF6b7280); // Gray
      icon = Icons.person_off_rounded;
      statusText = 'Unavailable';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                responder.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  void _showResponderInfo(
      ResponderProfile responder, Map<String, dynamic> assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: assignment.isNotEmpty ? 0.75 : 0.4,
        minChildSize: assignment.isNotEmpty ? 0.5 : 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Responder Header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: assignment.isNotEmpty
                                ? _getAssignmentStatusColor(assignment['status']?.toString() ?? 'assigned')
                                : (responder.isAvailable ? Colors.green : Colors.grey),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (assignment.isNotEmpty
                                        ? _getAssignmentStatusColor(assignment['status']?.toString() ?? 'assigned')
                                        : (responder.isAvailable ? Colors.green : Colors.grey))
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              responder.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    responder.role,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (assignment.isNotEmpty) ...[
                      // Emergency Details Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getTypeEmoji(assignment['reports']?['type']?.toString() ?? 'unknown'),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CURRENT ASSIGNMENT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (assignment['reports']?['type']?.toString() ?? 'UNKNOWN').toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              Icons.flag,
                              'Assignment Status',
                              (assignment['status']?.toString() ?? 'ASSIGNED').toUpperCase(),
                              _getAssignmentStatusColor(assignment['status']?.toString() ?? 'assigned'),
                            ),
                            const SizedBox(height: 12),
                            if (assignment['assigned_at'] != null)
                              _buildDetailRow(
                                Icons.access_time,
                                'Assigned At',
                                _formatDate(DateTime.parse(assignment['assigned_at'])),
                                Colors.blue,
                              ),
                            if (assignment['accepted_at'] != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                Icons.check_circle,
                                'Accepted At',
                                _formatDate(DateTime.parse(assignment['accepted_at'])),
                                Colors.green,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Emergency Information Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Emergency Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (assignment['reports']?['reporter_name'] != null) ...[
                              _buildInfoRow(
                                'Reporter',
                                assignment['reports']?['reporter_name']?.toString() ?? 'Unknown',
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (assignment['reports']?['message'] != null &&
                                (assignment['reports']?['message']?.toString() ?? '').trim().isNotEmpty) ...[
                              _buildInfoRow(
                                'Description',
                                (assignment['reports']?['message']?.toString() ?? '').trim(),
                                Icons.description_outlined,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (assignment['reports']?['created_at'] != null) ...[
                              _buildInfoRow(
                                'Reported At',
                                _formatDate(DateTime.parse(assignment['reports']?['created_at'])),
                                Icons.schedule,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Time Since',
                                _getTimeSince(DateTime.parse(assignment['reports']?['created_at'])),
                                Icons.timer_outlined,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (assignment['reports']?['location'] != null) ...[
                              _buildInfoRow(
                                'Location',
                                _formatLocation(assignment['reports']?['location']),
                                Icons.location_on_outlined,
                              ),
                            ],
                            if (assignment['reports']?['priority'] != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Priority',
                                _getPriorityText(assignment['reports']?['priority']),
                                Icons.priority_high,
                              ),
                            ],
                            if (assignment['reports']?['severity'] != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Severity',
                                assignment['reports']?['severity']?.toString().toUpperCase() ?? 'UNKNOWN',
                                Icons.warning_amber_outlined,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // No Assignment - Available Status
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: responder.isAvailable ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: responder.isAvailable
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              responder.isAvailable ? Icons.check_circle : Icons.cancel,
                              color: responder.isAvailable ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    responder.isAvailable ? 'Available' : 'Unavailable',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: responder.isAvailable ? Colors.green.shade700 : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    responder.isAvailable
                                        ? 'Ready to accept assignments'
                                        : 'Not available for assignments',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getAssignmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return const Color(0xFFf59e0b); // Amber
      case 'accepted':
        return const Color(0xFF3b82f6); // Blue
      case 'enroute':
        return const Color(0xFF06b6d4); // Cyan
      case 'on_scene':
        return const Color(0xFF10b981); // Green
      default:
        return const Color(0xFF6b7280); // Gray
    }
  }

  String _formatLocation(dynamic location) {
    if (location == null) return 'Location not specified';
    
    if (location is Map) {
      return location['address']?.toString() ?? 
             location['formatted_address']?.toString() ?? 
             location['description']?.toString() ?? 
             'Location detected';
    }
    
    if (location is String) {
      try {
        final decoded = jsonDecode(location);
        if (decoded is Map) {
          return decoded['address']?.toString() ?? 
                 decoded['formatted_address']?.toString() ?? 
                 decoded['description']?.toString() ?? 
                 'Location detected';
        }
      } catch (_) {
        return location;
      }
    }
    
    return 'Location detected';
  }

  String _getTimeSince(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String _getPriorityText(dynamic priority) {
    if (priority == null) return 'Unknown';
    final p = priority is int ? priority : int.tryParse(priority.toString()) ?? 4;
    switch (p) {
      case 1:
        return 'Critical';
      case 2:
        return 'High';
      case 3:
        return 'Medium';
      case 4:
        return 'Low';
      default:
        return 'Unknown';
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final type = report['type']?.toString() ?? 'Unknown';
    final status = report['status']?.toString() ?? 'Unknown';
    final message = report['message']?.toString() ?? 'No description';
    final reporterName = report['reporter_name']?.toString() ?? 'Unknown';
    final createdAt = report['created_at'];
    final location = report['location'];
    final priority = report['priority'];
    final severity = report['severity'];
    final correctedType = report['corrected_type']?.toString() ?? type;
    final emoji = _getTypeEmoji(correctedType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Emergency Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  correctedType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Report Information Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Report Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (reporterName != 'Unknown') ...[
                            _buildInfoRow(
                              'Reporter',
                              reporterName,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (message.trim().isNotEmpty) ...[
                            _buildInfoRow(
                              'Description',
                              message,
                              Icons.description_outlined,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (createdAt != null) ...[
                            _buildInfoRow(
                              'Reported At',
                              _formatDate(DateTime.parse(createdAt.toString())),
                              Icons.schedule,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Time Since',
                              _getTimeSince(DateTime.parse(createdAt.toString())),
                              Icons.timer_outlined,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (location != null) ...[
                            _buildInfoRow(
                              'Location',
                              _formatLocation(location),
                              Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (priority != null) ...[
                            _buildInfoRow(
                              'Priority',
                              _getPriorityText(priority),
                              Icons.priority_high,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (severity != null) ...[
                            _buildInfoRow(
                              'Severity',
                              severity.toString().toUpperCase(),
                              Icons.warning_amber_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/super-user-reports',
                          arguments: report,
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View Full Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3b82f6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'pending':
        return const Color(0xFFef4444); // Red
      case 'assigned':
      case 'processing':
      case 'classified':
        return const Color(0xFFf97316); // Orange
      case 'in-progress':
      case 'enroute':
        return const Color(0xFF3b82f6); // Blue
      case 'completed':
      case 'resolved':
        return const Color(0xFF10b981); // Green
      default:
        return const Color(0xFF3b82f6); // Blue
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getTypeEmoji(String type) {
    switch (type.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Super User Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const latlong.LatLng(14.26284, 121.39743),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lspu.superuser',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'Cache-Control': 'no-cache, no-store, must-revalidate',
                    'Pragma': 'no-cache',
                    'Expires': '0',
                  },
                ),
              ),
              if (!_isLoading) ...[
                PolylineLayer(polylines: _buildPolylines()),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // Filter Buttons
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton('all', 'All', Icons.list),
                  _buildFilterButton('active', 'Active', Icons.warning, isDefault: true),
                  _buildFilterButton('completed', 'Completed', Icons.check_circle),
                ],
              ),
            ),
          ),
          // Legend
          Positioned(
            top: 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Legend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(Icons.warning, 'Emergency', Colors.red),
                  _buildLegendItem(Icons.person, 'Available', Colors.green),
                  _buildLegendItem(Icons.airport_shuttle_rounded, 'En Route', Colors.cyan),
                  _buildLegendItem(Icons.location_on, 'On Scene', Colors.green),
                ],
              ),
            ),
          ),
          // Reports List Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentFilter == 'active'
                              ? 'Active Reports'
                              : _currentFilter == 'completed'
                                  ? 'Completed Reports'
                                  : 'All Reports',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_reports.length} reports, ${_responders.length} responders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _reports.isEmpty
                        ? Center(
                            child: Text(
                              'No active reports',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _reports.length,
                            itemBuilder: (context, index) {
                              final report = _reports[index];
                              return _buildReportCard(report);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filter, String label, IconData icon, {bool isDefault = false}) {
    final isActive = _currentFilter == filter;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _setFilter(filter),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF3b82f6)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? const Color(0xFF2563eb) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final type = report['type']?.toString() ?? 'Unknown';
    final status = report['status']?.toString() ?? 'Unknown';
    final message = report['message']?.toString() ?? 'No description';

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _getTypeEmoji(type),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3b82f6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3b82f6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
