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
}