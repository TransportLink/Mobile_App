import 'dart:math';

/// Bus Stop Location Model
///
/// Represents a bus stop with GPS coordinates for geofencing.
class BusStopLocation {
  final String systemId;
  final double latitude;
  final double longitude;
  final String location;

  BusStopLocation({
    required this.systemId,
    required this.latitude,
    required this.longitude,
    required this.location,
  });

  /// Calculate distance to this bus stop from a position
  double distanceFrom({
    required double latitude,
    required double longitude,
  }) {
    final latDiff = latitude - this.latitude;
    final lonDiff = longitude - this.longitude;
    return sqrt(latDiff * latDiff + lonDiff * lonDiff) * 111000; // Convert to meters
  }

  @override
  String toString() {
    return 'BusStopLocation(systemId: $systemId, location: $location)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusStopLocation && other.systemId == systemId;
  }

  @override
  int get hashCode => systemId.hashCode;
}
