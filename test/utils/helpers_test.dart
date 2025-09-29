import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/map/utils/helpers.dart';

void main() {
  group('Helpers.isPointNearCoordinates', () {
    test('returns true for nearby points', () {
      final aLat = 10.0;
      final aLon = 20.0;
      final bLat = 10.002;
      final bLon = 19.998;

      final result = Helpers.isPointNearCoordinates(aLat, aLon, bLat, bLon,
          tolerance: 0.01);
      expect(result, isTrue);
    });

    test('returns false for distant points', () {
      final result =
          Helpers.isPointNearCoordinates(0, 0, 1, 1, tolerance: 0.0001);
      expect(result, isFalse);
    });
  });
}
