
// ignore_for_file: public_member_api_docs, sort_constructors_first
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

  BusStop copyWith({
    String? systemId,
    double? latitude,
    double? longitude,
    Map<String, int>? destinations,
    int? totalCount,
  }) {
    return BusStop(
      systemId: systemId ?? this.systemId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      destinations: destinations ?? this.destinations,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'systemId': systemId,
      'latitude': latitude,
      'longitude': longitude,
      'destinations': destinations,
      'totalCount': totalCount,
    };
  }

  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      systemId: map['systemId'] ?? '',
      latitude: map['latitude'] ?? 0,
      longitude: map['longitude'] ?? 0,
      destinations: Map<String, int>.from((map['destinations'] as Map<String, int>)),
      totalCount: map['totalCount'] as int,
    );
  }
}
