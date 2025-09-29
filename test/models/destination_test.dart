import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/destination.dart';

void main() {
  group('Destination model', () {
    test('fromJson handles fields', () {
      final json = {
        'destination': 'Central',
        'dest_lat': '10.0',
        'dest_lng': '20.0',
        'passenger_count': '3',
        'eta': '15.5',
      };

      final d = Destination.fromJson(json);
      expect(d.destination, 'Central');
      expect(d.destLat, 10.0);
      expect(d.destLng, 20.0);
      expect(d.passengerCount, 3);
      expect(d.eta, 15.5);
    });

    test('toJson and toMap', () {
      final d = Destination(
          destination: 'East',
          passengerCount: 2,
          destLat: 1.0,
          destLng: 2.0,
          eta: 5.0);
      final json = d.toJson();
      expect(json['destination'], 'East');
      final map = d.toMap();
      expect(map['passengerCount'], 2);
    });
  });
}
