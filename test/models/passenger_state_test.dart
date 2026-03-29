import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/passenger/model/passenger_state.dart';

void main() {
  group('IncomingDriver', () {
    test('fromJson parses all fields', () {
      final json = {
        'driver_id': 'drv_1',
        'license_plate': 'GR-2341-20',
        'bus_color': 'blue',
        'eta': 5,
        'seats_available': 8,
      };

      final driver = IncomingDriver.fromJson(json);

      expect(driver.driverId, 'drv_1');
      expect(driver.licensePlate, 'GR-2341-20');
      expect(driver.busColor, 'blue');
      expect(driver.eta, 5);
      expect(driver.seatsAvailable, 8);
    });

    test('fromJson handles missing optional fields', () {
      final driver = IncomingDriver.fromJson({'driver_id': 'drv_2'});

      expect(driver.driverId, 'drv_2');
      expect(driver.licensePlate, isNull);
      expect(driver.eta, isNull);
      expect(driver.seatsAvailable, 0);
    });
  });

  group('PassengerCheckInState', () {
    test('fromJson parses check-in data', () {
      final json = {
        'checkin_id': 'chk_1',
        'system_id': 'Legon_bustop',
        'destination': 'Madina',
        'passenger_count': 2,
        'queue_position': 5,
        'total_waiting': 12,
        'checked_in_at': '2026-03-29T10:00:00Z',
        'incoming_drivers': [
          {'driver_id': 'drv_1', 'eta': 3, 'seats_available': 8},
        ],
      };

      final state = PassengerCheckInState.fromJson(json);

      expect(state.checkinId, 'chk_1');
      expect(state.systemId, 'Legon_bustop');
      expect(state.destination, 'Madina');
      expect(state.passengerCount, 2);
      expect(state.queuePosition, 5);
      expect(state.totalWaiting, 12);
      expect(state.incomingDrivers.length, 1);
      expect(state.incomingDrivers.first.eta, 3);
    });

    test('copyWith updates specific fields', () {
      final original = PassengerCheckInState(
        checkinId: 'chk_1',
        systemId: 'Legon_bustop',
        destination: 'Madina',
        passengerCount: 1,
        queuePosition: 3,
        totalWaiting: 10,
        checkedInAt: DateTime.now(),
        incomingDrivers: [],
      );

      final updated = original.copyWith(
        queuePosition: 2,
        totalWaiting: 9,
      );

      expect(updated.queuePosition, 2);
      expect(updated.totalWaiting, 9);
      expect(updated.destination, 'Madina');
      expect(updated.checkinId, 'chk_1');
    });
  });

  group('BusStopDemand', () {
    test('fromJson parses demand data', () {
      final json = {
        'system_id': 'Legon_bustop',
        'demand': {'Madina': 8, 'Circle': 3},
        'incoming_drivers': {
          'Madina': [
            {'driver_id': 'drv_1', 'eta': 4, 'seats_available': 10},
          ],
        },
      };

      final demand = BusStopDemand.fromJson(json);

      expect(demand.systemId, 'Legon_bustop');
      expect(demand.demand['Madina'], 8);
      expect(demand.demand['Circle'], 3);
      expect(demand.incomingDrivers['Madina']?.length, 1);
    });
  });
}
