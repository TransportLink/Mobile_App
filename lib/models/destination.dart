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
      startLatitude:
          double.tryParse(json['start_latitude']?.toString() ?? '') ?? 0.0,
      startLongitude:
          double.tryParse(json['start_longitude']?.toString() ?? '') ?? 0.0,
      endLatitude:
          double.tryParse(json['end_latitude']?.toString() ?? '') ?? 0.0,
      endLongitude:
          double.tryParse(json['end_longitude']?.toString() ?? '') ?? 0.0,
      availabilityStatus: json['availability_status'] ?? 'not_available',
    );
  }
}
