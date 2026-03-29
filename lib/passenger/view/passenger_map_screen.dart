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
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _loadLocationAndStops() async {
    final lastKnown = await geo.Geolocator.getLastKnownPosition();
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
    } catch (_) {}
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
      _nearbyStop = null; // hide nearby card when user taps a stop
    });
  }

  void _checkIn(BusStop stop) {
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.airlectric.smarttrotro',
                errorTileCallback: (tile, error, stackTrace) {},
              ),
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
                    width: 60, height: 68,
                    child: GestureDetector(
                      onTap: () => _onStopTapped(stop),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
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
                                  ? Colors.blue.shade600
                                  : isNearby
                                      ? Colors.orange.shade500
                                      : (count > 0 ? Colors.green.shade600 : Colors.grey.shade500),
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

          // Selected stop bottom card (tapped from map)
          if (_selectedStop != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16, right: 16,
              child: _buildStopCard(_selectedStop!),
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
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.near_me, size: 20, color: Colors.green.shade700),
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
                backgroundColor: Colors.green.shade600,
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hail_rounded, color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop.systemId.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('$totalCount passengers waiting',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
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
                          backgroundColor: Colors.green.shade50,
                          side: BorderSide(color: Colors.green.shade200),
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
                icon: const Icon(Icons.how_to_reg, size: 18),
                label: const Text('Check In Here',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
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
}
