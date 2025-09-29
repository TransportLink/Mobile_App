import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/route.dart';

void main() {
  group('Route model', () {
    test('fromJson maps route correctly', () {
      final json = {
        'geometry': {
          'coordinates': [
            [30.0, 10.0],
            [31.0, 11.0]
          ]
        },
        'eta': 120.0,
        'distance': 5000.0,
        'destination': 'Central'
      };

      final r = Route.fromJson(json);
      expect(r.coordinates.length, 2);
      expect(r.eta, 120.0);
      expect(r.distance, 5000.0);
      expect(r.destination, 'Central');
    });
  });
}
