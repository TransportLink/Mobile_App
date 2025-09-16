class BusStop {
  final String systemId;
  final double latitude;
  final double longitude;
  final Map<String, int> destinations;
  final int totalCount;

  BusStop({
    required this.systemId,
    required this.latitude,
    required this.longitude,
    required this.destinations,
    required this.totalCount,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['coordinates'] as List<dynamic>;
    final properties = json['properties'] as Map<String, dynamic>;
    return BusStop(
      systemId: properties['system_id'] ?? '',
      latitude: geometry[1].toDouble(),
      longitude: geometry[0].toDouble(),
      destinations: Map<String, int>.from(properties['destinations'] ?? {}),
      totalCount: properties['total_count'] ?? 0,
    );
  }
}