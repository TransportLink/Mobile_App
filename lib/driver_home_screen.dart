import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  mapbox.MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        styleUri: MapboxStyles.STANDARD, // Explicitly set Mapbox style
        onMapCreated: _onMapCreated,
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

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
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

    // Enable location puck (live tracking icon)
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
        showAccuracyRing: true,
      ),
    );

    // Once map is created, show marker at current location
    _showUserLocation();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;

    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();

      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission permanently denied'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        return;
      }
    }

    if (status.isGranted) {
      _showUserLocation();
    }
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
        CameraOptions(center: center, zoom: 16.0),
        MapAnimationOptions(duration: 1000),
      );

      // Clear any old markers
      await pointAnnotationManager?.deleteAll();

      // Add marker at current location
      final manager =
          await mapboxMap?.annotations.createPointAnnotationManager();
      await manager?.create(PointAnnotationOptions(
        geometry: center,
        iconImage: "marker-15", // Ensure this icon exists in Mapbox style
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
}
