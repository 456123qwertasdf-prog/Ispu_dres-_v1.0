import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapSimulationScreen extends StatefulWidget {
  const MapSimulationScreen({super.key});

  @override
  State<MapSimulationScreen> createState() => _MapSimulationScreenState();
}

class _MapSimulationScreenState extends State<MapSimulationScreen> {
  static const LatLng _campusCenter = LatLng(14.26284, 121.39743);
  static final LatLngBounds _campusBounds = LatLngBounds(
    const LatLng(14.2616, 121.3948), // southwest (parking)
    const LatLng(14.2644, 121.3992), // northeast (Quezon Ave + Trade Village)
  );
  static const double _defaultZoom = 17.8;
  static const String _defaultBuilding = 'CAS';

  final Distance _distance = const Distance();

  final Map<String, LatLng> _waypoints = const {
    'CSS': LatLng(14.262192, 121.397241),
    'CBAA': LatLng(14.262868, 121.396359),
    'UniversityLibrary': LatLng(14.262026, 121.398038),
    'ActivityCenter': LatLng(14.263063, 121.397719),
    'OpenField': LatLng(14.262670, 121.398424), // Main OpenField (near SHS)
    'OpenFieldNearSHS': LatLng(14.262670, 121.398424),
    'OpenFieldNearOldBasicEducation': LatLng(14.263325, 121.398467),
    'OpenFieldNearGearPublishing': LatLng(14.263157, 121.398531),
    'OpenFieldNearLibrary': LatLng(14.262052, 121.398131),
    'OpenFieldNearBasketballCourt': LatLng(14.262413, 121.398040),
    'OpenFieldNearVolleyballCourt': LatLng(14.262725, 121.397952),
    'OpenFieldNearActivityCenter': LatLng(14.262878, 121.397909),
    'OpenFieldNearMultiPurpose': LatLng(14.261977, 121.398362),
    'StudentServices': LatLng(14.261779, 121.397772),
    'CommissionOnAuditOffice': LatLng(14.261987, 121.397735),
    'AdministrationBuilding': LatLng(14.262288, 121.397668),
    'BusinessAffairsOffice': LatLng(14.262603, 121.397566),
    'UniversityChapel': LatLng(14.262337, 121.397035),
    'UniversityCafeteria': LatLng(14.262647, 121.397126),
    'COL': LatLng(14.262462, 121.396718),
    'CAS': LatLng(14.262387, 121.396238),
    'AcademicBuilding': LatLng(14.262712, 121.396434),
    'SupremeStudentGovernment': LatLng(14.262907, 121.396032),
    'CIT_1': LatLng(14.263120, 121.396321),
    'CCJE': LatLng(14.263250, 121.395935),
    'CIT_2': LatLng(14.263497, 121.396244),
    'CIT_3': LatLng(14.263208, 121.396965),
    'CIT_4': LatLng(14.263364, 121.396928),
    'UniversityClinic': LatLng(14.263375, 121.397378),
    'CONAH': LatLng(14.263520, 121.397483),
    'HumanKineticsCenter': LatLng(14.263330, 121.397665),
    'COE': LatLng(14.263440, 121.398092),
    'COE_2': LatLng(14.263684, 121.397992),
    'SHS': LatLng(14.263333, 121.398231),
    'EngineeringTestingCenter': LatLng(14.263266, 121.398030),
    'UDRRMO': LatLng(14.263793, 121.398357),
    'OldBasicEducationBuilding': LatLng(14.263422, 121.398550),
    'TheGearPublishing': LatLng(14.263180, 121.398609),
    'UniversityGrandstand': LatLng(14.262707, 121.398792),
    'MainGate': LatLng(14.261633, 121.397963),
    'GSOBuilding': LatLng(14.261831, 121.398320),
    'MultiPurposeBuilding': LatLng(14.261890, 121.398472),
    'BasketballCourt': LatLng(14.262387, 121.397904),
    'VolleyballCourt': LatLng(14.262639, 121.397831),
    'Gate2': LatLng(14.263697, 121.398454),
    'LSPUSupplyOffice': LatLng(14.262777, 121.396871),
    'LSPUHotel': LatLng(14.262850, 121.397113),
    'CHMT': LatLng(14.263006, 121.396995),
    'Gym': LatLng(14.263063, 121.397719),
    'CASCorner': LatLng(14.262540, 121.396760),
    'AcademicWalk': LatLng(14.262740, 121.397040),
    'ActivityWalk': LatLng(14.263020, 121.397520),
    'EvacuationField': LatLng(14.262689, 121.398464),
  };

  final Map<String, String> _waypointLabels = const {
    'CSS': 'CCS Building',
    'CAS': 'CAS Building',
    'CBAA': 'CBAA Building',
    'UniversityLibrary': 'University Library',
    'ActivityCenter': 'Activity Center',
    'OpenField': 'Open Field Assembly',
    'OpenFieldNearSHS': 'Open Field (near SHS)',
    'OpenFieldNearOldBasicEducation': 'Open Field (near Old Basic Education)',
    'OpenFieldNearGearPublishing': 'Open Field (near GEAR Publishing)',
    'OpenFieldNearLibrary': 'Open Field (near Library)',
    'OpenFieldNearBasketballCourt': 'Open Field (near Basketball Court)',
    'OpenFieldNearVolleyballCourt': 'Open Field (near Volleyball Court)',
    'OpenFieldNearActivityCenter': 'Open Field (near Activity Center)',
    'OpenFieldNearMultiPurpose': 'Open Field (near Multi-purpose Building)',
    'StudentServices': 'Student Services',
    'CommissionOnAuditOffice': 'COA Office',
    'AdministrationBuilding': 'Administration Building',
    'BusinessAffairsOffice': 'Business Affairs Office',
    'UniversityChapel': 'University Chapel',
    'UniversityCafeteria': 'University Cafeteria',
    'COL': 'College of Law',
    'AcademicBuilding': 'Academic Building',
    'SupremeStudentGovernment': 'SSG Office',
    'CIT_1': 'CIT Building 1',
    'CIT_2': 'CIT Building 2',
    'CIT_3': 'CIT Building 3',
    'CIT_4': 'CIT Building 4',
    'CCJE': 'CCJE Building',
    'CONAH': 'CONAH Building',
    'HumanKineticsCenter': 'Human Kinetics Center',
    'COE': 'COE Building',
    'COE_2': 'COE Annex',
    'SHS': 'Senior High School',
    'EngineeringTestingCenter': 'Engineering Testing Center',
    'UDRRMO': 'UDRRMO',
    'OldBasicEducationBuilding': 'Old Basic Education',
    'TheGearPublishing': 'The GEAR Publishing',
    'UniversityGrandstand': 'University Grandstand',
    'MainGate': 'Main Gate',
    'GSOBuilding': 'GSO Building',
    'MultiPurposeBuilding': 'Multi-purpose Building',
    'BasketballCourt': 'Basketball Court',
    'VolleyballCourt': 'Volleyball Court',
    'Gate2': 'Gate 2',
    'LSPUSupplyOffice': 'LSPU Supply Office',
    'LSPUHotel': 'LSPU Hotel',
    'CHMT': 'CHMT Building',
    'Gym': 'Activity Center / Gym',
    'CASCorner': 'CAS Covered Walk',
    'AcademicWalk': 'Academic Walkway',
    'ActivityWalk': 'Activity Center Walkway',
    'EvacuationField': 'Open Field Assembly',
  };

  // Removed route templates - now using simple start-to-OpenField routing

  StreamSubscription<Position>? _positionSub;

  LatLng? _userLocation;
  double? _locationAccuracy;
  List<LatLng> _activeRoutePoints = [];
  List<String> _activeStepIds = [];
  String? _selectedStartLocation; // Selected start building for testing

  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _initializeLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'Enable device location to receive GPS-based routes to OpenField.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage = 'Location permission required. Grant access to receive routes to OpenField.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final userLoc = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _userLocation = userLoc;
        _locationAccuracy = position.accuracy;
      });

      // Auto-route from GPS location to OpenField
      _createRouteFromGPSLocation(userLoc);

      // Update location and recalculate route when GPS position changes
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          distanceFilter: 10, // Recalculate route when user moves 10+ meters
          accuracy: LocationAccuracy.high,
        ),
      ).listen((pos) {
        if (mounted) {
          final newLocation = LatLng(pos.latitude, pos.longitude);
        setState(() {
            _userLocation = newLocation;
          _locationAccuracy = pos.accuracy;
        });
          // Recalculate route from new GPS location
          _createRouteFromGPSLocation(newLocation);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Unable to read GPS signal: $error';
      });
    }
  }

  // Create route from GPS location to OpenField - let OSRM handle the routing
  Future<void> _createRouteFromGPSLocation(LatLng gpsLocation) async {
    // Don't override if a manual test route is active
    if (_selectedStartLocation != null) {
      return; // Keep the test route active
    }
    
    // Check if GPS location is within campus
    if (!_isWithinCampus(gpsLocation)) {
      setState(() {
        _statusMessage = 'GPS location is outside campus. Use manual selection for testing.';
        _activeRoutePoints = [];
        _activeStepIds = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Calculating route from your location to OpenField...';
    });

    try {
      // Use the main OpenField location (middle of open field)
      final openFieldLocation = _waypoints['OpenField']!;
      
      // Let OSRM handle the routing directly from GPS to OpenField
      // OSRM will automatically use service roads and walkable paths
      print('🛣️ Routing from GPS location to OpenField via OSRM (service roads)...');
      final routePoints = await _fetchOSRMFootRoute(
        gpsLocation,
        openFieldLocation,
        fromWaypointId: null, // GPS location, not a waypoint
        toWaypointId: 'OpenField',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _activeRoutePoints = routePoints;
        _activeStepIds = ['GPS', 'OpenField'];
        _statusMessage = 'Route from your location → ${_waypointLabels['OpenField']}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to calculate route from GPS: $e';
        _activeRoutePoints = [];
        _activeStepIds = [];
      });
    }
  }

  // Removed announcement handling - now using simple test routing

  // List of all OpenField waypoint IDs
  static const List<String> _openFieldWaypoints = [
    'OpenField',
    'OpenFieldNearSHS',
    'OpenFieldNearOldBasicEducation',
    'OpenFieldNearGearPublishing',
    'OpenFieldNearLibrary',
    'OpenFieldNearBasketballCourt',
    'OpenFieldNearVolleyballCourt',
    'OpenFieldNearActivityCenter',
    'OpenFieldNearMultiPurpose',
    'EvacuationField',
  ];

  // Check if a waypoint is the Open Field destination (not the gate)
  bool _isOpenFieldDestination(String waypointId) {
    return _openFieldWaypoints.contains(waypointId);
  }

  // Find the nearest OpenField entry point to a given location
  String _findNearestOpenFieldEntry(LatLng location) {
    String nearestId = 'OpenField';
    double smallestDistance = double.infinity;
    
    for (final openFieldId in _openFieldWaypoints) {
      if (!_waypoints.containsKey(openFieldId)) continue;
      
      final openFieldLocation = _waypoints[openFieldId]!;
      final distance = _distance.as(LengthUnit.Meter, location, openFieldLocation);
      
      if (distance < smallestDistance) {
        smallestDistance = distance;
        nearestId = openFieldId;
      }
    }
    
    print('📍 Nearest OpenField entry: $nearestId (${smallestDistance.toStringAsFixed(1)}m away)');
    return nearestId;
  }


  // OpenField center coordinates (middle of open field)
  static const LatLng _openFieldCenter = LatLng(14.262652, 121.398466);
  
  // LSPU Campus boundary polygon based on OpenStreetMap way 121783486
  // These coordinates define the actual campus perimeter
  // Quezon Avenue (longitude ~121.399) is the eastern boundary - routes must not cross it
  static const List<LatLng> _campusBoundaryPolygon = [
    // Northwest corner (near Trade Village area)
    LatLng(14.2639, 121.3953),
    // North edge (moving east)
    LatLng(14.2637, 121.3960),
    LatLng(14.2636, 121.3968),
    LatLng(14.2635, 121.3975),
    LatLng(14.2634, 121.3982),
    // Northeast corner (at Quezon Avenue - this is the critical boundary)
    LatLng(14.2633, 121.3988), // Just before Quezon Avenue
    // East edge (along Quezon Avenue - longitude ~121.3988-121.3990 is the limit)
    LatLng(14.2630, 121.3989),
    LatLng(14.2627, 121.3989),
    LatLng(14.2625, 121.3989), // OpenField area
    LatLng(14.2623, 121.3989),
    LatLng(14.2620, 121.3988),
    // Southeast corner (south of OpenField, before Quezon Avenue)
    LatLng(14.2618, 121.3985),
    // South edge (moving west)
    LatLng(14.2617, 121.3980),
    LatLng(14.2616, 121.3975),
    LatLng(14.2616, 121.3970),
    LatLng(14.2616, 121.3965),
    LatLng(14.2617, 121.3960),
    LatLng(14.2617, 121.3955),
    // Southwest corner
    LatLng(14.2618, 121.3952),
    // West edge (moving north)
    LatLng(14.2620, 121.3950),
    LatLng(14.2625, 121.3949),
    LatLng(14.2630, 121.3950),
    LatLng(14.2635, 121.3951),
    LatLng(14.2637, 121.3952),
    // Close the polygon
    LatLng(14.2639, 121.3953),
  ];

  // Point-in-polygon algorithm to check if a point is inside the campus boundary
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      
      // Check if ray crosses edge
      final yiGreater = yi > point.latitude;
      final yjGreater = yj > point.latitude;
      
      if (yiGreater != yjGreater) {
        // Avoid division by zero
        final denominator = yj - yi;
        if (denominator.abs() > 0.0001) {
          final intersectionX = ((xj - xi) * (point.latitude - yi) / denominator) + xi;
          if (point.longitude < intersectionX) {
            inside = !inside;
          }
        }
      }
      
      j = i;
    }
    
    return inside;
  }

  // Check if a coordinate is within the LSPU campus boundaries
  bool _isWithinCampus(LatLng point) {
    // Quick check: Quezon Avenue is the eastern boundary at longitude ~121.399
    // If longitude is greater than 121.3989, it's definitely outside (beyond Quezon Avenue)
    if (point.longitude > 121.3989) {
      return false;
        }
    
    // Quick check: If latitude is outside the campus range, reject immediately
    if (point.latitude < 14.2615 || point.latitude > 14.2640) {
      return false;
  }

    // Use point-in-polygon check with the actual campus boundary
    if (_isPointInPolygon(point, _campusBoundaryPolygon)) {
      return true;
    }
    
    // Also check if within campus bounds rectangle (fallback)
    if (_campusBounds.contains(point)) {
      // Double-check with polygon for points near the edge
      // If it's clearly outside the polygon, reject it
      // Check if very close to any OpenField entry point (within 150m)
      for (final openFieldId in _openFieldWaypoints) {
        if (!_waypoints.containsKey(openFieldId)) continue;
        
        final openFieldLocation = _waypoints[openFieldId]!;
        final distanceFromOpenField = _distance.as(LengthUnit.Meter, point, openFieldLocation);
        
        if (distanceFromOpenField <= 150) {
          return true;
  }
      }
      return false;
    }
    
    return false;
  }

  // Check if a coordinate is near any Open Field entry point or in walkable open areas
  bool _isNearOpenField(LatLng point) {
    // Check distance to all OpenField entry points
    for (final openFieldId in _openFieldWaypoints) {
      if (!_waypoints.containsKey(openFieldId)) continue;
      
      final openFieldLocation = _waypoints[openFieldId]!;
      final distance = _distance.as(LengthUnit.Meter, point, openFieldLocation);
      
      if (distance < 200) {
        // Within 200 meters of any OpenField entry point
        return true;
      }
    }
    
    return false;
  }

  // Find the intersection point between a line segment and campus boundary
  LatLng? _findBoundaryIntersection(LatLng insidePoint, LatLng outsidePoint) {
    // Binary search to find the boundary point
    LatLng low = insidePoint;
    LatLng high = outsidePoint;
    
    for (int i = 0; i < 10; i++) {
      final midLat = (low.latitude + high.latitude) / 2;
      final midLng = (low.longitude + high.longitude) / 2;
      final midPoint = LatLng(midLat, midLng);
      
      if (_isWithinCampus(midPoint)) {
        low = midPoint;
      } else {
        high = midPoint;
      }
    }
    
    return low; // Return the point just inside the boundary
  }

  // Filter route points to keep them within campus boundaries
  List<LatLng> _filterRouteToStayInCampus(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return routePoints;
    
    List<LatLng> filteredPoints = [];
    LatLng? lastValidPoint;
    
    for (int i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      
      if (_isWithinCampus(point)) {
        // Point is within campus, add it
        filteredPoints.add(point);
        lastValidPoint = point;
      } else {
        // Point is outside campus
        if (lastValidPoint != null) {
          // We have a valid previous point, find where the route crosses the boundary
          final boundaryPoint = _findBoundaryIntersection(lastValidPoint, point);
          if (boundaryPoint != null && _isWithinCampus(boundaryPoint)) {
            filteredPoints.add(boundaryPoint);
            lastValidPoint = boundaryPoint;
          }
        } else if (i == 0) {
          // First point is outside - keep it but log warning
          print('⚠️ Route start point is outside campus, keeping it');
          filteredPoints.add(point);
        }
        
        // Skip this point and continue
        // If this is the last point, we'll handle it below
      }
    }
    
    // Ensure we have valid start and end points
    if (filteredPoints.isEmpty) {
      // If all points were outside, create a route from start to nearest OpenField
      final nearestOpenFieldId = _findNearestOpenFieldEntry(routePoints.first);
      filteredPoints = [routePoints.first, _waypoints[nearestOpenFieldId]!];
    } else {
      // Ensure the route ends at nearest OpenField entry (within campus)
      final lastPoint = filteredPoints.last;
      final nearestOpenFieldId = _findNearestOpenFieldEntry(lastPoint);
      final nearestOpenFieldLocation = _waypoints[nearestOpenFieldId]!;
      
      if (!_isWithinCampus(lastPoint) || 
          _distance.as(LengthUnit.Meter, lastPoint, nearestOpenFieldLocation) > 50) {
        // Last point is outside or far from OpenField, add nearest OpenField as endpoint
        if (filteredPoints.last != nearestOpenFieldLocation) {
          filteredPoints.add(nearestOpenFieldLocation);
          print('📍 Route endpoint adjusted to nearest OpenField entry: $nearestOpenFieldId');
        }
      }
    }
    
    // Remove duplicate consecutive points
    List<LatLng> cleanedPoints = [];
    for (int i = 0; i < filteredPoints.length; i++) {
      if (i == 0 || 
          _distance.as(LengthUnit.Meter, filteredPoints[i], filteredPoints[i - 1]) > 5) {
        cleanedPoints.add(filteredPoints[i]);
      }
    }
    
    // If no valid points, return route to nearest OpenField entry
    if (cleanedPoints.isEmpty && routePoints.isNotEmpty) {
      final nearestOpenFieldId = _findNearestOpenFieldEntry(routePoints.first);
      return [routePoints.first, _waypoints[nearestOpenFieldId]!];
    }
    
    return cleanedPoints;
  }

  // Check if there's a direct walkable path through open areas (no buildings blocking)
  bool _hasDirectWalkablePath(LatLng from, LatLng to, {String? fromWaypointId}) {
    // Check if both points are in areas with open walkable spaces (near open field area)
    final toNearField = _isNearOpenField(to);
    
    // If routing to open field, check if direct path through walkable open areas is possible
    if (toNearField) {
      const openFieldCenter = LatLng(14.262689, 121.398464);
      final fromToFieldDist = _distance.as(LengthUnit.Meter, from, openFieldCenter);
      final toToFieldDist = _distance.as(LengthUnit.Meter, to, openFieldCenter);
      
      // If destination is in open field, allow direct path from nearby buildings
      if (toToFieldDist < 150) {
        // Check if origin is reasonably close (within 200m) - allows direct walkable paths
        if (fromToFieldDist < 200) {
          // Check if path is generally eastward (toward open field) - avoid going through buildings
          // CSS is at 121.397241, OpenField is at 121.398464 - direct east is good
          final longitudeDiff = to.longitude - from.longitude;
          if (longitudeDiff > 0) { // Going east (toward open field)
            return true;
          }
        }
        // Special case: CSS building - always allow direct east route (it's very close)
        if (fromWaypointId == 'CSS') {
          return true;
        }
      }
    }
    
    // Both points near open field - direct path through field
    final fromNearField = _isNearOpenField(from);
    return fromNearField && toNearField;
  }

  // Create a direct route through the open field (walkable area)
  List<LatLng> _createDirectFieldRoute(LatLng from, LatLng to) {
    final distanceMeters = _distance.as(LengthUnit.Meter, from, to);
    
    // For open fields, create a smooth direct path
    // Add more intermediate points for smoother visualization (every 10 meters)
    final numSegments = (distanceMeters / 10).ceil().clamp(5, 50); // 5-50 segments for smoother path
    
    List<LatLng> route = [from];
    
    for (int i = 1; i < numSegments; i++) {
      final ratio = i / numSegments;
      final lat = from.latitude + (to.latitude - from.latitude) * ratio;
      final lng = from.longitude + (to.longitude - from.longitude) * ratio;
      route.add(LatLng(lat, lng));
    }
    
    route.add(to);
    return route;
  }

  // Create a simple route with intermediate waypoints when OSRM is unavailable
  List<LatLng> _createSimpleRoute(LatLng from, LatLng to) {
    final distanceMeters = _distance.as(LengthUnit.Meter, from, to);
    
    // Create intermediate points for a more realistic route
    // Add waypoints every 30-50 meters for smoother visualization
    final numSegments = (distanceMeters / 40).ceil().clamp(3, 30);
    
    List<LatLng> route = [from];
    
    for (int i = 1; i < numSegments; i++) {
      final ratio = i / numSegments;
      final lat = from.latitude + (to.latitude - from.latitude) * ratio;
      final lng = from.longitude + (to.longitude - from.longitude) * ratio;
      route.add(LatLng(lat, lng));
    }
    
    route.add(to);
    return route;
      }

  Future<List<LatLng>> _fetchOSRMFootRoute(LatLng from, LatLng to, {String? fromWaypointId, String? toWaypointId}) async {
    // Always use OSRM for routing - let it find service roads and walkable paths
    // Only use direct paths if points are extremely close (less than 15m) - this is just for very short connections
    final distance = _distance.as(LengthUnit.Meter, from, to);
    if (distance < 15) {
      // Points are extremely close - direct path is fine
      return [from, to];
    }
    
    // For all other routes, use OSRM to find service roads and walkable paths
    
    // Try multiple OSRM servers as fallback
    // Different servers have different URL structures
    final coordString = '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    
    final List<Map<String, String>> osrmServers = [
      {
        'name': 'routing.openstreetmap.de',
        'base': 'https://routing.openstreetmap.de/routed-foot',
      },
      {
        'name': 'router.project-osrm.org',
        'base': 'https://router.project-osrm.org',
      },
    ];
    
    Exception? lastError;
    
    for (final server in osrmServers) {
      try {
        // Try with alternatives first, fallback to simple request if that fails
        String urlString = '${server['base']}/route/v1/foot/$coordString?overview=full&geometries=geojson&alternatives=true&steps=true&number=3';
        var url = Uri.parse(urlString);
        
        print('🔄 Trying OSRM server: ${server['name']}');
      
      final response = await http.get(url).timeout(
          const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Routing request timeout');
        },
      );

      if (response.statusCode != 200) {
          // If 400 error, try simpler request without alternatives
          if (response.statusCode == 400) {
            print('⚠️ Server ${server['name']} returned 400, trying simpler request...');
            urlString = '${server['base']}/route/v1/foot/$coordString?overview=full&geometries=geojson';
            url = Uri.parse(urlString);
            
            final simpleResponse = await http.get(url).timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                throw Exception('Routing request timeout');
              },
            );
            
            if (simpleResponse.statusCode == 200) {
              // Use the simpler response
              final body = jsonDecode(simpleResponse.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      
              if (routes != null && routes.isNotEmpty) {
      final route = routes.first as Map<String, dynamic>;
      final geometry = (route['geometry'] ?? {}) as Map<String, dynamic>;
                final routeCoords = (geometry['coordinates'] ?? []) as List<dynamic>;
      
                final routePoints = routeCoords
          .whereType<List>()
          .where((pair) => pair.length >= 2)
          .map((pair) => LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();

                if (routePoints.isNotEmpty) {
                  // Filter route to ensure it stays within campus boundaries
                  final filteredRoute = _filterRouteToStayInCampus(routePoints);
                  print('✅ OSRM Foot Route (simple): ${(route['distance'] as num?)?.toDouble().toStringAsFixed(0) ?? 'N/A'}m');
                  if (filteredRoute.length != routePoints.length) {
                    print('📍 Filtered route: ${routePoints.length} → ${filteredRoute.length} points (removed points outside campus)');
                  }
                  return filteredRoute;
                }
              }
            }
          }
          
          final errorBody = response.statusCode == 400 && response.body.length > 200 
              ? '${response.body.substring(0, 200)}...' 
              : response.body;
          print('⚠️ Server ${server['name']} returned status ${response.statusCode}: $errorBody');
          lastError = Exception('OSRM routing service returned status ${response.statusCode}');
          continue; // Try next server
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      
      if (routes == null || routes.isEmpty) {
          // OSRM couldn't find a route - this should be rare
          // Only use direct fallback if points are extremely close (less than 20m)
          // Otherwise, retry or indicate routing failure
          print('⚠️ OSRM: No route found between waypoints.');
          if (distance < 20) {
            print('⚠️ Using direct path fallback (very close points: ${distance.toStringAsFixed(1)}m)');
          return [from, to];
        }
          // For longer distances, throw error to try next server
          throw Exception('OSRM could not find a route between waypoints (distance: ${distance.toStringAsFixed(1)}m)');
        }

        // Try to find a route that uses service roads and walkable paths
        // Longer routes (10-25% longer) are more likely to use service roads instead of main roads
        Map<String, dynamic>? selectedRoute;
        
        if (routes.length > 1) {
          final shortestDistance = (routes.first as Map<String, dynamic>)['distance'] as num?;
          if (shortestDistance != null) {
            final shortestDist = shortestDistance.toDouble();
      
            // Look for a route that's 10-25% longer (likely uses service roads)
            // but not too long (>40% longer might be inefficient)
            for (final routeOption in routes) {
              final route = routeOption as Map<String, dynamic>;
              final routeDistance = (route['distance'] as num?)?.toDouble();
              if (routeDistance == null) continue;
              
              final lengthRatio = routeDistance / shortestDist;
              
              // Prefer routes that are 10-25% longer (service roads) over shortest (main roads)
              if (lengthRatio >= 1.10 && lengthRatio <= 1.25) {
                selectedRoute = route;
                print('📍 Selected route ${lengthRatio.toStringAsFixed(2)}x longer (likely uses service roads)');
                break;
              }
            }
            
            // If no route in ideal range, prefer slightly longer routes (5-40% longer)
            if (selectedRoute == null) {
              for (final routeOption in routes) {
                final route = routeOption as Map<String, dynamic>;
                final routeDistance = (route['distance'] as num?)?.toDouble();
                if (routeDistance == null) continue;
                
                final lengthRatio = routeDistance / shortestDist;
                if (lengthRatio >= 1.05 && lengthRatio <= 1.40) {
                  selectedRoute = route;
                  print('📍 Selected route ${lengthRatio.toStringAsFixed(2)}x longer (may use service roads)');
                  break;
                }
              }
            }
          }
        }
        
        // Fallback to first route (shortest) if no better route found
        final route = selectedRoute ?? routes.first as Map<String, dynamic>;
      final geometry = (route['geometry'] ?? {}) as Map<String, dynamic>;
      final coordinates = (geometry['coordinates'] ?? []) as List<dynamic>;
      
        // OSRM returns the route along actual service roads and walkable paths
      final routePoints = coordinates
          .whereType<List>()
          .where((pair) => pair.length >= 2)
          .map((pair) => LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();

      // Log route information for debugging
      final routeDistance = route['distance'] as num?;
      final duration = route['duration'] as num?;
      if (routeDistance != null) {
          final routeType = selectedRoute != null && selectedRoute != routes.first ? ' (preferred service road route)' : '';
          print('✅ OSRM Foot Route$routeType: ${routeDistance.toDouble().toStringAsFixed(0)}m, ${duration != null ? (duration.toDouble() / 60).toStringAsFixed(1) : 'N/A'}min');
      }

        // Return the route points along service roads and walkable paths
        if (routePoints.isEmpty) {
          throw Exception('OSRM returned empty route');
        }
        
        // Filter route to ensure it stays within campus boundaries
        final filteredRoute = _filterRouteToStayInCampus(routePoints);
        if (filteredRoute.length != routePoints.length) {
          print('📍 Filtered route: ${routePoints.length} → ${filteredRoute.length} points (removed points outside campus)');
        }
        return filteredRoute; // Success! Return the filtered route
    } catch (e) {
        print('❌ OSRM routing error from ${server['name']}: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        continue; // Try next server
      }
    }
    
    // All OSRM servers failed - use fallback route
    print('⚠️ All OSRM servers failed, using fallback route');
    
    if (distance < 20) {
      print('⚠️ Using direct path fallback (very close points: ${distance.toStringAsFixed(1)}m)');
        return [from, to];
      }
    
    // For longer distances, create a simple route with intermediate points
    print('⚠️ Creating simple fallback route (${distance.toStringAsFixed(1)}m)');
    final fallbackRoute = _createSimpleRoute(from, to);
    // Filter to ensure it stays within campus
    return _filterRouteToStayInCampus(fallbackRoute);
    }

  // Find the nearest walkable waypoint to OpenField (courts, activity center, etc.)
  // These are waypoints that have walkable paths/service roads leading to OpenField
  String _findNearestWalkableWaypointToOpenField(LatLng location) {
    // List of walkable waypoints near OpenField that can be used as intermediate points
    final walkableWaypoints = [
      'BasketballCourt',
      'VolleyballCourt',
      'ActivityCenter',
      'UniversityGrandstand',
    ];
    
    String nearestId = 'BasketballCourt';
    double smallestDistance = double.infinity;
    
    for (final waypointId in walkableWaypoints) {
      if (!_waypoints.containsKey(waypointId)) continue;
      
      final waypointLocation = _waypoints[waypointId]!;
      final distance = _distance.as(LengthUnit.Meter, location, waypointLocation);
      
      if (distance < smallestDistance) {
        smallestDistance = distance;
        nearestId = waypointId;
      }
    }
    
    print('📍 Nearest walkable waypoint to OpenField: $nearestId (${smallestDistance.toStringAsFixed(1)}m away)');
    return nearestId;
  }

  // Manual route selection for testing purposes only
  // Real routes use GPS location automatically
  // Let OSRM handle the routing - it will automatically use service roads and walkable paths
  Future<void> _createTestRoute(String startBuildingId) async {
    if (!_waypoints.containsKey(startBuildingId)) {
      setState(() {
        _statusMessage = 'Invalid start location selected.';
      });
      return;
    }

    final startLocation = _waypoints[startBuildingId]!;
    
    // Use the main OpenField location (middle of open field)
    final openFieldLocation = _waypoints['OpenField']!;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Calculating test route via service roads...';
      _selectedStartLocation = startBuildingId;
    });

    try {
      // Let OSRM handle the routing directly from building to OpenField
      // OSRM will automatically use service roads and walkable paths
      print('🛣️ Routing from $startBuildingId to OpenField via OSRM (service roads)...');
      final routePoints = await _fetchOSRMFootRoute(
        startLocation,
        openFieldLocation,
        fromWaypointId: startBuildingId,
        toWaypointId: 'OpenField',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _activeRoutePoints = routePoints;
        _activeStepIds = [startBuildingId, 'OpenField'];
        final routeDescription = '${_waypointLabels[startBuildingId]} → ${_waypointLabels['OpenField']}';
        _statusMessage = 'Route: $routeDescription';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to calculate route: $e';
        _activeRoutePoints = [];
        _activeStepIds = [];
      });
    }
  }

  void _clearRoute() {
    if (!mounted) return;
    setState(() {
      _activeRoutePoints = [];
      _activeStepIds = [];
      _selectedStartLocation = null;
      // If GPS is available, recalculate route from GPS location
      if (_userLocation != null) {
        _createRouteFromGPSLocation(_userLocation!);
      } else {
        _statusMessage = 'Waiting for GPS location...';
      }
    });
  }

  void _showStartLocationDialog() {
    final buildings = _waypointLabels.keys
        .where((key) => key != 'OpenField' && 
                       key != 'EvacuationField' && 
                       key != 'CASCorner' && 
                       key != 'AcademicWalk' && 
                       key != 'ActivityWalk')
        .toList()
      ..sort((a, b) => _waypointLabels[a]!.compareTo(_waypointLabels[b]!));

    String? selectedBuilding = _selectedStartLocation;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Test Route (Manual Selection)'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                      ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This is for testing only. Real routes use your GPS location automatically.',
                                style: TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose a starting building. Route will go to Open Field.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: ListView.separated(
                          itemCount: buildings.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            final building = buildings[index];
                            return RadioListTile<String>(
                              title: Text(
                                _waypointLabels[building] ?? building,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: building,
                              groupValue: selectedBuilding,
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedBuilding = value;
                                  });
                                }
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedBuilding == null
                      ? null
                      : () {
                    Navigator.of(dialogContext).pop();
                          _createTestRoute(selectedBuilding!);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Evacuation Route'),
        actions: [
          IconButton(
            tooltip: 'Test Route (Manual Selection)',
            onPressed: () => _showStartLocationDialog(),
            icon: const Icon(Icons.location_on),
          ),
          IconButton(
            tooltip: 'Clear Route / Reset to GPS',
            onPressed: _activeRoutePoints.isEmpty
                ? null
                : () => _clearRoute(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double mapHeight = (constraints.maxHeight * 0.45)
                .clamp(220.0, constraints.maxHeight)
                .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLoading)
                      const LinearProgressIndicator(minHeight: 3)
                    else
                      const SizedBox(height: 3),
                    _buildAlertCard(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: mapHeight,
                        child: _buildMap(),
                      ),
                    ),
                    _buildRoutePanel(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlertCard() {
    final hasRoute = _activeRoutePoints.isNotEmpty;
    final isGPSRoute = _activeStepIds.isNotEmpty && _activeStepIds.first == 'GPS';
    final isTestRoute = _selectedStartLocation != null;
    
    String subtitle = _statusMessage ?? '';
    if (subtitle.isEmpty) {
      if (hasRoute) {
        if (isGPSRoute) {
          subtitle = 'GPS-based route to OpenField (auto-updates as you move)';
        } else {
          subtitle = 'Test route: ${_waypointLabels[_selectedStartLocation] ?? "Building"} → OpenField';
        }
      } else {
        if (_userLocation != null) {
          subtitle = 'Calculating route from your GPS location...';
        } else {
          subtitle = 'Waiting for GPS location. Use manual selection for testing.';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: hasRoute 
                ? (isGPSRoute ? Colors.blue : Colors.green)
                : Colors.blueGrey,
            child: Icon(
              hasRoute 
                  ? (isGPSRoute ? Icons.my_location : Icons.route)
                  : Icons.location_searching,
              color: Colors.white,
            ),
          ),
          title: Text(
            hasRoute 
                ? (isGPSRoute ? 'GPS Route Active' : 'Test Route Active')
                : (_userLocation != null ? 'Waiting for Route' : 'No GPS Location'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle),
          trailing: hasRoute
              ? Icon(
                  isGPSRoute ? Icons.gps_fixed : Icons.check_circle,
                  color: isGPSRoute ? Colors.blue : Colors.green,
                )
              : const Icon(Icons.arrow_forward, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>[];

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 32,
          ),
        ),
      );
    }

    if (_activeRoutePoints.isNotEmpty) {
      markers.addAll([
        Marker(
          point: _activeRoutePoints.first,
          width: 46,
          height: 46,
          child: _buildWaypointMarker(
            label: 'START',
            color: Colors.green,
          ),
        ),
        Marker(
          point: _activeRoutePoints.last,
          width: 46,
          height: 46,
          child: _buildWaypointMarker(
            label: 'SAFE',
            color: Colors.redAccent,
          ),
        ),
      ]);
    }

    final circles = <CircleMarker>[];
    if (_userLocation != null && _locationAccuracy != null) {
      circles.add(
        CircleMarker(
          point: _userLocation!,
          color: Colors.blue.withOpacity(0.1),
          borderColor: Colors.blueAccent.withOpacity(0.4),
          useRadiusInMeter: true,
          radius: _locationAccuracy!.clamp(10, 45).toDouble(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _userLocation ?? _campusCenter,
          initialZoom: _defaultZoom,
          minZoom: 17,
          maxZoom: 19.5,
          cameraConstraint: CameraConstraint.contain(bounds: _campusBounds),
          maxBounds: _campusBounds,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.lspu.dres',
            tileProvider: NetworkTileProvider(
              headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            ),
          ),
          if (_activeRoutePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _activeRoutePoints,
                  strokeWidth: 6,
                  color: Colors.red.shade500,
                ),
              ],
            ),
          if (circles.isNotEmpty) CircleLayer(circles: circles),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  Widget _buildWaypointMarker({required String label, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoutePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _activeStepIds.isEmpty
              ? Column(
                  children: [
                    const Icon(Icons.route, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No route selected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userLocation != null
                          ? 'Calculating route from your GPS location to OpenField...'
                          : 'Waiting for GPS location. Tap the location icon for manual testing.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Steps',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ..._activeStepIds.asMap().entries.map(
                      (entry) {
                        final stepIndex = entry.key + 1;
                        final waypoint = entry.value;
                        // Handle GPS step ID
                        final label = waypoint == 'GPS' 
                            ? 'Your Location (GPS)'
                            : (_waypointLabels[waypoint] ?? waypoint);
                        final isLast = stepIndex == _activeStepIds.length;
                        final isGPS = waypoint == 'GPS';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isLast
                                    ? Colors.green.shade600
                                    : (isGPS ? Colors.blue.shade600 : Colors.blue.shade600),
                                child: isGPS
                                    ? const Icon(Icons.my_location, size: 14, color: Colors.white)
                                    : Text(
                                  '$stepIndex',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isLast ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              ),
                              if (isLast)
                                const Icon(Icons.flag, color: Colors.green, size: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

