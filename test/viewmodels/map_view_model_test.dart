import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/map/model/map_state.dart';

void main() {
  group('MapViewModel basic', () {
    test('MapState defaults are correct', () async {
      final state = const MapState();
      expect(state.busStops, isA<List>());
      expect(state.searchRadius, 5.0);
      expect(state.isOnTrip, isFalse);
      expect(state.selectedDestinations.length, 0);
    });
  });
}
