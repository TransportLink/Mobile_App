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
  final MapService _mapService =
      MapService(); // Requires Dio and AuthService injection
  final AuthService _authService = AuthService();
  final DriverLocationService _driverLocationService = DriverLocationService();
  final MapUtils _mapUtils = MapUtils();
  List<BusStop> _busStops = [];
  route_models.Route? _currentRoute;
  List<Destination> _selectedDestinations = [];
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
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  int? _tripId;

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
    _initializeDriverAndTrip();
    _fetchVehicles();
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

  Future<void> _initializeDriverAndTrip() async {
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
    // Load trip_id from SharedPreferences
    final tripId = prefs.getInt('trip_id');
    if (tripId != null) {
      setState(() {
        _tripId = tripId;
        print("✅ Loaded trip ID: $_tripId");
      });
    }
  }

  Future<void> _fetchVehicles() async {
    final vehicleResult = await _authService.listVehicles();
    if (vehicleResult['success']) {
      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(vehicleResult['data']);
        _selectedVehicleId =
            _vehicles.isNotEmpty ? _vehicles.first['vehicle_id'] : null;
      });
      print("✅ Fetched ${_vehicles.length} vehicles");
    } else {
      print("❌ Error fetching vehicles: ${vehicleResult['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(vehicleResult['message'] ?? 'Error fetching vehicles')),
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
    _locationUpdateTimer?.cancel(); // Cancel any existing timer
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
      print("⚠️ Mapbox map not initialized, delaying bus stop polling");
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        return mapboxMap == null;
      });
      print("✅ Mapbox map initialized, starting bus stop polling");
    }
    _busStopUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_selectedDestinations.isNotEmpty) {
        print("ℹ️ Updating bus stop during active trip");
        try {
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
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_selectedDestinations.isEmpty ||
          _driverId == null ||
          _currentBusStopId == null ||
          _selectedVehicleId == null ||
          _tripId == null) {
        print("⚠️ No active trip, stopping route updates");
        _routeUpdateTimer?.cancel();
        _routeUpdateTimer = null;
        return;
      }
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        final stop =
            _busStops.firstWhereOrNull((s) => s.systemId == _currentBusStopId);
        if (stop == null) {
          print("❌ Bus stop not found for systemId: $_currentBusStopId");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bus stop not found')),
          );
          return;
        }
        // Calculate ETA to the bus stop
        final eta = await _mapService.calculateEta(
          driverLat: position.latitude,
          driverLng: position.longitude,
          busStopLat: stop.latitude,
          busStopLng: stop.longitude,
        );
        if (eta == null) {
          print("❌ Failed to calculate ETA");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to calculate ETA')),
          );
          return;
        }
        final updateResult = await _mapService.updateLocation(
          driverId: _driverId!,
          systemId: _currentBusStopId!,
          vehicleId: _selectedVehicleId!,
          tripId: _tripId!,
          busStopLat: stop.latitude,
          busStopLng: stop.longitude,
          eta: eta,
        );
        if (updateResult['success']) {
          print("✅ Location updated successfully with ETA: $eta");
          // Optionally update the route if the server returns new route data
          if (updateResult['data'] != null &&
              updateResult['data']['route'] != null) {
            setState(() {
              _currentRoute =
                  route_models.Route.fromJson(updateResult['data']['route']);
            });
            await _mapUtils.showRoute(mapboxMap, _currentRoute!, context);
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
        } else {
          print("❌ Failed to update location: ${updateResult['message']}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    updateResult['message'] ?? 'Failed to update location')),
          );
        }
      } catch (e) {
        print("❌ Error updating route: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update route')),
        );
      }
    });
  }

  Future<void> _fetchBusStops() async {
    if (mapboxMap == null) {
      print("⚠️ Mapbox map not initialized, skipping bus stop fetch");
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

  Future<void> _selectDestinationsAndAcceptTrip(BusStop stop) async {
    if (_driverId == null || _selectedVehicleId == null) {
      print("❌ Driver ID or Vehicle ID not found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID or Vehicle ID not found')),
      );
      return;
    }
    final destinations = await showDialog<List<Destination>>(
      context: context,
      builder: (context) => DestinationSelectionDialog(
        availableDestinations: stop.destinations.keys.toList(),
        onDestinationsSelected: (selected) => Navigator.pop(context, selected),
      ),
    );
    if (destinations == null || destinations.isEmpty) {
      print("❌ No destinations selected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No destinations selected')),
      );
      return;
    }
    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    final routeResult = await _mapService.fetchRoute(
      driverId: _driverId!,
      systemId: stop.systemId,
      busStop: stop.systemId,
      busStopLat: stop.latitude,
      busStopLng: stop.longitude,
      destinations: destinations
          .map((d) => {
                'destination': d.destination,
                'passenger_count': d.passengerCount,
              })
          .toList(),
      vehicleId: _selectedVehicleId!,
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
      _currentRoute = route_models.Route.fromJson(routeResult['data']['route']);
      _currentBusStopId = stop.systemId;
      _selectedBusStop = null;
      _selectedDestinations = destinations;
      _isTripCardMinimized = false;
      _tripId = routeResult['data']['trip_id'];
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trip_id', _tripId!);
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
    _routeUpdateTimer = null;
    if (_selectedDestinations.isEmpty || _tripId == null) {
      print("⚠️ No destinations to mark as arrived, clearing route");
      setState(() {
        _currentRoute = null;
        _selectedDestinations = [];
        _currentBusStopId = null;
        _isTripCardMinimized = false;
        _tripId = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('trip_id');
      await _mapUtils.clearRouteLayer(mapboxMap);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrived at destination')),
      );
      await _animationController?.reverse();
      return;
    }
    final result = await _driverLocationService.updateDestination(
      _selectedDestinations.first.destination ?? '',
      'available',
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _selectedDestinations = [];
        _currentBusStopId = null;
        _isTripCardMinimized = false;
        _tripId = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('trip_id');
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
    _routeUpdateTimer = null;
    if (_selectedDestinations.isEmpty ||
        _tripId == null ||
        _currentBusStopId == null ||
        _selectedVehicleId == null) {
      print(
          "⚠️ No destinations, trip ID, or bus stop ID to cancel, clearing route");
      setState(() {
        _currentRoute = null;
        _selectedDestinations = [];
        _currentBusStopId = null;
        _isTripCardMinimized = false;
        _tripId = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('trip_id');
      await _mapUtils.clearRouteLayer(mapboxMap);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled')),
      );
      await _animationController?.reverse();
      return;
    }
    final stop =
        _busStops.firstWhereOrNull((s) => s.systemId == _currentBusStopId);
    if (stop == null) {
      print("❌ Bus stop not found for systemId: $_currentBusStopId");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus stop not found')),
      );
      return;
    }
    final result = await _mapService.cancelRoute(
      driverId: _driverId!,
      systemId: _currentBusStopId!,
      vehicleId: _selectedVehicleId!,
      destination: _selectedDestinations.first.destination ?? '',
      destLat: stop.latitude,
      destLng: stop.longitude,
      passengerCount: _selectedDestinations.first.passengerCount,
      tripId: _tripId!,
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _selectedDestinations = [];
        _currentBusStopId = null;
        _isTripCardMinimized = false;
        _tripId = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('trip_id');
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
        "ℹ️ Building UI: _selectedBusStop=${_selectedBusStop?.systemId}, _selectedDestinations=${_selectedDestinations.length}, _isTripCardMinimized=$_isTripCardMinimized");

    Widget bottomSheetChild;
    if (_selectedBusStop != null) {
      print("ℹ️ Rendering bus stop card for ${_selectedBusStop!.systemId}");
      bottomSheetChild = UIComponents.buildBusStopCard(
        _selectedBusStop!,
        () {
          setState(() => _selectedBusStop = null);
          _animationController?.reverse();
        },
        () => _selectDestinationsAndAcceptTrip(_selectedBusStop!),
      );
    } else if (_selectedDestinations.isNotEmpty) {
      if (_isTripCardMinimized) {
        print("ℹ️ Rendering minimized trip card");
        bottomSheetChild = UIComponents.buildMinimizedTripCard(
          _selectedDestinations,
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
          _selectedDestinations,
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
              } else if (_selectedDestinations.isNotEmpty) {
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
          if (_selectedBusStop != null || _selectedDestinations.isNotEmpty)
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
            left: 16,
            child: DropdownButton<String>(
              value: _selectedVehicleId,
              hint: const Text('Select Vehicle'),
              items: _vehicles.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle['vehicle_id'],
                  child: Text(
                      '${vehicle['brand']} ${vehicle['model']} (${vehicle['plate_number']})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedVehicleId = value);
              },
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

class DestinationSelectionDialog extends StatefulWidget {
  final List<String> availableDestinations;
  final Function(List<Destination>) onDestinationsSelected;

  const DestinationSelectionDialog({
    super.key,
    required this.availableDestinations,
    required this.onDestinationsSelected,
  });

  @override
  State<DestinationSelectionDialog> createState() =>
      _DestinationSelectionDialogState();
}

class _DestinationSelectionDialogState
    extends State<DestinationSelectionDialog> {
  final MapService _mapService = MapService();
  final List<Destination> _selectedDestinations = [];
  final Map<String, TextEditingController> _passengerControllers = {};

  @override
  void initState() {
    super.initState();
    for (var dest in widget.availableDestinations) {
      _passengerControllers[dest] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _passengerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Destinations'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.availableDestinations.map((dest) {
            return Row(
              children: [
                Checkbox(
                  value:
                      _selectedDestinations.any((d) => d.destination == dest),
                  onChanged: (value) {
                    if (value == true) {
                      setState(() {
                        _selectedDestinations.add(Destination(
                          destination: dest,
                          passengerCount:
                              int.tryParse(_passengerControllers[dest]!.text) ??
                                  1,
                        ));
                      });
                    } else {
                      setState(() {
                        _selectedDestinations
                            .removeWhere((d) => d.destination == dest);
                      });
                    }
                  },
                ),
                Expanded(child: Text(dest)),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _passengerControllers[dest],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Passengers',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (_selectedDestinations
                          .any((d) => d.destination == dest)) {
                        setState(() {
                          final index = _selectedDestinations
                              .indexWhere((d) => d.destination == dest);
                          final currentDest = _selectedDestinations[index];
                          _selectedDestinations[index] = Destination(
                            destination: currentDest.destination,
                            passengerCount: int.tryParse(value) ?? 1,
                          );
                        });
                      }
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedDestinations.isNotEmpty) {
              widget.onDestinationsSelected(_selectedDestinations);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please select at least one destination')),
              );
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
