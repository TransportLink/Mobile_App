// ignore_for_file: public_member_api_docs, sort_constructors_first

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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'destination': destination,
      'destLat': destLat,
      'destLng': destLng,
      'passengerCount': passengerCount,
      'eta': eta,
    };
  }

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      destination: map['destination'] != null ? map['destination'] as String : null,
      destLat: map['destLat'] != null ? map['destLat'] as double : null,
      destLng: map['destLng'] != null ? map['destLng'] as double : null,
      passengerCount: map['passengerCount'] as int,
      eta: map['eta'] != null ? map['eta'] as double : null,
    );
  }
}
