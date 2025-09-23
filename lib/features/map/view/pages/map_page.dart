import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/map/utils/helpers.dart';
import 'package:mobileapp/features/map/utils/map_utils.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with SingleTickerProviderStateMixin {
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? pointAnnotationManager;

  final MapUtils _mapUtils = MapUtils();

  /// UI-only state
  int _selectedIndex = 0;
  bool _useCustomMarker = true;
  bool _isTripCardMinimized = false;
  BusStop? _selectedBusStop;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Init animation
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

    // Kick off ViewModel logic
    final mapVM = ref.read(mapViewModelProvider.notifier);
    Future.microtask(() async {
      await mapVM.initializeDriverId();
      await mapVM.requestLocationPermission();
      mapVM.startLocationUpdates();
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  /// Called when map is created
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
      setState(() => _useCustomMarker = false);
    }
  }

  /// Handle map taps
  void _handleMapTap(MapContentGestureContext context, List<BusStop> busStops,
      Destination? currentDestination) {
    final latitude = context.point.coordinates.lat.toDouble();
    final longitude = context.point.coordinates.lng.toDouble();

    print("OnTap coordinate: {$longitude, $latitude}");

    final tappedStop = busStops.firstWhere(
      (stop) => Helpers.isPointNearCoordinates(
        stop.latitude,
        stop.longitude,
        latitude,
        longitude,
        tolerance: 0.005,
      ),
      orElse: () => null as BusStop,
    );

    if (tappedStop != null) {
      setState(() {
        _selectedBusStop = tappedStop;
        _isTripCardMinimized = false;
      });
      _animationController?.forward();
    } else if (currentDestination != null) {
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = !_isTripCardMinimized;
      });
      _isTripCardMinimized
          ? _animationController?.reverse()
          : _animationController?.forward();
    } else {
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = false;
      });
      _animationController?.reverse();
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        ref.watch(mapViewModelProvider.select((val) => val?.isLoading)) == true;

    var busStops;
    var currentDestination;
    var currentRoute;

    ref.listen(mapViewModelProvider, (_, next) {
      next?.when(
        loading: () {},
        error: (err, st) => Scaffold(
          body: Center(child: Text("❌ $err")),
        ),
        data: (driver) {
          busStops = driver.busStops ?? [];
          currentDestination = driver?.currentDestination;
          currentRoute = driver?.currentRoute;
        },
      );
    });

    return Scaffold(
      body: isLoading
          ? Loader()
          : Stack(
              children: [
                MapWidget(
                  key: const ValueKey("mapWidget"),
                  styleUri: MapboxStyles.STANDARD,
                  onMapCreated: _onMapCreated,
                  onTapListener: (context) =>
                      _handleMapTap(context, busStops, currentDestination),
                ),

                // Trip card
                if (_selectedBusStop != null || currentDestination != null)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 56.0,
                    left: 16.0,
                    child: SlideTransition(
                      position: _slideAnimation!,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: _isTripCardMinimized
                            ? 300.0
                            : MediaQuery.of(context).size.width - 32.0,
                        height: _isTripCardMinimized
                            ? 80.0
                            : MediaQuery.of(context).size.height * 0.5,
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
                        child: Center(
                          child: Text(
                            currentDestination != null
                                ? "Active trip to ${currentDestination.routeName}"
                                : "Bus stop: ${_selectedBusStop?.systemId ?? ''}",
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Recenter & Show Marker',
        onPressed: () => _mapUtils.showUserLocation(
          mapboxMap,
          pointAnnotationManager,
          context,
        ),
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
