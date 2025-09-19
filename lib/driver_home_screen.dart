import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/driver_location_service.dart';
import '../services/map_service.dart';
import '../models/bus_stop.dart';
import '../models/route.dart' as route_models;
import '../models/destination.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  mapbox.MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  final MapService _mapService = MapService();
  final AuthService _authService = AuthService();
  final DriverLocationService _driverLocationService = DriverLocationService();
  List<BusStop> _busStops = [];
  route_models.Route? _currentRoute;
  Destination? _currentDestination;
  bool _isLoading = true;
  int _selectedIndex = 0;
  String? _driverId;
  double _searchRadius = 5.0;
  Timer? _locationUpdateTimer;
  Timer? _busStopUpdateTimer;
  Timer? _routeUpdateTimer;
  bool _useCustomMarker = true;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;
  BusStop? _selectedBusStop;
  String? _currentBusStopId; // To track passenger count for active trip
  bool _isTripCardMinimized = false; // To toggle minimized trip card

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    _initializeDriverId();
    _requestLocationPermission();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _busStopUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _initializeDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final profileResult = await _authService.fetchDriverProfile();
    if (profileResult['success']) {
      setState(() {
        _driverId = profileResult['data']['driver_id']?.toString();
        print("✅ Driver ID: $_driverId");
      });
    } else {
      print("❌ Error fetching driver profile: ${profileResult['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                profileResult['message'] ?? 'Error fetching driver profile')),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    print("ℹ️ Location permission status: $status");
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
      print("ℹ️ Requested permission, new status: $status");
      if (status.isDenied) {
        print("❌ Location permission denied");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _isLoading = false);
        return;
      }
      if (status.isPermanentlyDenied) {
        print("❌ Location permission permanently denied");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission permanently denied'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
    }
    if (status.isGranted) {
      print("✅ Location permission granted");
      await _showUserLocation();
      await _fetchBusStops();
      await _startBusStopUpdates();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _startLocationUpdates() async {
    _locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        final addressResult = await _mapService.fetchReverseGeocoding(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        String address = addressResult['success']
            ? addressResult['data']['place_name']?.toString() ?? 'Unknown'
            : 'Unknown';
        print(
            "📍 Updating location: ${position.latitude}, ${position.longitude}, address: $address");
        final result = await _driverLocationService.updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );
        if (!result['success']) {
          print("❌ Failed to update location: ${result['message']}");
          if (result['message'] == 'Unauthorized. Please log in again.') {
            Navigator.pushReplacementNamed(context, '/signin');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(result['message'] ?? 'Failed to update location')),
          );
        }
      } catch (e) {
        print("❌ Error updating location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update location')),
        );
      }
    });
  }

  Future<void> _startBusStopUpdates() async {
    if (_busStopUpdateTimer != null) {
      print("ℹ️ Bus stop update timer already running");
      return;
    }
    if (mapboxMap == null) {
      print("❌ Mapbox map not initialized, delaying bus stop polling");
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        return mapboxMap == null;
      });
      print("✅ Mapbox map initialized, starting bus stop polling");
    }
    _busStopUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentDestination != null) {
        print("ℹ️ Updating bus stop during active trip");
        try {
          print("📡 Starting periodic bus stop update");
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
          );
          final result = await _mapService.fetchBusStops(
            latitude: position.latitude,
            longitude: position.longitude,
            radius: _searchRadius,
          );
          if (result['success']) {
            final features = result['data']['features'] as List<dynamic>? ?? [];
            print("🚌 Found ${features.length} bus stops");
            setState(() {
              _busStops = features.map((f) => BusStop.fromJson(f)).toList();
              if (_selectedBusStop != null) {
                _selectedBusStop = _busStops.firstWhereOrNull(
                    (stop) => stop.systemId == _selectedBusStop!.systemId);
              }
            });
            await _addBusStopMarkers();
          }
        } catch (e) {
          print("❌ Error in periodic bus stop update: $e");
        }
      } else {
        try {
          print("📡 Starting periodic bus stop update");
          await _fetchBusStops();
        } catch (e) {
          print("❌ Error in periodic bus stop update: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update bus stops')),
          );
        }
      }
    });
  }

  Future<void> _startRouteUpdates() async {
    if (_routeUpdateTimer != null) {
      print("ℹ️ Route update timer already running");
      return;
    }
    _routeUpdateTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_currentDestination == null || _driverId == null) return;
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        final routeResult = await _mapService.fetchRoute(
          driverId: _driverId!,
          destination: _currentDestination!.routeName.split(' to ').last,
          systemId: _currentDestination!.routeName.split(' to ').first,
          destLat: _currentDestination!.endLatitude,
          destLng: _currentDestination!.endLongitude,
          startLat: position.latitude,
          startLng: position.longitude,
        );
        if (routeResult['success']) {
          setState(() {
            _currentRoute = route_models.Route.fromJson(routeResult['data']);
          });
          await _showRoute(_currentRoute!);
          await mapboxMap?.flyTo(
            CameraOptions(
              center: mapbox.Point(
                coordinates:
                    mapbox.Position(position.longitude, position.latitude),
              ),
              zoom: 14.0,
            ),
            MapAnimationOptions(duration: 1000),
          );
        }
      } catch (e) {
        print("❌ Error updating route: $e");
      }
    });
  }

  Future<void> _fetchBusStops() async {
    if (mapboxMap == null) {
      print("❌ Mapbox map not initialized, skipping bus stop fetch");
      return;
    }
    const maxRetries = 3;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        print(
            "📍 Fetching bus stops for lat: ${position.latitude}, lon: ${position.longitude}, radius: $_searchRadius");
        final result = await _mapService.fetchBusStops(
          latitude: position.latitude,
          longitude: position.longitude,
          radius: _searchRadius,
        );
        print("📡 Full Bus Stops Response: $result");
        if (result['success']) {
          final features = result['data']['features'] as List<dynamic>? ?? [];
          print("🚌 Found ${features.length} bus stops");
          setState(() {
            _busStops = features.map((f) => BusStop.fromJson(f)).toList();
            if (_selectedBusStop != null) {
              _selectedBusStop = _busStops.firstWhereOrNull(
                  (stop) => stop.systemId == _selectedBusStop!.systemId);
            }
          });
          await _addBusStopMarkers();
          return;
        } else {
          print("❌ API error: ${result['message']}");
          if (result['message']?.contains('503') ?? false) {
            retryCount++;
            print("🔄 Retrying fetch bus stops ($retryCount/$maxRetries)");
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Error fetching bus stops')),
          );
          return;
        }
      } catch (e) {
        print("❌ Error fetching bus stops: $e");
        if (e.toString().contains('503')) {
          retryCount++;
          print("🔄 Retrying fetch bus stops ($retryCount/$maxRetries)");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch bus stops')),
        );
        return;
      }
    }
    print("❌ Max retries reached for fetching bus stops");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to fetch bus stops after retries')),
    );
  }

  Future<void> _addBusStopMarkers() async {
    print("🛠️ Adding ${_busStops.length} bus stop markers");
    await pointAnnotationManager?.deleteAll();
    final manager = await mapboxMap?.annotations.createPointAnnotationManager();
    if (manager == null) {
      print("❌ Failed to create PointAnnotationManager");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create marker manager')),
      );
      return;
    }
    for (var stop in _busStops) {
      try {
        print(
            "🚌 Adding marker for ${stop.systemId} at (${stop.latitude}, ${stop.longitude})");
        await manager.create(PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(stop.longitude, stop.latitude),
          ),
          iconImage: _useCustomMarker ? 'blue-marker' : 'marker',
          iconSize: 1.5,
          textField: stop.systemId,
          textOffset: [0.0, -2.0],
        ));
      } catch (e) {
        print("❌ Failed to add marker for ${stop.systemId}: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add marker for ${stop.systemId}: $e')),
        );
      }
    }
    pointAnnotationManager = manager;
    print("✅ Finished adding markers");
  }

  Future<void> _showUserLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      final center = mapbox.Point(
        coordinates: mapbox.Position(position.longitude, position.latitude),
      );
      await mapboxMap?.flyTo(
        CameraOptions(center: center, zoom: 14.0),
        MapAnimationOptions(duration: 1000),
      );
      await pointAnnotationManager?.deleteAll();
      final manager =
          await mapboxMap?.annotations.createPointAnnotationManager();
      if (manager == null) {
        print("❌ Failed to create PointAnnotationManager for user location");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create marker manager')),
        );
        return;
      }
      await manager.create(PointAnnotationOptions(
        geometry: center,
        iconImage: _useCustomMarker ? 'blue-marker' : 'marker',
        iconSize: 2.0,
      ));
      pointAnnotationManager = manager;
      print(
          "📍 User location marker added: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("❌ Error showing user location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to show user location')),
      );
    }
  }

  Future<void> _showRoute(route_models.Route route) async {
    try {
      if (route.coordinates == null) {
        print("❌ Route coordinates are null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route coordinates are missing')),
        );
        return;
      }
      final geoJsonData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': route.coordinates,
            },
            'properties': {'color': '#FF0000', 'width': 4.0},
          },
        ],
      };
      final jsonString = jsonEncode(geoJsonData);

      final style = mapboxMap?.style;
      if (style != null) {
        final layers = await style.getStyleLayers();
        final sources = await style.getStyleSources();
        if (layers.any((layer) => layer?.id == 'route-line-layer')) {
          await style.removeStyleLayer('route-line-layer');
          print("✅ Removed existing route-line-layer");
        }
        if (sources.any((source) => source?.id == 'route-line-source')) {
          await style.removeStyleSource('route-line-source');
          print("✅ Removed existing route-line-source");
        }
      }

      await mapboxMap?.style.addSource(
        GeoJsonSource(id: 'route-line-source', data: jsonString),
      );
      await mapboxMap?.style.addLayer(
        LineLayer(
          id: 'route-line-layer',
          sourceId: 'route-line-source',
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineOpacity: 0.7,
          lineColor: Colors.red.value,
          lineWidth: 8.0,
        ),
      );

      final bounds = _calculateBounds(route.coordinates!);
      await mapboxMap?.flyTo(
        CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(
              (bounds[0][0] + bounds[1][0]) / 2,
              (bounds[0][1] + bounds[1][1]) / 2,
            ),
          ),
          zoom: 13.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      print("✅ Route displayed");
      setState(() {});
    } catch (e) {
      print("❌ Error showing route: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to show route: $e')),
      );
    }
  }

  List<List<double>> _calculateBounds(List<List<double>> coordinates) {
    double minLon = coordinates[0][0];
    double maxLon = coordinates[0][0];
    double minLat = coordinates[0][1];
    double maxLat = coordinates[0][1];
    for (var coord in coordinates) {
      minLon = minLon < coord[0] ? minLon : coord[0];
      maxLon = maxLon > coord[0] ? maxLon : coord[0];
      minLat = minLat < coord[1] ? minLat : coord[1];
      maxLat = maxLat > coord[1] ? maxLat : coord[1];
    }
    return [
      [minLon, minLat],
      [maxLon, maxLat]
    ];
  }

  void _showBusStopDialog(BusStop stop) {
    setState(() {
      _selectedBusStop = stop;
      _isTripCardMinimized = false; // Ensure trip card is not minimized
    });
    print("ℹ️ Showing bus stop dialog for ${stop.systemId}");
    _animationController?.forward();
  }

  Future<void> _acceptTrip(BusStop stop) async {
    if (_driverId == null) {
      print("❌ Driver ID not found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID not found')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken == null) {
      print("❌ Access token missing, redirecting to signin");
      Navigator.pushReplacementNamed(context, '/signin');
      return;
    }
    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    final routeResult = await _mapService.fetchRoute(
      driverId: _driverId!,
      destination: stop.destinations.keys.first,
      systemId: stop.systemId,
      destLat: stop.latitude,
      destLng: stop.longitude,
      startLat: position.latitude,
      startLng: position.longitude,
    );
    print("🟣 Full Fetch Route Response: $routeResult");
    if (routeResult['success']) {
      setState(() {
        _currentRoute = route_models.Route.fromJson(routeResult['data']);
        _currentBusStopId = stop.systemId; // Store for passenger updates
        _selectedBusStop = null; // Switch to trip card
        _isTripCardMinimized = false; // Show full trip card
      });
      await _showRoute(_currentRoute!);
      await mapboxMap?.flyTo(
        CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(position.longitude, position.latitude),
          ),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      final destinationResult = await _driverLocationService.createDestination(
        routeName: '${stop.systemId} to ${stop.destinations.keys.first}',
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: stop.latitude,
        endLongitude: stop.longitude,
        availabilityStatus: 'available',
      );
      print("🟣 Full Create Destination Response: $destinationResult");
      if (destinationResult['success']) {
        print("✅ Setting _currentDestination: ${destinationResult['data']}");
        setState(() {
          _currentDestination = Destination.fromJson(destinationResult['data']);
          print("✅ _currentDestination set: ${_currentDestination?.routeName}");
        });
        // Ensure animation is reset and then forwarded
        if (_animationController != null) {
          print("ℹ️ Resetting and forwarding animation for trip card");
          await _animationController!.reverse();
          await _animationController!.forward();
        } else {
          print("❌ Animation controller is null");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Animation controller error')),
          );
        }
        _startRouteUpdates();
      } else {
        print(
            "❌ Failed to create destination: ${destinationResult['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(destinationResult['message'] ?? 'Error accepting trip')),
        );
        setState(() {
          _selectedBusStop = null;
          _isTripCardMinimized = false;
        });
        await _animationController?.reverse();
      }
    } else {
      print("❌ Failed to fetch route: ${routeResult['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(routeResult['message'] ?? 'Error fetching route')),
      );
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = false;
      });
      await _animationController?.reverse();
    }
  }

  Future<void> _arrivedAtDestination() async {
    _routeUpdateTimer?.cancel();
    if (_currentDestination == null) {
      print("⚠️ No destination to mark as arrived, clearing route");
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
        _currentBusStopId = null;
        _isTripCardMinimized = false;
      });
      await _clearRouteLayer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrived at destination')),
      );
      await _animationController?.reverse();
      return;
    }
    final result = await _driverLocationService.updateDestination(
      _currentDestination!.destinationId,
      'not_available',
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
        _currentBusStopId = null;
        _isTripCardMinimized = false;
      });
      await _clearRouteLayer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrived at destination')),
      );
      await _animationController?.reverse();
    } else {
      print("❌ Failed to update destination: ${result['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Error updating destination')),
      );
    }
  }

  Future<void> _cancelTrip() async {
    _routeUpdateTimer?.cancel();
    if (_currentDestination == null) {
      print("⚠️ No destination to cancel, clearing route");
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
        _currentBusStopId = null;
        _isTripCardMinimized = false;
      });
      await _clearRouteLayer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled')),
      );
      await _animationController?.reverse();
      return;
    }
    final result = await _driverLocationService.updateDestination(
      _currentDestination!.destinationId,
      'not_available',
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
        _currentBusStopId = null;
        _isTripCardMinimized = false;
      });
      await _clearRouteLayer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled')),
      );
      await _animationController?.reverse();
    } else {
      print("❌ Failed to cancel trip: ${result['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error cancelling trip')),
      );
    }
  }

  Future<void> _clearRouteLayer() async {
    try {
      final style = mapboxMap?.style;
      if (style != null) {
        final layers = await style.getStyleLayers();
        final sources = await style.getStyleSources();
        if (layers.any((layer) => layer?.id == 'route-line-layer')) {
          await style.removeStyleLayer('route-line-layer');
          print("✅ Removed route-line-layer");
        }
        if (sources.any((source) => source?.id == 'route-line-source')) {
          await style.removeStyleSource('route-line-source');
          print("✅ Removed route-line-source");
        }
      }
    } catch (e) {
      print("❌ Error clearing route layer: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      Navigator.pushNamed(context, '/wallet');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/vehicles');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/documents');
    } else if (index == 4) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    print("🗺️ Map created");
    try {
      final byteData = await rootBundle.load('assets/images/bus_stop.png');
      final bytes = byteData.buffer.asUint8List();
      final image = mapbox.MbxImage(
        width: 64,
        height: 64,
        data: bytes,
      );
      await mapboxMap.style.addStyleImage(
        'blue-marker',
        1.0,
        image,
        true,
        [],
        [],
        null,
      );
      print("✅ Added blue-marker to map style");
      setState(() {
        _useCustomMarker = true;
      });
    } catch (e) {
      print("❌ Failed to load or add blue-marker image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load marker image: $e')),
      );
      print("ℹ️ Falling back to default 'marker'");
      setState(() {
        _useCustomMarker = false;
      });
    }
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        puckBearingEnabled: true,
        showAccuracyRing: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    print(
        "ℹ️ Building UI: _selectedBusStop=${_selectedBusStop?.systemId}, _currentDestination=${_currentDestination?.routeName}, _isTripCardMinimized=$_isTripCardMinimized");

    // Determine which widget to render and log the appropriate message
    Widget bottomSheetChild;
    if (_selectedBusStop != null) {
      print("ℹ️ Rendering bus stop card for ${_selectedBusStop!.systemId}");
      bottomSheetChild = _buildBusStopCard(_selectedBusStop!);
    } else if (_isTripCardMinimized) {
      print("ℹ️ Rendering minimized trip card");
      bottomSheetChild = _buildMinimizedTripCard();
    } else {
      print("ℹ️ Rendering full trip card");
      bottomSheetChild = _buildTripCard();
    }

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri: MapboxStyles.STANDARD,
            onMapCreated: _onMapCreated,
            onTapListener: (context) {
              final latitude = context.point.coordinates.lat.toDouble();
              final longitude = context.point.coordinates.lng.toDouble();
              print(
                  "OnTap coordinate: {$longitude, $latitude} point: {x: ${context.touchPosition.x}, y: ${context.touchPosition.y}}");
              final tappedStop = _busStops.firstWhereOrNull((stop) {
                final isNear = _isPointNearCoordinates(
                  stop.latitude,
                  stop.longitude,
                  latitude,
                  longitude,
                  tolerance: 0.005,
                );
                print("Checking stop ${stop.systemId}: isNear=$isNear");
                return isNear;
              });
              if (tappedStop != null) {
                print("✅ Tapped stop: ${tappedStop.systemId}");
                _showBusStopDialog(tappedStop);
              } else if (_currentDestination != null) {
                print(
                    "ℹ️ Tapped outside during active trip, toggling minimization");
                setState(() {
                  _selectedBusStop = null;
                  _isTripCardMinimized = !_isTripCardMinimized;
                });
                if (_isTripCardMinimized) {
                  _animationController?.reverse();
                } else {
                  _animationController?.forward();
                }
              } else {
                print("❌ No stop tapped, no active trip");
                setState(() {
                  _selectedBusStop = null;
                  _isTripCardMinimized = false;
                });
                _animationController?.reverse();
              }
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_selectedBusStop != null || _currentDestination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation!,
                child: Container(
                  height: _isTripCardMinimized
                      ? screenHeight * 0.15
                      : screenHeight * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: bottomSheetChild,
                ),
              ),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: DropdownButton<double>(
              value: _searchRadius,
              items: [1.0, 2.0, 5.0, 10.0]
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text('$r km'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _searchRadius = value!);
                _fetchBusStops();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Recenter & Show Marker',
        onPressed: _showUserLocation,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_car), label: 'Vehicles'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Documents'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBusStopCard(BusStop stop) {
    print("ℹ️ Building bus stop card for ${stop.systemId}");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stop.systemId,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedBusStop = null;
                  });
                  _animationController?.reverse();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Total Passengers: ${stop.totalCount ?? 0}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Destinations:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: stop.destinations.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value ?? 0}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedBusStop = null;
                  });
                  _animationController?.reverse();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _acceptTrip(stop),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard() {
    final passengerCount = _currentBusStopId != null
        ? _busStops
                .firstWhereOrNull((stop) => stop.systemId == _currentBusStopId)
                ?.totalCount ??
            0
        : 0;
    print(
        "ℹ️ Building trip card: route=${_currentDestination?.routeName}, passengers=$passengerCount");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentDestination != null
                ? 'Trip to ${_currentDestination!.routeName}'
                : 'Trip in progress',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_currentRoute != null) ...[
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ETA: ${(_currentRoute!.eta / 60).toStringAsFixed(1)} min',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${(_currentRoute!.distance / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Passengers: $passengerCount',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _arrivedAtDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Arrived'),
              ),
              ElevatedButton(
                onPressed: _cancelTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedTripCard() {
    final passengerCount = _currentBusStopId != null
        ? _busStops
                .firstWhereOrNull((stop) => stop.systemId == _currentBusStopId)
                ?.totalCount ??
            0
        : 0;
    print(
        "ℹ️ Building minimized trip card: route=${_currentDestination?.routeName}, passengers=$passengerCount");
    return GestureDetector(
      onTap: () {
        setState(() {
          _isTripCardMinimized = false;
        });
        _animationController?.forward();
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentDestination != null
                        ? _currentDestination!.routeName
                        : 'Trip in progress',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (_currentRoute != null) ...[
                    Text(
                      'ETA: ${(_currentRoute!.eta / 60).toStringAsFixed(1)} min',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      'Dist: ${(_currentRoute!.distance / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                  Text(
                    'Pass: $passengerCount',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_upward,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  bool _isPointNearCoordinates(
      double lat1, double lon1, double lat2, double lon2,
      {double tolerance = 0.005}) {
    print("Comparing ($lat1, $lon1) to ($lat2, $lon2)");
    return (lat1 - lat2).abs() < tolerance && (lon1 - lon2).abs() < tolerance;
  }
}
