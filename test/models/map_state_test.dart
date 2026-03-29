import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart';

void main() {
  group('MapState', () {
    test('default state has correct values', () {
      const state = MapState();
      expect(state.busStops, isEmpty);
      expect(state.currentRoute, isNull);
      expect(state.selectedDestinations, isEmpty);
      expect(state.currentBusStopId, isNull);
      expect(state.selectedVehicleId, isNull);
      expect(state.tripId, isNull);
      expect(state.searchRadius, 5.0);
      expect(state.isOnTrip, false);
    });

    test('copyWith updates specified fields only', () {
      const state = MapState();
      final updated = state.copyWith(
        isOnTrip: true,
        tripId: 42,
        searchRadius: 10.0,
      );

      expect(updated.isOnTrip, true);
      expect(updated.tripId, 42);
      expect(updated.searchRadius, 10.0);
      expect(updated.busStops, isEmpty);
      expect(updated.currentRoute, isNull);
    });

    test('copyWith preserves bus stops', () {
      final stops = [
        BusStop(systemId: 's1', latitude: 5.6, longitude: -0.1, destinations: {'Madina': 5}, totalCount: 5),
      ];
      final state = MapState(busStops: stops);
      final updated = state.copyWith(isOnTrip: true);

      expect(updated.busStops.length, 1);
      expect(updated.busStops.first.systemId, 's1');
    });

    test('copyWith with route', () {
      final route = Route(coordinates: [[0.0, 0.0]], eta: 5.0, distance: 2.0, destination: 'Test');
      const state = MapState();
      final updated = state.copyWith(currentRoute: route);

      expect(updated.currentRoute, isNotNull);
      expect(updated.currentRoute!.eta, 5.0);
    });

    test('copyWith with destinations list', () {
      final dests = [
        Destination(destination: 'Madina', passengerCount: 3),
        Destination(destination: 'Circle', passengerCount: 2),
      ];
      const state = MapState();
      final updated = state.copyWith(selectedDestinations: dests);

      expect(updated.selectedDestinations.length, 2);
      expect(updated.selectedDestinations.first.passengerCount, 3);
    });

    test('toString produces readable output', () {
      const state = MapState();
      final str = state.toString();
      expect(str, contains('busStops: 0'));
      expect(str, contains('hasRoute: false'));
      expect(str, contains('isOnTrip: false'));
    });

    test('trip state consistency', () {
      const state = MapState();
      final onTrip = state.copyWith(
        isOnTrip: true,
        tripId: 100,
        currentBusStopId: 'Legon_bustop',
        selectedVehicleId: 'v1',
      );

      expect(onTrip.isOnTrip, true);
      expect(onTrip.tripId, 100);
      expect(onTrip.currentBusStopId, 'Legon_bustop');
      expect(onTrip.selectedVehicleId, 'v1');
    });
  });
}
