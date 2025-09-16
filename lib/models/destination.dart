class Destination {
  final String destinationId;
  final String driverId;
  final String routeName;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String availabilityStatus;

  Destination({
    required this.destinationId,
    required this.driverId,
    required this.routeName,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.availabilityStatus,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      destinationId: json['destination_id'] ?? '',
      driverId: json['driver_id'] ?? '',
      routeName: json['route_name'] ?? '',
      startLatitude: json['start_latitude']?.toDouble() ?? 0.0,
      startLongitude: json['start_longitude']?.toDouble() ?? 0.0,
      endLatitude: json['end_latitude']?.toDouble() ?? 0.0,
      endLongitude: json['end_longitude']?.toDouble() ?? 0.0,
      availabilityStatus: json['availability_status'] ?? 'not_available',
    );
  }
}