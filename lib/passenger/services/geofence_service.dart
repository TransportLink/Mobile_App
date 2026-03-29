import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exit-only geofence using Geolocator position stream.
///
/// Only purpose: detect when a checked-in passenger moves away from
/// their bus stop and fire [onAutoCheckout] so the app can log them out.
///
/// No polling timers. The stream wakes up only when the device moves
/// ≥ [_distanceFilterMeters], so battery impact is minimal.
class GeofenceService {
  /// How far the passenger must move before we even check (GPS wake threshold).
  static const double _distanceFilterMeters = 30.0;

  /// Distance from the check-in stop that triggers auto-checkout.
  static const double _exitThresholdMeters = 150.0;

  StreamSubscription<Position>? _positionSub;

  String? _checkedInSystemId;
  double? _stopLat;
  double? _stopLng;

  /// Called when the passenger is detected to have left the bus stop.
  /// The [reason] string is passed straight through to [checkOut()].
  void Function(String systemId)? onAutoCheckout;

  /// Start monitoring for exit after a successful check-in.
  ///
  /// [systemId] is stored so the callback knows which stop was left.
  /// [stopLat] / [stopLng] is the bus stop centre used for distance checks.
  Future<void> startExitMonitoring({
    required String systemId,
    required double stopLat,
    required double stopLng,
  }) async {
    // Always cancel any prior subscription first
    await stopExitMonitoring();

    _checkedInSystemId = systemId;
    _stopLat = stopLat;
    _stopLng = stopLng;

    // Verify permission before opening the stream
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // Can't monitor without permission — fail silently
    }

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _distanceFilterMeters.toInt(),
      // Don't keep the app alive in background just for exit detection
      foregroundNotificationConfig: null,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPosition,
      onError: (_) {}, // Non-critical — passenger can still checkout manually
      cancelOnError: false,
    );
  }

  void _onPosition(Position position) {
    if (_stopLat == null || _stopLng == null || _checkedInSystemId == null) {
      return;
    }

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _stopLat!,
      _stopLng!,
    );

    if (distanceMeters > _exitThresholdMeters) {
      final systemId = _checkedInSystemId!;
      // Stop monitoring before firing callback to avoid double-triggers
      stopExitMonitoring();
      onAutoCheckout?.call(systemId);
    }
  }

  /// Stop exit monitoring (called on manual checkout or app teardown).
  Future<void> stopExitMonitoring() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _checkedInSystemId = null;
    _stopLat = null;
    _stopLng = null;
  }

  bool get isMonitoring => _positionSub != null;

  // ── Stale check-in helpers (unchanged) ───────────────────────────────────

  Future<void> saveCheckInState(String stopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_check_in_time', DateTime.now().millisecondsSinceEpoch);
    await prefs.setString('last_check_in_stop', stopId);
  }

  Future<void> clearCheckInState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_check_in_time');
    await prefs.remove('last_check_in_stop');
  }

  Future<String?> checkForStaleCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt('last_check_in_time');
    final lastStop = prefs.getString('last_check_in_stop');
    if (lastTime == null || lastStop == null) return null;

    final hoursSince =
        (DateTime.now().millisecondsSinceEpoch - lastTime) / 3600000;
    if (hoursSince > 2) {
      await clearCheckInState();
      return lastStop; // Caller decides what to do with the stale stop
    }
    return null;
  }
}

// Singleton
final geofenceService = GeofenceService();
