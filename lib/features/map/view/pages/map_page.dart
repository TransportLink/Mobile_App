import 'package:mobileapp/core/theme/app_palette.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/features/map/utils/helpers.dart';
import 'package:mobileapp/features/map/utils/map_utils.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;
import 'package:permission_handler/permission_handler.dart';
import 'package:mobileapp/core/widgets/cached_tile_layer.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/driver/view/vehicle_page.dart';

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

  bool _listenerAdded = false;

  Future<void> _initializeMap() async {
    // Check if map data is already cached (coming back from another tab)
    if (!mounted) return;
    final existingState = ref.read(mapViewModelProvider)?.valueOrNull;
    if (existingState != null && existingState.busStops.isNotEmpty) {
      _updateMapMarkers(existingState.busStops);
      await _showUserLocation();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } else {
      await _requestLocationPermission();
      if (!mounted) return;
      await _showUserLocation();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ref.read(mapViewModelProvider.notifier).initializeMap();
    }

    if (!mounted) return;
    final currentState = ref.read(mapViewModelProvider)?.valueOrNull;
    if (currentState?.isOnTrip == true && currentState?.currentRoute != null) {
      await _showRouteOnMap(currentState!.currentRoute);
      if (!mounted) return;
      setState(() => _isTripCardMinimized = false);
    }

    if (!mounted) return;

    // Listen for focus requests from Demand page (separate from map state)
    ref.listenManual(pendingFocusBusStopProvider, (previous, next) {
      if (next == null || !mounted) return;
      _handleFocusRequest(next);
    });

    // Also check if there's a pending request right now (set before map tab was active)
    final pendingFocus = ref.read(pendingFocusBusStopProvider);
    if (pendingFocus != null) {
      // Delay slightly to let the map controller initialize
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _handleFocusRequest(pendingFocus);
      });
    }

    if (!_listenerAdded) {
      _listenerAdded = true;
      ref.listenManual(mapViewModelProvider, (previous, next) {
        final state = next?.valueOrNull;
        final busStops = state?.busStops ?? [];
        if (busStops != _previousBusStops && busStops.isNotEmpty) {
          _previousBusStops = busStops;
          _updateMapMarkers(busStops);
        }
        // Auto-show route line when route becomes available (e.g., after restoration)
        if (state?.currentRoute != null &&
            state!.currentRoute!.coordinates.isNotEmpty &&
            _routePolylines.isEmpty &&
            state.isOnTrip) {
          _showRouteOnMap(state.currentRoute);
        }
        // Live-update polyline when route coordinates change (every 15s recalc)
        if (state?.currentRoute != null &&
            state!.isOnTrip &&
            _routePolylines.isNotEmpty) {
          final polyline = _mapUtils.buildRoutePolyline(state.currentRoute!);
          if (polyline != null && mounted) {
            setState(() => _routePolylines = [polyline]);
          }
        }
        // Clear polyline if trip ended
        if (state?.isOnTrip == false && _routePolylines.isNotEmpty) {
          if (mounted) setState(() => _routePolylines = []);
        }
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status;
    try {
      status = await Permission.locationWhenInUse.status;
    } catch (_) {
      return; // Another permission request in flight
    }

    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      try {
        status = await Permission.locationWhenInUse.request();
      } catch (_) {
        return; // Another permission request in flight
      }

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

    // Bus stop fetching is handled by initializeMap's timer — no extra call needed
  }

  geo.Position? _lastKnownPosition;
  double? _lastHeading;

  /// Handle focus request from Demand page — zoom to bus stop and auto-select it
  void _handleFocusRequest(FocusBusStopRequest req) {
    if (!mounted) return;

    // Clear the request immediately to avoid re-processing
    ref.read(pendingFocusBusStopProvider.notifier).state = null;

    // Zoom to the bus stop location
    _mapController.move(LatLng(req.latitude, req.longitude), 16.0);

    // Find the matching bus stop in loaded data and select it
    final busStops = ref.read(mapViewModelProvider)?.valueOrNull?.busStops ?? [];
    final target = busStops.cast<BusStop?>().firstWhere(
      (s) => s?.systemId == req.systemId,
      orElse: () => null,
    );

    if (target != null) {
      setState(() {
        _selectedBusStop = target;
        _isTripCardMinimized = false;
      });
      _animationController?.forward();
    } else {
      // Bus stop not in loaded data yet — show a snackbar with the name
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoomed to ${req.systemId.replaceAll("_", " ")}. Tap the marker to select.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showUserLocation() async {
    try {
      // Use last known position first for instant display, then refine
      final lastKnown = await geo.Geolocator.getLastKnownPosition();
      if (lastKnown != null && _lastKnownPosition == null) {
        _lastKnownPosition = lastKnown;
        final userLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        if (mounted) {
          setState(() {
            _currentCenter = userLatLng;
            _userLocationMarker = _mapUtils.buildUserLocationMarker(lastKnown, heading: _lastHeading);
          });
          _mapController.move(userLatLng, 14.0);
        }
      }

      // Then get accurate position with heading
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _lastKnownPosition = position;
      if (position.heading != 0) _lastHeading = position.heading;
      final userLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = userLatLng;
          _userLocationMarker = _mapUtils.buildUserLocationMarker(position, heading: _lastHeading);
        });
        // Only auto-move if not on a trip (when on trip, camera follows route)
        final isOnTrip = ref.read(mapViewModelProvider)?.valueOrNull?.isOnTrip ?? false;
        if (!isOnTrip) {
          _mapController.move(userLatLng, 14.0);
        }
      }
    } catch (e) {
      // Silently handle — location is non-critical for map display
    }
  }

  void _updateMapMarkers(List<BusStop> busStops) {
    if (!mounted) return;
    final markers = _mapUtils.buildBusStopMarkers(busStops);
    setState(() {
      _busStopMarkers = markers;
    });

    // Fit bounds using cached position (no extra GPS call)
    if (_lastKnownPosition != null) {
      final bounds = _mapUtils.calculateCameraBounds(_lastKnownPosition!, busStops);
      if (bounds != null) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    }
  }

  Future<void> _showRouteOnMap(route_models.Route? route) async {
    if (route == null) return;
    final polyline = _mapUtils.buildRoutePolyline(route);
    if (polyline != null) {
      setState(() {
        _routePolylines = [polyline];
      });

      // Orient camera to show the full route from driver to bus stop
      if (route.coordinates.isNotEmpty) {
        // GeoJSON coordinates are [lng, lat]
        final routePoints = route.coordinates
            .map((c) => LatLng(c[1], c[0]))
            .toList();

        // Include driver position in the bounds
        if (_lastKnownPosition != null) {
          routePoints.add(LatLng(
            _lastKnownPosition!.latitude,
            _lastKnownPosition!.longitude,
          ));
        }

        final bounds = LatLngBounds.fromPoints(routePoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(48, 100, 48, 280),
          ),
        );
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    final mapState = ref.read(mapViewModelProvider)?.valueOrNull;
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
    final mapState = ref.read(mapViewModelProvider)?.valueOrNull;
    if (mapState?.selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Set a default vehicle first'),
          action: SnackBarAction(
            label: 'Vehicles',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const VehiclesPage()));
              if (mounted) {
                final authLocal = ref.read(authLocalRepositoryProvider);
                final vid = authLocal.getDefaultVehicleId();
                if (vid != null) {
                  ref.read(mapViewModelProvider.notifier).updateSelectedVehicle(vid);
                }
              }
            },
          ),
        ),
      );
      return;
    }

    final destinations = await showDialog<List<Destination>>(
      context: context,
      builder: (context) => DestinationSelectionDialog(
        availableDestinations: stop.destinations.keys.toList(),
        passengerCounts: stop.destinations,
      ),
    );

    if (destinations == null || destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No destinations selected')),
      );
      return;
    }

    // Show loading overlay immediately
    setState(() {
      _selectedBusStop = null;
      _isLoading = true;
    });

    await ref.read(mapViewModelProvider.notifier).acceptTrip(
          busStop: stop,
          destinations: destinations,
          vehicleId: mapState!.selectedVehicleId!,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final updatedState = ref.read(mapViewModelProvider)?.valueOrNull;
    if (updatedState?.isOnTrip == true && updatedState?.currentRoute != null) {
      await _showRouteOnMap(updatedState!.currentRoute);
      setState(() => _isTripCardMinimized = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip #${updatedState.tripId} accepted! Head to the bus stop.'),
          backgroundColor: AppPalette.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept trip. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showCancelConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancel this trip?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Passengers at the bus stop are expecting you. Frequent cancellations affect your reliability score.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Keep Trip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Yes, Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _cancelTrip();
    }
  }

  Future<void> _cancelTrip() async {
    setState(() => _isLoading = true);

    final success = await ref.read(mapViewModelProvider.notifier).cancelTrip();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (success) {
        _routePolylines = [];
        _isTripCardMinimized = false;
      }
    });

    if (success) {
      // Force refresh bus stop counts immediately
      ref.read(mapViewModelProvider.notifier).fetchBusStops();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled'), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _arrivedAtDestination() async {
    setState(() => _isLoading = true);

    final success = await ref.read(mapViewModelProvider.notifier).arrivedAtDestination();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (success) {
        _routePolylines = [];
        _isTripCardMinimized = false;
      }
    });

    if (success) {
      // Force refresh bus stop counts immediately
      ref.read(mapViewModelProvider.notifier).fetchBusStops();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip completed!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to complete trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigation handled by NavWithFab — no local nav needed

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapViewModelProvider);

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
              buildCachedTileLayer(),
              MarkerLayer(markers: allMarkers),
              PolylineLayer(polylines: _routePolylines),
            ],
          ),

          if (_isLoading || mapState?.isLoading == true)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please wait...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error banner — dismissible, doesn't block map interaction
          if (mapState?.hasError == true)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, size: 18, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connection issue. Retrying...',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ref.read(mapViewModelProvider.notifier).fetchBusStops(),
                        child: Icon(Icons.refresh, size: 18, color: Colors.red.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // No-vehicle warning — only show after map loaded (not during init)
          if (!_isLoading && mapState?.valueOrNull?.selectedVehicleId == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VehiclesPage()));
                  // Reload default vehicle after returning from Vehicles page
                  if (mounted) {
                    final authLocal = ref.read(authLocalRepositoryProvider);
                    final vid = authLocal.getDefaultVehicleId();
                    if (vid != null) {
                      ref.read(mapViewModelProvider.notifier).updateSelectedVehicle(vid);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No vehicle selected. Tap to set your default vehicle.',
                          style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: Colors.orange.shade400),
                    ],
                  ),
                ),
              ),
            ),

          // Bus stop selection card (full size)
          if (_selectedBusStop != null && !(mapState?.valueOrNull?.isOnTrip ?? false))
            Positioned(
              bottom: safePadding + 56.0,
              left: 16.0,
              child: SlideTransition(
                position: _slideAnimation!,
                child: Container(
                  width: MediaQuery.of(context).size.width - 32.0,
                  height: screenHeight * 0.45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildBottomSheetContent(mapState?.valueOrNull),
                ),
              ),
            ),

          // Trip card — minimized floating pill OR expanded card
          if (mapState?.valueOrNull?.isOnTrip ?? false)
            Positioned(
              bottom: _isTripCardMinimized ? safePadding + 70.0 : safePadding + 56.0,
              left: _isTripCardMinimized ? null : 16.0,
              right: _isTripCardMinimized ? 16.0 : null,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isTripCardMinimized = !_isTripCardMinimized);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isTripCardMinimized
                      ? null
                      : MediaQuery.of(context).size.width - 32.0,
                  height: _isTripCardMinimized ? null : screenHeight * 0.45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_isTripCardMinimized ? 25 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: _isTripCardMinimized ? 6 : 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isTripCardMinimized
                      ? _buildMinimizedTripPill(mapState?.valueOrNull)
                      : _buildBottomSheetContent(mapState?.valueOrNull),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'recenter',
        tooltip: mapState?.valueOrNull?.isOnTrip == true ? 'Show route' : 'My location',
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        onPressed: () {
          // On trip: recenter on route. Not on trip: recenter on driver.
          if (mapState?.valueOrNull?.isOnTrip == true && mapState?.valueOrNull?.currentRoute != null) {
            _showRouteOnMap(mapState?.valueOrNull?.currentRoute);
          } else {
            _showUserLocation();
          }
        },
        child: Icon(
          mapState?.valueOrNull?.isOnTrip == true ? Icons.route : Icons.my_location,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMinimizedTripPill(MapState? mapState) {
    final currentRoute = mapState?.currentRoute;
    final distance = currentRoute?.distance.toStringAsFixed(1) ?? '?';
    final eta = currentRoute?.eta.toStringAsFixed(0) ?? '?';
    final totalPax = mapState?.selectedDestinations.fold(0, (sum, d) => sum + d.passengerCount) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppPalette.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            '${distance}km',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 4, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
          ),
          Text(
            '${eta} min',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 4, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
          ),
          Text(
            '$totalPax pax',
            style: TextStyle(fontSize: 14, color: AppPalette.primaryDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_less, size: 18, color: Colors.grey.shade500),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(MapState? mapStateValue) {
    final mapState = ref.watch(mapViewModelProvider)?.valueOrNull;

    if (_selectedBusStop != null) {
      final stop = _selectedBusStop!;
      final totalCount = stop.totalCount ?? 0;

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hail_rounded, color: AppPalette.primaryDark, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.systemId?.replaceAll('_', ' ') ?? 'Bus Stop',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$totalCount passengers waiting',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedBusStop = null;
                      _isTripCardMinimized = false;
                    });
                    _animationController?.reverse();
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Destination cards
            Expanded(
              child: ListView(
                children: stop.destinations.entries.map((e) {
                  final count = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: count > 0 ? AppPalette.primary.withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: count > 0 ? AppPalette.primary.withOpacity(0.25) : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: count > 0 ? AppPalette.primary : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: count > 0 ? Colors.black87 : Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: count > 0 ? AppPalette.primary : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Accept button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: totalCount > 0 ? () => _selectDestinationsAndAcceptTrip(stop) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Accept Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    if (mapState?.isOnTrip ?? false) {
      final currentRoute = mapState?.currentRoute;
      final destinations = mapState?.selectedDestinations ?? [];
      final totalPassengers = destinations.fold(0, (sum, d) => sum + d.passengerCount);

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Minimize handle
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _isTripCardMinimized = true),
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Live distance/ETA banner
            if (currentRoute != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.primary, AppPalette.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Distance
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.straighten, color: Colors.white70, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            '${currentRoute.distance.toStringAsFixed(1)} km',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('distance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    // ETA
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.schedule, color: Colors.white70, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            '${currentRoute.eta.toStringAsFixed(0)} min',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('arrival', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    // Passengers
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.people, color: Colors.white70, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            '$totalPassengers',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('passengers', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Trip info header
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentRoute?.destination ?? mapState?.currentBusStopId?.replaceAll('_', ' ') ?? 'Bus Stop',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Trip #${mapState?.tripId ?? ''}',
                    style: TextStyle(fontSize: 11, color: AppPalette.primaryDark, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Destinations
            Expanded(
              child: ListView.builder(
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final d = destinations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 16, color: AppPalette.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(d.destination ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                        ),
                        Text(
                          '${d.passengerCount} pax',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppPalette.primaryDark),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: Tooltip(
                      message: (mapState?.isNearDestination ?? false) 
                          ? 'Confirm arrival' 
                          : 'You must be within 200m of the destination to complete the trip',
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || !(mapState?.isNearDestination ?? false)) 
                            ? null 
                            : _arrivedAtDestination,
                        icon: Icon(
                          (mapState?.isNearDestination ?? false) ? Icons.check_circle : Icons.location_off, 
                          size: 18
                        ),
                        label: Text(
                          (mapState?.isNearDestination ?? false) ? 'I\'ve Arrived' : 'TOO FAR', 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (mapState?.isNearDestination ?? false) 
                              ? AppPalette.primary 
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _showCancelConfirmation(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 14)),
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
  final Map<String, dynamic> passengerCounts;

  static const int minPassengers = 5;

  const DestinationSelectionDialog({
    super.key,
    required this.availableDestinations,
    required this.passengerCounts,
  });

  @override
  State<DestinationSelectionDialog> createState() =>
      _DestinationSelectionDialogState();
}

class _DestinationSelectionDialogState
    extends State<DestinationSelectionDialog> {
  final Map<String, bool> _selected = {};
  final Map<String, TextEditingController> _passengerControllers = {};

  @override
  void initState() {
    super.initState();
    for (var dest in widget.availableDestinations) {
      final available = (widget.passengerCounts[dest] ?? 0) as int;
      _selected[dest] = false;
      // Default to min of available or minPassengers
      final defaultCount = available >= DestinationSelectionDialog.minPassengers
          ? DestinationSelectionDialog.minPassengers
          : available;
      _passengerControllers[dest] = TextEditingController(text: '$defaultCount');
    }
  }

  @override
  void dispose() {
    for (var controller in _passengerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalSelected => _selected.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.route, color: AppPalette.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Destinations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Choose where you are heading', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop<List<Destination>>([]),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Destination list
            ...widget.availableDestinations.map((dest) {
              final isSelected = _selected[dest] ?? false;
              return GestureDetector(
                onTap: () => setState(() => _selected[dest] = !isSelected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppPalette.primary.withOpacity(0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppPalette.primary.withOpacity(0.6) : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? AppPalette.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppPalette.primary : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Destination name
                      Expanded(
                        child: Text(
                          dest,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.black87 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      // Available count badge
                      if (!isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.passengerCounts[dest] ?? 0} waiting',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      // Passenger count stepper (with min/max enforcement)
                      if (isSelected) ...[
                        () {
                          final current = int.tryParse(_passengerControllers[dest]!.text) ?? 1;
                          final maxCount = (widget.passengerCounts[dest] ?? 0) as int;
                          final canDecrease = current > DestinationSelectionDialog.minPassengers;
                          final canIncrease = current < maxCount;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: canDecrease ? () {
                                  _passengerControllers[dest]!.text = '${current - 1}';
                                  setState(() {});
                                } : null,
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: canDecrease ? Colors.grey.shade600 : Colors.grey.shade300,
                                  size: 22,
                                ),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '$current',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                onPressed: canIncrease ? () {
                                  _passengerControllers[dest]!.text = '${current + 1}';
                                  setState(() {});
                                } : null,
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: canIncrease ? AppPalette.primary : Colors.grey.shade300,
                                  size: 22,
                                ),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              Text(
                                '/${maxCount}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _totalSelected > 0
                    ? () {
                        final destinations = <Destination>[];
                        for (var dest in widget.availableDestinations) {
                          if (_selected[dest] == true) {
                            final count = int.tryParse(_passengerControllers[dest]!.text) ?? 0;
                            final available = (widget.passengerCounts[dest] ?? 0) as int;
                            // Clamp to valid range
                            final clamped = count.clamp(1, available > 0 ? available : 1);
                            destinations.add(Destination(
                              destination: dest,
                              passengerCount: clamped,
                            ));
                          }
                        }
                        Navigator.of(context).pop<List<Destination>>(destinations);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  _totalSelected > 0
                      ? 'Confirm $_totalSelected destination${_totalSelected > 1 ? 's' : ''}'
                      : 'Select at least one destination',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
