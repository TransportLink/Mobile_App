import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/bus_stop_location.dart';
import 'package:mobileapp/core/widgets/cached_tile_layer.dart';
import 'passenger_checkin_screen.dart';

/// Threshold in meters — passenger must be within this range to check in.
const double kCheckInRadiusMeters = 150.0;

/// Screen shown when a passenger tries to check in but is too far from the stop.
/// Shows a walking polyline from their position to the bus stop, real-time GPS tracking,
/// distance countdown, and auto-redirects to check-in once they arrive within range.
class WalkToStopScreen extends StatefulWidget {
  final BusStop busStop;
  final geo.Position userPosition;

  const WalkToStopScreen({
    super.key,
    required this.busStop,
    required this.userPosition,
  });

  @override
  State<WalkToStopScreen> createState() => _WalkToStopScreenState();
}

class _WalkToStopScreenState extends State<WalkToStopScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Walking route polyline from OSRM
  List<LatLng> _routePoints = [];
  bool _loadingRoute = true;
  String? _routeError;

  // Live position tracking
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;
  double _distanceToStop = 0;
  double _walkingEtaMinutes = 0;
  double _totalDistanceMeters = 0;
  double _osrmDistanceMeters = 0; // straight-line dist at last OSRM polyline fetch
  bool _fetchingRoute = false; // prevent overlapping OSRM calls

  // State flags
  bool _arrivedAndNavigating = false; // prevent double-navigation
  bool _isPanelMinimized = false; // collapsed bottom panel

  // Status message shown at the top — explains what's happening
  String _statusTitle = 'Getting your walking route...';
  String _statusSubtitle = 'Hold on while we find the best path to the bus stop.';
  IconData _statusIcon = Icons.route;
  Color _statusColor = Colors.blue;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;
    _distanceToStop = _calcDistance(widget.userPosition);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchWalkingRoute();
    _startPositionTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  double _calcDistance(geo.Position pos) {
    return geo.Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.busStop.latitude,
      widget.busStop.longitude,
    );
  }

  // ─── Walking ETA (always from distance, never OSRM duration) ─────

  /// Average walking speed: 5 km/h = 83.3 m/min.
  static const _walkSpeedMPerMin = 83.3;

  /// Compute walking ETA from straight-line distance in meters.
  /// Adds a 1.3x detour factor since roads/paths aren't straight.
  double _calcWalkingEta(double distanceMeters) {
    final adjusted = distanceMeters * 1.3; // detour factor
    final mins = adjusted / _walkSpeedMPerMin;
    if (mins < 1 && distanceMeters > 30) return 1;
    return mins.ceilToDouble();
  }

  // ─── OSRM walking route (polyline only — duration is unreliable) ──

  Future<void> _fetchWalkingRoute() async {
    // Set walking ETA immediately from straight-line distance
    setState(() {
      _walkingEtaMinutes = _calcWalkingEta(_distanceToStop);
    });

    try {
      final pos = widget.userPosition;
      final stop = widget.busStop;

      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${pos.longitude},${pos.latitude};'
          '${stop.longitude},${stop.latitude}'
          '?overview=full&geometries=geojson';

      final response = await Dio().get(url);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          response.data['routes'] != null &&
          (response.data['routes'] as List).isNotEmpty) {
        final route = response.data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;
        final distanceM = (route['distance'] ?? 0).toDouble();

        final points =
            coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

        setState(() {
          _routePoints = points;
          _loadingRoute = false;
          _totalDistanceMeters = distanceM;
          // Use OSRM route distance (more accurate than straight-line) for ETA
          _walkingEtaMinutes = (distanceM / _walkSpeedMPerMin).ceilToDouble();
          _osrmDistanceMeters = _distanceToStop;
          _updateStatus();
        });

        _fitMapBounds();
      } else {
        setState(() {
          _loadingRoute = false;
          _routeError = 'Could not find a walking route. Head towards the bus stop marker on the map.';
          _updateStatus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRoute = false;
          _routeError = 'Could not load walking route. Head towards the bus stop marker on the map.';
          _updateStatus();
        });
      }
    }
  }

  void _fitMapBounds() {
    try {
      final userLl = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      final stopLl = LatLng(widget.busStop.latitude, widget.busStop.longitude);

      final bounds = LatLngBounds.fromPoints([userLl, stopLl]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (_) {}
  }

  // ─── Live position stream ─────────────────────────────────────────

  void _startPositionTracking() {
    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // update every 10m of movement
      ),
    ).listen(_onPositionUpdate, onError: (_) {});
  }

  void _onPositionUpdate(geo.Position position) {
    if (!mounted || _arrivedAndNavigating) return;

    final distance = _calcDistance(position);

    setState(() {
      _currentPosition = position;
      _distanceToStop = distance;
      _walkingEtaMinutes = _calcWalkingEta(distance);
      _updateStatus();
    });

    // Check if passenger arrived within range
    if (distance <= kCheckInRadiusMeters) {
      _onArrivedAtStop();
      return;
    }

    // Re-fetch OSRM route every ~200m of progress for accurate polyline + ETA
    if (_osrmDistanceMeters > 0 &&
        (_osrmDistanceMeters - distance).abs() > 200 &&
        !_fetchingRoute) {
      _refetchWalkingRoute(position);
    }
  }

  /// Re-fetch OSRM walking route from current position for updated polyline.
  /// ETA is always calculated from distance, never from OSRM duration.
  Future<void> _refetchWalkingRoute(geo.Position pos) async {
    _fetchingRoute = true;
    try {
      final stop = widget.busStop;
      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${pos.longitude},${pos.latitude};'
          '${stop.longitude},${stop.latitude}'
          '?overview=full&geometries=geojson';

      final response = await Dio().get(url);
      if (!mounted) return;

      if (response.statusCode == 200 &&
          response.data['routes'] != null &&
          (response.data['routes'] as List).isNotEmpty) {
        final route = response.data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;

        final points =
            coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

        setState(() {
          _routePoints = points;
          _osrmDistanceMeters = _distanceToStop;
        });
      }
    } catch (_) {
      // OSRM re-fetch failed — polyline stays as-is
    } finally {
      _fetchingRoute = false;
    }
  }

  // ─── Arrival logic ────────────────────────────────────────────────

  void _onArrivedAtStop() {
    if (_arrivedAndNavigating) return;
    _arrivedAndNavigating = true;

    setState(() {
      _statusTitle = "You've arrived!";
      _statusSubtitle =
          "You're now within range of ${_stopName}. Opening check-in...";
      _statusIcon = Icons.check_circle;
      _statusColor = Colors.green;
    });

    // Brief delay so the user sees the arrival message, then navigate
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PassengerCheckInScreen(
            busStop: BusStopLocation(
              systemId: widget.busStop.systemId,
              latitude: widget.busStop.latitude,
              longitude: widget.busStop.longitude,
              location: _stopName,
            ),
          ),
        ),
      );
    });
  }

  // ─── Status message logic ─────────────────────────────────────────

  String get _stopName => widget.busStop.systemId.replaceAll('_', ' ');

  /// Format minutes as "Xh Ym" when >= 60, otherwise "X min".
  String _formatEta(double minutes) {
    final mins = minutes.round();
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '$mins min';
  }

  void _updateStatus() {
    if (_arrivedAndNavigating) return;

    if (_loadingRoute) {
      _statusTitle = 'Getting your walking route...';
      _statusSubtitle = 'Hold on while we find the best path to the bus stop.';
      _statusIcon = Icons.route;
      _statusColor = Colors.blue;
      return;
    }

    final distInt = _distanceToStop.round();
    final etaStr = _formatEta(_walkingEtaMinutes);

    if (_distanceToStop > 5000) {
      _statusTitle = "You're ${(distInt / 1000).toStringAsFixed(1)} km away";
      _statusSubtitle =
          "$_stopName is quite far — about $etaStr on foot. "
          "You may want to take transport closer first.";
      _statusIcon = Icons.directions_walk;
      _statusColor = Colors.red;
    } else if (_distanceToStop > 1000) {
      _statusTitle = "You're ${(distInt / 1000).toStringAsFixed(1)} km away";
      _statusSubtitle =
          "Follow the path on the map to $_stopName. "
          "About $etaStr walk.";
      _statusIcon = Icons.directions_walk;
      _statusColor = Colors.orange;
    } else if (_distanceToStop > 300) {
      _statusTitle = "You're ${distInt}m away";
      _statusSubtitle =
          "Keep walking towards $_stopName. "
          "About $etaStr left. "
          "We'll let you check in when you arrive.";
      _statusIcon = Icons.directions_walk;
      _statusColor = Colors.blue;
    } else if (_distanceToStop > kCheckInRadiusMeters) {
      _statusTitle = 'Almost there! ${distInt}m to go';
      _statusSubtitle =
          "You're getting close to $_stopName. "
          "Check-in will open automatically when you're within ${kCheckInRadiusMeters.round()}m.";
      _statusIcon = Icons.near_me;
      _statusColor = AppPalette.primary;
    } else {
      // Within range — handled by _onArrivedAtStop
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;
    final stopLatLng = LatLng(widget.busStop.latitude, widget.busStop.longitude);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: stopLatLng,
              initialZoom: 15.0,
            ),
            children: [
              buildCachedTileLayer(),
              // Walking route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppPalette.navy.withOpacity(0.7),
                      strokeWidth: 5.0,
                      isDotted: true,
                    ),
                  ],
                ),
              // Range circle around bus stop
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: stopLatLng,
                    radius: kCheckInRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppPalette.primary.withOpacity(0.08),
                    borderColor: AppPalette.primary.withOpacity(0.3),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // User position
                  if (userLatLng != null)
                    Marker(
                      point: userLatLng,
                      width: 48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48 * _pulseAnimation.value,
                              height: 48 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.15),
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Bus stop marker
                  Marker(
                    point: stopLatLng,
                    width: 56,
                    height: 70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.primaryDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.busStop.totalCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppPalette.primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.hail_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Status card at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _buildStatusCard(),
          ),

          // Bottom info panel — collapsible
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: _isPanelMinimized ? null : 16,
            right: 16,
            child: GestureDetector(
              onTap: _isPanelMinimized
                  ? () => setState(() => _isPanelMinimized = false)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isPanelMinimized
                    ? null
                    : MediaQuery.of(context).size.width - 32,
                child: _isPanelMinimized
                    ? _buildMinimizedPill()
                    : _buildBottomPanel(),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 4,
            child: SafeArea(
              child: Material(
                elevation: 2,
                shape: const CircleBorder(),
                color: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Go back',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_statusIcon, size: 22, color: _statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final distInt = _distanceToStop.round();
    final etaInt = _walkingEtaMinutes.round();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stop name + minimize
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hail_rounded,
                      color: AppPalette.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_stopName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${widget.busStop.totalCount} passengers waiting',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.expand_more, size: 22, color: Colors.grey.shade500),
                  tooltip: 'Minimize',
                  onPressed: () => setState(() => _isPanelMinimized = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Distance + ETA row
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: distInt > 1000
                        ? '${(distInt / 1000).toStringAsFixed(1)} km'
                        : '${distInt}m',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoTile(
                    icon: Icons.schedule,
                    label: 'Walking time',
                    value: etaInt > 0 ? _formatEta(_walkingEtaMinutes) : '< 1 min',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoTile(
                    icon: Icons.gps_fixed,
                    label: 'Check-in range',
                    value: '${kCheckInRadiusMeters.round()}m',
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar showing how close they are to the check-in zone
            _buildProgressBar(),
            const SizedBox(height: 14),
            // Explanation text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You need to be within ${kCheckInRadiusMeters.round()}m of the bus stop to check in. '
                      'This ensures accurate passenger counts for drivers.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    // Calculate progress: 0.0 = starting distance, 1.0 = at the stop
    final initialDist = _totalDistanceMeters > 0
        ? _totalDistanceMeters
        : _calcDistance(widget.userPosition);
    final progress = (1.0 - (_distanceToStop / initialDist)).clamp(0.0, 1.0);

    final progressColor = progress > 0.8
        ? Colors.green
        : progress > 0.5
            ? AppPalette.primary
            : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress to check-in zone',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progressColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Collapsed pill — shows stop name, distance, and ETA. Tap to expand.
  Widget _buildMinimizedPill() {
    final distInt = _distanceToStop.round();
    final distText = distInt > 1000
        ? '${(distInt / 1000).toStringAsFixed(1)} km'
        : '${distInt}m';

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
                color: AppPalette.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_walk, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _stopName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
            ),
            Text(distText,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
            ),
            Text(
              _formatEta(_walkingEtaMinutes),
              style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_less, size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
