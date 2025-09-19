import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:collection/collection.dart';
import 'package:mobileapp/utils/helpers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/driver_location_service.dart';
import '../services/map_service.dart';
import '../models/bus_stop.dart';
import '../models/route.dart' as route_models;
import '../models/destination.dart';
import '../utils/map_utils.dart';
import '../utils/ui_components.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? pointAnnotationManager;
  final MapService _mapService = MapService();
  final AuthService _authService = AuthService();
  final DriverLocationService _driverLocationService = DriverLocationService();
  final MapUtils _mapUtils = MapUtils();
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
  String? _currentBusStopId;
  bool _isTripCardMinimized = false;

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
      await _mapUtils.showUserLocation(
          mapboxMap, pointAnnotationManager, context);
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
            await _mapUtils.addBusStopMarkers(
                mapboxMap, pointAnnotationManager, _busStops, context);
            await _mapUtils.fitMapToBounds(mapboxMap, position, _busStops);
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
          await _mapUtils.showRoute(mapboxMap, _currentRoute!, context);
          await mapboxMap?.flyTo(
            mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates:
                    mapbox.Position(position.longitude, position.latitude),
              ),
              zoom: 14.0,
            ),
            mapbox.MapAnimationOptions(duration: 1000),
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
          await _mapUtils.addBusStopMarkers(
              mapboxMap, pointAnnotationManager, _busStops, context);
          await _mapUtils.fitMapToBounds(mapboxMap, position, _busStops);
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
    if (!routeResult['success']) {
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
      return;
    }

    setState(() {
      _currentRoute = route_models.Route.fromJson(routeResult['data']);
      _currentBusStopId = stop.systemId;
      _selectedBusStop = null;
      _isTripCardMinimized = false;
    });
    await _mapUtils.showRoute(mapboxMap, _currentRoute!, context);
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
    if (!destinationResult['success']) {
      print("❌ Failed to create destination: ${destinationResult['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(destinationResult['message'] ?? 'Error accepting trip')),
      );
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = false;
        _currentRoute = null;
        _currentBusStopId = null;
      });
      await _animationController?.reverse();
      return;
    }

    try {
      setState(() {
        _currentDestination = Destination.fromJson(destinationResult['data']);
        print("✅ _currentDestination set: ${_currentDestination?.routeName}");
      });
    } catch (e) {
      print("❌ Error parsing destination: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error parsing destination data')),
      );
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = false;
        _currentRoute = null;
        _currentBusStopId = null;
      });
      await _animationController?.reverse();
      return;
    }

    if (_animationController != null) {
      print("ℹ️ Resetting and forwarding animation for trip card");
      _animationController!.reset();
      await _animationController!.forward();
    } else {
      print("❌ Animation controller is null");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animation controller error')),
      );
    }
    _startRouteUpdates();
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
      await _mapUtils.clearRouteLayer(mapboxMap);
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
      await _mapUtils.clearRouteLayer(mapboxMap);
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
      await _mapUtils.clearRouteLayer(mapboxMap);
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
      await _mapUtils.clearRouteLayer(mapboxMap);
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
      pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: Colors.blue.value,
          pulsingMaxRadius: 100.0,
          puckBearingEnabled: true,
          showAccuracyRing: false,
        ),
      );
    } catch (e) {
      print("❌ Error in onMapCreated: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing map: $e')),
      );
      setState(() {
        _useCustomMarker = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).padding.bottom;
    print(
        "ℹ️ Building UI: _selectedBusStop=${_selectedBusStop?.systemId}, _currentDestination=${_currentDestination?.routeName}, _isTripCardMinimized=$_isTripCardMinimized");

    Widget bottomSheetChild;
    if (_selectedBusStop != null) {
      print("ℹ️ Rendering bus stop card for ${_selectedBusStop!.systemId}");
      bottomSheetChild = UIComponents.buildBusStopCard(
        _selectedBusStop!,
        () {
          setState(() => _selectedBusStop = null);
          _animationController?.reverse();
        },
        () => _acceptTrip(_selectedBusStop!),
      );
    } else if (_currentDestination != null) {
      if (_isTripCardMinimized) {
        print("ℹ️ Rendering minimized trip card");
        bottomSheetChild = UIComponents.buildMinimizedTripCard(
          _currentDestination!,
          _currentRoute,
          _currentBusStopId,
          _busStops,
          () {
            setState(() => _isTripCardMinimized = false);
            _animationController?.forward();
          },
        );
      } else {
        print("ℹ️ Rendering full trip card");
        bottomSheetChild = UIComponents.buildTripCard(
          _currentDestination!,
          _currentRoute,
          _currentBusStopId,
          _busStops,
          _arrivedAtDestination,
          _cancelTrip,
        );
      }
    } else {
      print("ℹ️ No trip or bus stop selected, hiding bottom sheet");
      bottomSheetChild = const SizedBox.shrink();
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
              final tappedStop = _busStops
                  .firstWhereOrNull((stop) => Helpers.isPointNearCoordinates(
                        stop.latitude,
                        stop.longitude,
                        latitude,
                        longitude,
                        tolerance: 0.005,
                      ));
              if (tappedStop != null) {
                print("✅ Tapped stop: ${tappedStop.systemId}");
                setState(() {
                  _selectedBusStop = tappedStop;
                  _isTripCardMinimized = false;
                });
                _animationController?.forward();
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
              bottom: safePadding + 56.0,
              left: 16.0,
              child: SlideTransition(
                position: _slideAnimation!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isTripCardMinimized
                      ? 300.0
                      : MediaQuery.of(context).size.width - 32.0,
                  height: _isTripCardMinimized ? 80.0 : screenHeight * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                  .map((r) => DropdownMenuItem(value: r, child: Text('$r km')))
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
        onPressed: () => _mapUtils.showUserLocation(
            mapboxMap, pointAnnotationManager, context),
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
}
