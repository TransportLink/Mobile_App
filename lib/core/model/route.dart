// ignore_for_file: public_member_api_docs, sort_constructors_first

class Route {
  final List<List<double>> coordinates;
  final double eta;
  final double distance;
  final String destination;

  Route({
    required this.coordinates,
    required this.eta,
    required this.distance,
    required this.destination,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      coordinates: (json['geometry']['coordinates'] as List<dynamic>)
          .map((coord) => List<double>.from(coord))
          .toList(),
      eta: json['eta']?.toDouble() ?? 0.0,
      distance: json['distance']?.toDouble() ?? 0.0,
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
      eta: map['eta'] as double,
      distance: map['distance'] as double,
      destination: map['destination'] as String,
    );
  }
}
