import 'package:mobileapp/core/theme/app_palette.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/model/bus_stop.dart';
import '../../../features/map/repository/map_repository.dart';
import '../../../core/model/bus_stop_location.dart';
import 'passenger_checkin_screen.dart';
import 'walk_to_stop_screen.dart';
import '../../../core/widgets/cached_tile_layer.dart';

class PassengerMapScreen extends ConsumerStatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  ConsumerState<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends ConsumerState<PassengerMapScreen> {
  final MapController _mapController = MapController();

  List<BusStop> _busStops = [];
  geo.Position? _userPosition;
  BusStop? _selectedStop;
  BusStop? _nearbyStop; // auto-detected nearby bus stop
  bool _nearbyDismissed = false; // user dismissed the nearby card
  bool _isLoading = true;
  bool _isCardMinimized = false; // collapsed stop card pill
  Timer? _refreshTimer;

  static const _defaultCenter = LatLng(5.6037, -0.1870);
  static const _nearbyThresholdMeters = 150.0; // show card when within 150m

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _requestPermission();
    await _loadLocationAndStops();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshStops());
  }

  Future<void> _requestPermission() async {
    try {
      var status = await Permission.locationWhenInUse.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.locationWhenInUse.request();
      }
    } catch (_) {
      // Another permission request may already be in flight — safe to ignore
    }
  }

  Future<void> _loadLocationAndStops() async {
    geo.Position? lastKnown;
    try {
      lastKnown = await geo.Geolocator.getLastKnownPosition();
    } catch (_) {
      // Permission denied or location service unavailable
    }

    if (lastKnown != null && mounted) {
      setState(() => _userPosition = lastKnown);
      _mapController.move(LatLng(lastKnown.latitude, lastKnown.longitude), 14.0);
    }

    await _refreshStops(position: lastKnown);

    try {
      final accurate = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() => _userPosition = accurate);
        _mapController.move(LatLng(accurate.latitude, accurate.longitude), 14.0);
        _checkNearbyStops(accurate);
      }
    } catch (_) {
      // Permission denied or timeout — map still works, just no blue dot
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshStops({geo.Position? position}) async {
    if (!mounted) return;
    final pos = position ?? _userPosition;
    if (pos == null) return;

    final repo = ref.read(mapRepositoryProvider);
    final result = await repo.fetchBusStops(
      latitude: pos.latitude,
      longitude: pos.longitude,
      radius: 5.0,
    );

    result.fold(
      (err) => null,
      (stops) {
        if (mounted) {
          setState(() {
            _busStops = stops;
            _isLoading = false;
          });
          _checkNearbyStops(pos);
        }
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  /// Check if user is within 150m of any bus stop — show gentle card
  void _checkNearbyStops(geo.Position pos) {
    if (_nearbyDismissed || _selectedStop != null) return;

    BusStop? closest;
    double closestDist = double.infinity;

    for (final stop in _busStops) {
      final dist = geo.Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        stop.latitude, stop.longitude,
      );
      if (dist < closestDist) {
        closestDist = dist;
        closest = stop;
      }
    }

    if (closest != null && closestDist <= _nearbyThresholdMeters && closest.totalCount > 0) {
      if (mounted && _nearbyStop?.systemId != closest.systemId) {
        setState(() => _nearbyStop = closest);
      }
    } else {
      if (mounted && _nearbyStop != null) {
        setState(() => _nearbyStop = null);
      }
    }
  }

  void _onStopTapped(BusStop stop) {
    setState(() {
      _selectedStop = stop;
      _isCardMinimized = false;
      _nearbyStop = null; // hide nearby card when user taps a stop
    });
  }

  void _checkIn(BusStop stop) {
    final pos = _userPosition;

    // If we don't have the user's position, try to get it
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for your location. Please try again in a moment.'),
        ),
      );
      return;
    }

    final distance = geo.Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      stop.latitude, stop.longitude,
    );

    if (distance <= kCheckInRadiusMeters) {
      // Within range — go straight to check-in
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PassengerCheckInScreen(
            busStop: BusStopLocation(
              systemId: stop.systemId,
              latitude: stop.latitude,
              longitude: stop.longitude,
              location: stop.systemId.replaceAll('_', ' '),
            ),
          ),
        ),
      );
    } else {
      // Too far — show walking guidance with explanation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WalkToStopScreen(
            busStop: stop,
            userPosition: pos,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLatLng = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14.0,
              onTap: (_, __) => setState(() {
                _selectedStop = null;
              }),
            ),
            children: [
              buildCachedTileLayer(),
              MarkerLayer(markers: [
                if (userLatLng != null)
                  Marker(
                    point: userLatLng,
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.15),
                          ),
                        ),
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._busStops.map((stop) {
                  final count = stop.totalCount;
                  final isSelected = _selectedStop?.systemId == stop.systemId;
                  final isNearby = _nearbyStop?.systemId == stop.systemId;

                  return Marker(
                    point: LatLng(stop.latitude, stop.longitude),
                    width: 60, height: 72,
                    child: GestureDetector(
                      onTap: () => _onStopTapped(stop),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: count > 0 ? AppPalette.primaryDark : Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$count',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: (isSelected || isNearby) ? 42 : 36,
                            height: (isSelected || isNearby) ? 42 : 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppPalette.primary
                                  : isNearby
                                      ? Colors.orange.shade500
                                      : (count > 0 ? AppPalette.primary : Colors.grey.shade500),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: isSelected ? 3 : 2.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.hail_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ]),
            ],
          ),

          if (_isLoading)
            const Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Finding nearby stops...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Nearby bus stop suggestion — gentle, dismissible banner at top
          if (_nearbyStop != null && _selectedStop == null && !_nearbyDismissed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12, right: 12,
              child: _buildNearbyBanner(_nearbyStop!),
            ),

          // Selected stop — minimized pill OR expanded card
          if (_selectedStop != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: _isCardMinimized ? null : 16,
              right: 16,
              child: GestureDetector(
                onTap: _isCardMinimized
                    ? () => setState(() => _isCardMinimized = false)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isCardMinimized
                      ? null
                      : MediaQuery.of(context).size.width - 32,
                  child: _isCardMinimized
                      ? _buildMinimizedStopPill(_selectedStop!)
                      : _buildStopCard(_selectedStop!),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'My location',
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        onPressed: () {
          if (_userPosition != null) {
            _mapController.move(
              LatLng(_userPosition!.latitude, _userPosition!.longitude), 14.0,
            );
          }
        },
        child: const Icon(Icons.my_location, size: 20),
      ),
    );
  }

  /// Gentle top banner when passenger is near a bus stop
  Widget _buildNearbyBanner(BusStop stop) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.near_me, size: 20, color: AppPalette.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "You're near ${stop.systemId.replaceAll('_', ' ')}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${stop.totalCount} passengers waiting',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _checkIn(stop),
              style: TextButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Check In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() {
                _nearbyDismissed = true;
                _nearbyStop = null;
              }),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopCard(BusStop stop) {
    final totalCount = stop.totalCount;

    // Calculate distance
    double? distanceMeters;
    bool withinRange = false;
    if (_userPosition != null) {
      distanceMeters = geo.Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        stop.latitude, stop.longitude,
      );
      withinRange = distanceMeters <= kCheckInRadiusMeters;
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      Text(stop.systemId.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('$totalCount passengers waiting',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          if (distanceMeters != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: withinRange
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                withinRange
                                    ? 'In range'
                                    : distanceMeters > 1000
                                        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
                                        : '${distanceMeters.round()}m away',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: withinRange ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Minimize button
                IconButton(
                  icon: Icon(Icons.expand_more, size: 22, color: Colors.grey.shade500),
                  tooltip: 'Minimize',
                  onPressed: () => setState(() => _isCardMinimized = true),
                ),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedStop = null),
                ),
              ],
            ),
            if (stop.destinations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: stop.destinations.entries
                    .where((e) => e.value > 0)
                    .map((e) => Chip(
                          label: Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppPalette.primary.withOpacity(0.1),
                          side: BorderSide(color: AppPalette.primary.withOpacity(0.25)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                onPressed: totalCount > 0 ? () => _checkIn(stop) : null,
                icon: Icon(
                  withinRange ? Icons.how_to_reg : Icons.directions_walk,
                  size: 18,
                ),
                label: Text(
                  withinRange ? 'Check In Here' : 'Navigate to Stop',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: withinRange ? AppPalette.primary : AppPalette.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collapsed pill — shows stop name, count, and distance. Tap to expand.
  Widget _buildMinimizedStopPill(BusStop stop) {
    double? distanceMeters;
    bool withinRange = false;
    if (_userPosition != null) {
      distanceMeters = geo.Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        stop.latitude, stop.longitude,
      );
      withinRange = distanceMeters <= kCheckInRadiusMeters;
    }

    final distText = distanceMeters != null
        ? (distanceMeters > 1000
            ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
            : '${distanceMeters.round()}m')
        : null;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: withinRange ? AppPalette.primary : AppPalette.navy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hail_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              stop.systemId.replaceAll('_', ' '),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            _dot(),
            Text(
              '${stop.totalCount} pax',
              style: TextStyle(fontSize: 13, color: AppPalette.primaryDark, fontWeight: FontWeight.w600),
            ),
            if (distText != null) ...[
              _dot(),
              Text(
                distText,
                style: TextStyle(
                  fontSize: 13,
                  color: withinRange ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_less, size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
    );
  }
}
