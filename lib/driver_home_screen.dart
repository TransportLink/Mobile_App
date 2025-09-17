import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
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

class _DriverHomeScreenState extends State<DriverHomeScreen> {
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
  double _searchRadius = 5.0; // Increased default to 5 km
  Timer? _locationUpdateTimer;
  Timer? _busStopUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeDriverId();
    _requestLocationPermission();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _busStopUpdateTimer?.cancel();
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
      await _startBusStopUpdates(); // Start polling after initial fetch
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
            ? addressResult['data']['features'][0]['properties']['name']
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
        }
      } catch (e) {
        print("❌ Error updating location: $e");
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
      // Wait for map initialization
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        return mapboxMap == null;
      });
      print("✅ Mapbox map initialized, starting bus stop polling");
    }
    _busStopUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentDestination != null) {
        print("ℹ️ Skipping bus stop update during active trip");
        return;
      }
      try {
        print("📡 Starting periodic bus stop update");
        await _fetchBusStops();
      } catch (e) {
        print("❌ Error in periodic bus stop update: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update bus stops')),
        );
      }
    });
  }

  Future<void> _fetchBusStops() async {
    if (mapboxMap == null) {
      print("❌ Mapbox map not initialized, skipping bus stop fetch");
      return;
    }
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
      print("📡 API response: $result");
      if (result['success']) {
        final features = result['data']['features'] as List<dynamic>;
        print("🚌 Found ${features.length} bus stops");
        setState(() {
          _busStops = features.map((f) => BusStop.fromJson(f)).toList();
        });
        await _addBusStopMarkers();
      } else {
        print("❌ API error: ${result['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Error fetching bus stops')),
        );
      }
    } catch (e) {
      print("❌ Error fetching bus stops: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch bus stops')),
      );
    }
  }

  Future<void> _addBusStopMarkers() async {
    print("🛠️ Adding ${_busStops.length} bus stop markers");
    await pointAnnotationManager?.deleteAll();
    final manager = await mapboxMap?.annotations.createPointAnnotationManager();
    for (var stop in _busStops) {
      print(
          "🚌 Adding marker for ${stop.systemId} at (${stop.latitude}, ${stop.longitude})");
      await manager?.create(PointAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(stop.longitude, stop.latitude),
        ),
        iconImage: 'marker', // Use default 'marker' to ensure rendering
        iconSize: 1.5,
        textField: stop.systemId,
        textOffset: [0.0, -2.0],
      ));
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
      await manager?.create(PointAnnotationOptions(
        geometry: center,
        iconImage: 'marker', // Use default 'marker' to ensure rendering
        iconSize: 2.0,
      ));
      pointAnnotationManager = manager;
      print("📍 Location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("❌ Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get current location.")),
      );
    }
  }

  Future<void> _showRoute(route_models.Route route) async {
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
    final bounds = _calculateBounds(route.coordinates);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stop.systemId),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Passengers: ${stop.totalCount}'),
            const SizedBox(height: 8),
            const Text('Destinations:'),
            ...stop.destinations.entries.map(
              (e) => Text('${e.key}: ${e.value} passengers'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _acceptTrip(stop),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptTrip(BusStop stop) async {
    Navigator.pop(context);
    if (_driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID not found')),
      );
      return;
    }
    final routeResult = await _mapService.fetchRoute(
      driverId: _driverId!,
      destination: stop.destinations.keys.first,
      systemId: stop.systemId
    );
    if (routeResult['success']) {
      setState(() {
        _currentRoute = route_models.Route.fromJson(routeResult['data']);
      });
      await _showRoute(_currentRoute!);
      final destinationResult = await _driverLocationService.createDestination(
        routeName: '${stop.systemId} to ${stop.destinations.keys.first}',
        startLatitude: _currentRoute!.coordinates[0][1],
        startLongitude: _currentRoute!.coordinates[0][0],
        endLatitude: stop.latitude,
        endLongitude: stop.longitude,
        availabilityStatus: 'available',
      );
      if (destinationResult['success']) {
        setState(() {
          _currentDestination = Destination.fromJson(destinationResult['data']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(destinationResult['message'] ?? 'Error accepting trip'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(routeResult['message'] ?? 'Error fetching route')),
      );
    }
  }

  Future<void> _arrivedAtDestination() async {
    if (_currentDestination == null) return;
    final result = await _driverLocationService.updateDestination(
      _currentDestination!.destinationId,
      'not_available',
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
      });
      await mapboxMap?.style.removeStyleLayer('route-line-layer');
      await mapboxMap?.style.removeStyleSource('route-line-source');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrived at destination')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Error updating destination')),
      );
    }
  }

  Future<void> _cancelTrip() async {
    if (_currentDestination == null) return;
    final result = await _driverLocationService.updateDestination(
      _currentDestination!.destinationId,
      'not_available',
    );
    if (result['success']) {
      setState(() {
        _currentRoute = null;
        _currentDestination = null;
      });
      await mapboxMap?.style.removeStyleLayer('route-line-layer');
      await mapboxMap?.style.removeStyleSource('route-line-source');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled')),
      );
    } else {
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

  void _onMapCreated(mapbox.MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    print("🗺️ Map created");
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false, // Disabled to reduce visual clutter
        puckBearingEnabled: true,
        showAccuracyRing: false, // Disabled to reduce visual clutter
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              print("OnTap coordinate: {$longitude, $latitude} " +
                  "point: {x: ${context.touchPosition.x}, y: ${context.touchPosition.y}}");
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
              } else {
                print("❌ No stop tapped");
              }
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_currentDestination != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Trip to ${_currentDestination!.routeName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                          'ETA: ${(_currentRoute!.eta / 60).toStringAsFixed(1)} min'),
                      Text(
                          'Distance: ${(_currentRoute!.distance / 1000).toStringAsFixed(1)} km'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _arrivedAtDestination,
                            child: const Text('Arrived'),
                          ),
                          ElevatedButton(
                            onPressed: _cancelTrip,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
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

  bool _isPointNearCoordinates(
      double lat1, double lon1, double lat2, double lon2,
      {double tolerance = 0.005}) {
    print("Comparing ($lat1, $lon1) to ($lat2, $lon2)");
    return (lat1 - lat2).abs() < tolerance && (lon1 - lon2).abs() < tolerance;
  }
}
