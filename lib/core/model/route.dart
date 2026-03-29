// ignore_for_file: public_member_api_docs, sort_constructors_first

class Route {
  final List<List<double>> coordinates;
  final double eta;       // Always in MINUTES
  final double distance;  // Always in KILOMETERS
  final String destination;

  Route({
    required this.coordinates,
    required this.eta,
    required this.distance,
    required this.destination,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    // Map Microservice returns eta_seconds and distance_meters (explicit units).
    // Fall back to legacy eta/distance fields for backwards compatibility.
    final etaSeconds = json['eta_seconds']?.toDouble() ?? json['eta']?.toDouble() ?? 0.0;
    final distanceMeters = json['distance_meters']?.toDouble() ?? json['distance']?.toDouble() ?? 0.0;

    return Route(
      coordinates: (json['geometry']['coordinates'] as List<dynamic>)
          .map((coord) => List<double>.from(coord))
          .toList(),
      eta: etaSeconds / 60.0,          // Always convert seconds → minutes
      distance: distanceMeters / 1000.0, // Always convert meters → kilometers
      destination: json['destination']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'coordinates': coordinates,
      'eta': eta,
      'distance': distance,
      'destination': destination,
    };
  }

  factory Route.fromMap(Map<String, dynamic> map) {
    return Route(
      coordinates: (map['coordinates'] as List)
          .map<List<double>>((x) => List<double>.from(x))
          .toList(),
      eta: (map['eta'] as num).toDouble(),
      distance: (map['distance'] as num).toDouble(),
      destination: map['destination'] as String,
    );
  }
}
