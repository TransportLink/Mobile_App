class Destination {
  final String? destination;
  final double? destLat;
  final double? destLng;
  int passengerCount;
  final double? eta;

  Destination({
    this.destination,
    this.destLat,
    this.destLng,
    required this.passengerCount,
    this.eta,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      destination: json['destination']?.toString(),
      destLat: double.tryParse(json['dest_lat']?.toString() ?? ''),
      destLng: double.tryParse(json['dest_lng']?.toString() ?? ''),
      passengerCount:
          int.tryParse(json['passenger_count']?.toString() ?? '') ?? 0,
      eta: double.tryParse(json['eta']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'passenger_count': passengerCount,
    };
    if (destination != null) map['destination'] = destination;
    if (destLat != null) map['dest_lat'] = destLat;
    if (destLng != null) map['dest_lng'] = destLng;
    if (eta != null) map['eta'] = eta;
    return map;
  }
}
