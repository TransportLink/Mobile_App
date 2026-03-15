import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';
import 'package:mobileapp/features/driver/viewmodel/vehicle_view_model.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/features/map/utils/helpers.dart';
import 'package:mobileapp/features/map/utils/map_utils.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final MapUtils _mapUtils = MapUtils();

  bool _isLoading = true;
  int _selectedIndex = 0;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;
  BusStop? _selectedBusStop;
  bool _isTripCardMinimized = false;
  List<BusStop> _previousBusStops = [];

  // Map state
  List<Marker> _busStopMarkers = [];
  Marker? _userLocationMarker;
  List<Polyline> _routePolylines = [];
  LatLng _currentCenter = const LatLng(5.6037, -0.1870); // Accra default

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeMap();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _setupAnimations() {
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
  }

  Future<void> _initializeMap() async {
    await _requestLocationPermission();
    await ref.read(mapViewModelProvider.notifier).initializeMap();
    await _showUserLocation();
    setState(() => _isLoading = false);

    // Listen for bus stop changes to update markers
    ref.listenManual(mapViewModelProvider, (previous, next) {
      final busStops = next?.value?.busStops ?? [];
      if (busStops != _previousBusStops && busStops.isNotEmpty) {
        _previousBusStops = busStops;
        _updateMapMarkers(busStops);
      }
    });
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;

    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();

      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission permanently denied'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    if (status.isGranted) {
      await ref.read(mapViewModelProvider.notifier).fetchBusStops();
    }
  }

  Future<void> _showUserLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = userLatLng;
        _userLocationMarker = _mapUtils.buildUserLocationMarker(position);
      });
      _mapController.move(userLatLng, 14.0);
    } catch (e) {
      print('Error showing user location: $e');
    }
  }

  void _updateMapMarkers(List<BusStop> busStops) {
    final markers = _mapUtils.buildBusStopMarkers(busStops);
    setState(() {
      _busStopMarkers = markers;
    });

    // Fit bounds
    geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    ).then((position) {
      final bounds = _mapUtils.calculateCameraBounds(position, busStops);
      if (bounds != null) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    }).catchError((e) {
      print('Error fitting map bounds: $e');
    });
  }

  Future<void> _showRouteOnMap(route_models.Route? route) async {
    if (route == null) return;
    final polyline = _mapUtils.buildRoutePolyline(route);
    if (polyline != null) {
      setState(() {
        _routePolylines = [polyline];
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    final mapState = ref.read(mapViewModelProvider)?.value;
    if (mapState == null) return;

    final tappedStop = mapState.busStops.firstWhereOrNull(
      (stop) => Helpers.isPointNearCoordinates(
        stop.latitude,
        stop.longitude,
        latLng.latitude,
        latLng.longitude,
        tolerance: 0.005,
      ),
    );

    if (tappedStop != null) {
      setState(() {
        _selectedBusStop = tappedStop;
        _isTripCardMinimized = false;
      });
      _animationController?.forward();
    } else if (mapState.isOnTrip) {
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
      setState(() {
        _selectedBusStop = null;
        _isTripCardMinimized = false;
      });
      _animationController?.reverse();
    }
  }

  Future<void> _selectDestinationsAndAcceptTrip(BusStop stop) async {
    final mapState = ref.read(mapViewModelProvider)?.value;
    if (mapState?.selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle first')),
      );
      return;
    }

    final destinations = await showDialog<List<Destination>>(
      context: context,
      builder: (context) => DestinationSelectionDialog(
        availableDestinations: stop.destinations.keys.toList(),
      ),
    );

    if (destinations == null || destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No destinations selected')),
      );
      return;
    }

    await ref.read(mapViewModelProvider.notifier).acceptTrip(
          busStop: stop,
          destinations: destinations,
          vehicleId: mapState!.selectedVehicleId!,
        );

    // Show route on map if trip was accepted successfully
    final updatedState = ref.read(mapViewModelProvider)?.value;
    if (updatedState?.currentRoute != null) {
      await _showRouteOnMap(updatedState!.currentRoute);
    }

    setState(() {
      _selectedBusStop = null;
      _isTripCardMinimized = false;
    });

    _animationController?.reset();
    await _animationController?.forward();
  }

  Future<void> _cancelTrip() async {
    await ref.read(mapViewModelProvider.notifier).cancelTrip();
    setState(() {
      _routePolylines = [];
      _isTripCardMinimized = false;
    });

    await _animationController?.reverse();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled')),
      );
    }
  }

  Future<void> _arrivedAtDestination() async {
    await ref.read(mapViewModelProvider.notifier).arrivedAtDestination();
    setState(() {
      _routePolylines = [];
      _isTripCardMinimized = false;
    });

    await _animationController?.reverse();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrived at destination')),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/wallet');
        break;
      case 2:
        Navigator.pushNamed(context, '/vehicles');
        break;
      case 3:
        Navigator.pushNamed(context, '/documents');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapViewModelProvider);
    final vehiclesAsync = ref.watch(getAllVehiclesProvider);

    final screenHeight = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).padding.bottom;

    // Collect all markers
    final allMarkers = <Marker>[
      ..._busStopMarkers,
      if (_userLocationMarker != null) _userLocationMarker!,
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 14.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.airlectric.smarttrotro',
              ),
              MarkerLayer(markers: allMarkers),
              PolylineLayer(polylines: _routePolylines),
            ],
          ),

          if (_isLoading || mapState?.isLoading == true)
            const Center(child: CircularProgressIndicator()),

          if (mapState?.hasError == true)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: ${mapState!.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),

          // Vehicle selector
          if (vehiclesAsync.hasValue && vehiclesAsync.value!.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: _buildVehicleSelector(vehiclesAsync.value!),
            ),

          // Search radius selector
          if (mapState?.hasValue == true)
            Positioned(
              top: 16,
              right: 16,
              child: _buildRadiusSelector(mapState!.value!.searchRadius),
            ),

          // Bottom sheet for bus stop/trip cards
          if (_selectedBusStop != null || (mapState?.value?.isOnTrip ?? false))
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
                  child: _buildBottomSheetContent(mapState?.value),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Recenter',
        onPressed: _showUserLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildVehicleSelector(List<VehicleModel> vehicles) {
    final mapState = ref.watch(mapViewModelProvider)?.value;

    return Card(
      child: DropdownButton<String>(
        value: mapState?.selectedVehicleId,
        hint: const Text('Select Vehicle'),
        items: vehicles.map((vehicle) {
          return DropdownMenuItem<String>(
            value: vehicle.vehicleId,
            child: Text('${vehicle.plateNumber} • ${vehicle.displayName}'),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            ref.read(mapViewModelProvider.notifier).updateSelectedVehicle(val);
          }
        },
      ),
    );
  }

  Widget _buildRadiusSelector(double currentRadius) {
    final radii = [1.0, 3.0, 5.0, 10.0, 20.0];

    return Card(
      child: DropdownButton<double>(
        value: currentRadius,
        items: radii.map((r) {
          return DropdownMenuItem<double>(
            value: r,
            child: Text('${r.toInt()} km'),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            ref.read(mapViewModelProvider.notifier).updateSearchRadius(val);
          }
        },
      ),
    );
  }

  Widget _buildBottomSheetContent(MapState? mapStateValue) {
    final mapState = ref.watch(mapViewModelProvider)?.value;

    if (_selectedBusStop != null) {
      final stop = _selectedBusStop!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: Text('Stop: ${stop.systemId}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                Text('${stop.totalCount} pax',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Destinations:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: stop.destinations.entries.map((e) {
                  return ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text('${e.value} pax'),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDestinationsAndAcceptTrip(stop),
                    child: const Text('Accept Trip'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedBusStop = null;
                        _isTripCardMinimized = false;
                      });
                      _animationController?.reverse();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (mapState?.isOnTrip ?? false) {
      final currentRoute = mapState?.currentRoute;
      final destinations = mapState?.selectedDestinations ?? [];

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: Text('On Trip: ${mapState?.tripId ?? ''}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                if (currentRoute != null)
                  Text('${(currentRoute.distance).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            if (currentRoute != null)
              Text(
                  'To: ${currentRoute.destination} — ETA ${(currentRoute.eta).toStringAsFixed(0)} mins'),
            const SizedBox(height: 8),
            const Text('Selected Destinations:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final d = destinations[index];
                  return ListTile(
                    title: Text(d.destination ?? 'Unknown'),
                    trailing: Text('${d.passengerCount} pax'),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _arrivedAtDestination,
                    child: const Text('Arrived'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelTrip,
                    child: const Text('Cancel Trip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class DestinationSelectionDialog extends StatefulWidget {
  final List<String> availableDestinations;

  const DestinationSelectionDialog(
      {super.key, required this.availableDestinations});

  @override
  State<DestinationSelectionDialog> createState() =>
      _DestinationSelectionDialogState();
}

class _DestinationSelectionDialogState
    extends State<DestinationSelectionDialog> {
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
                  value: _selectedDestinations
                      .any((d) => d.destination == dest),
                  onChanged: (value) {
                    if (value == true) {
                      setState(() {
                        _selectedDestinations.add(Destination(
                          destination: dest,
                          passengerCount: int.tryParse(
                                  _passengerControllers[dest]!.text) ??
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
                      labelText: 'Pax',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (_selectedDestinations
                          .any((d) => d.destination == dest)) {
                        setState(() {
                          final index = _selectedDestinations
                              .indexWhere((d) => d.destination == dest);
                          _selectedDestinations[index] = Destination(
                            destination: dest,
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
          onPressed: () => Navigator.of(context).pop<List<Destination>>([]),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedDestinations.isNotEmpty) {
              Navigator.of(context)
                  .pop<List<Destination>>(_selectedDestinations);
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
