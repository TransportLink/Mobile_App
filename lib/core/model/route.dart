// ignore_for_file: public_member_api_docs, sort_constructors_first
class Route {
  final List<List<double>> coordinates;
  final double eta;
  final double distance;

  Route({
    required this.coordinates,
    required this.eta,
    required this.distance,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      coordinates: (json['geometry']['coordinates'] as List<dynamic>)
          .map((coord) => List<double>.from(coord))
          .toList(),
      eta: json['eta']?.toDouble() ?? 0.0,
      distance: json['distance']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'coordinates': coordinates,
      'eta': eta,
      'distance': distance,
    };
  }

  factory Route.fromMap(Map<String, dynamic> map) {
    return Route(
      coordinates: List<List<double>>.from((map['coordinates'] as List<int>)),
      eta: map['eta'] ?? 0,
      distance: map['distance'] ?? 0,
    );
  }
}
