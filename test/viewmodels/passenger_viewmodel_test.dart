import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/passenger/viewmodel/passenger_viewmodel.dart';
import 'package:mobileapp/passenger/model/passenger_state.dart';

void main() {
  group('PassengerState', () {
    test('default state is not checked in', () {
      final state = PassengerState();
      expect(state.isLoading, false);
      expect(state.isCheckedIn, false);
      expect(state.checkInState, isNull);
      expect(state.error, isNull);
      expect(state.selectedDestination, isNull);
      expect(state.passengerCount, 1);
    });

    test('copyWith updates specified fields', () {
      final state = PassengerState();
      final updated = state.copyWith(
        isLoading: true,
        selectedDestination: 'Madina',
        passengerCount: 3,
      );
      expect(updated.isLoading, true);
      expect(updated.selectedDestination, 'Madina');
      expect(updated.passengerCount, 3);
      expect(updated.isCheckedIn, false);
    });

    test('copyWith preserves unchanged fields', () {
      final checkIn = PassengerCheckInState(
        checkinId: 'chk_1',
        systemId: 'Legon_bustop',
        destination: 'Madina',
        passengerCount: 2,
        queuePosition: 5,
        totalWaiting: 12,
        checkedInAt: DateTime.now(),
        incomingDrivers: [],
      );
      final state = PassengerState(isCheckedIn: true, checkInState: checkIn, passengerCount: 2);
      final updated = state.copyWith(passengerCount: 3);
      expect(updated.isCheckedIn, true);
      expect(updated.checkInState?.destination, 'Madina');
      expect(updated.passengerCount, 3);
    });

    test('copyWith with error', () {
      final state = PassengerState();
      final withError = state.copyWith(error: 'Network failed');
      expect(withError.error, 'Network failed');
      expect(withError.isLoading, false);
    });
  });

  group('PassengerNotifier — destination selection', () {
    late PassengerNotifier notifier;

    setUp(() {
      notifier = PassengerNotifier();
    });

    test('selectDestination updates state', () {
      notifier.selectDestination('Madina');
      expect(notifier.state.selectedDestination, 'Madina');
      expect(notifier.state.error, isNull);
    });

    test('selectDestination clears previous error', () {
      notifier.state = PassengerState(error: 'old error');
      notifier.selectDestination('Circle');
      expect(notifier.state.error, isNull);
      expect(notifier.state.selectedDestination, 'Circle');
    });

    test('changing destination updates correctly', () {
      notifier.selectDestination('Madina');
      notifier.selectDestination('Lapaz');
      expect(notifier.state.selectedDestination, 'Lapaz');
    });
  });

  group('PassengerNotifier — passenger count', () {
    late PassengerNotifier notifier;

    setUp(() {
      notifier = PassengerNotifier();
    });

    test('default count is 1', () {
      expect(notifier.state.passengerCount, 1);
    });

    test('setPassengerCount updates count', () {
      notifier.setPassengerCount(4);
      expect(notifier.state.passengerCount, 4);
    });

    test('setPassengerCount clears error', () {
      notifier.state = PassengerState(error: 'some error');
      notifier.setPassengerCount(2);
      expect(notifier.state.error, isNull);
      expect(notifier.state.passengerCount, 2);
    });

    test('setPassengerCount to 1 (min)', () {
      notifier.setPassengerCount(1);
      expect(notifier.state.passengerCount, 1);
    });

    test('setPassengerCount to 10 (max)', () {
      notifier.setPassengerCount(10);
      expect(notifier.state.passengerCount, 10);
    });
  });

  group('PassengerNotifier — queue updates', () {
    late PassengerNotifier notifier;
    late PassengerCheckInState checkIn;

    setUp(() {
      notifier = PassengerNotifier();
      checkIn = PassengerCheckInState(
        checkinId: 'chk_1',
        systemId: 'Legon_bustop',
        destination: 'Madina',
        passengerCount: 1,
        queuePosition: 5,
        totalWaiting: 15,
        checkedInAt: DateTime.now(),
        incomingDrivers: [],
      );
    });

    test('updateQueuePosition updates check-in state', () {
      notifier.state = PassengerState(isCheckedIn: true, checkInState: checkIn);
      notifier.updateQueuePosition(3, 12);

      expect(notifier.state.checkInState?.queuePosition, 3);
      expect(notifier.state.checkInState?.totalWaiting, 12);
      expect(notifier.state.checkInState?.destination, 'Madina');
    });

    test('updateQueuePosition does nothing when not checked in', () {
      notifier.updateQueuePosition(1, 5);
      expect(notifier.state.checkInState, isNull);
      expect(notifier.state.isCheckedIn, false);
    });

    test('queue position can decrease (people served)', () {
      notifier.state = PassengerState(isCheckedIn: true, checkInState: checkIn);
      notifier.updateQueuePosition(2, 8);
      expect(notifier.state.checkInState?.queuePosition, 2);
      expect(notifier.state.checkInState?.totalWaiting, 8);
    });
  });

  group('PassengerNotifier — incoming drivers', () {
    late PassengerNotifier notifier;
    late PassengerCheckInState checkIn;

    setUp(() {
      notifier = PassengerNotifier();
      checkIn = PassengerCheckInState(
        checkinId: 'chk_1',
        systemId: 'Legon_bustop',
        destination: 'Madina',
        passengerCount: 1,
        queuePosition: 3,
        totalWaiting: 10,
        checkedInAt: DateTime.now(),
        incomingDrivers: [],
      );
    });

    test('updateIncomingDrivers adds drivers', () {
      notifier.state = PassengerState(isCheckedIn: true, checkInState: checkIn);
      final drivers = [
        IncomingDriver(driverId: 'drv_1', licensePlate: 'GR-123', eta: 4, seatsAvailable: 8),
        IncomingDriver(driverId: 'drv_2', licensePlate: 'GW-456', eta: 10, seatsAvailable: 12),
      ];
      notifier.updateIncomingDrivers(drivers);

      expect(notifier.state.checkInState?.incomingDrivers.length, 2);
      expect(notifier.state.checkInState?.incomingDrivers.first.licensePlate, 'GR-123');
      expect(notifier.state.checkInState?.incomingDrivers.last.eta, 10);
    });

    test('updateIncomingDrivers replaces previous list', () {
      notifier.state = PassengerState(
        isCheckedIn: true,
        checkInState: checkIn.copyWith(incomingDrivers: [
          IncomingDriver(driverId: 'old', seatsAvailable: 5),
        ]),
      );
      notifier.updateIncomingDrivers([
        IncomingDriver(driverId: 'new', seatsAvailable: 10),
      ]);
      expect(notifier.state.checkInState?.incomingDrivers.length, 1);
      expect(notifier.state.checkInState?.incomingDrivers.first.driverId, 'new');
    });

    test('updateIncomingDrivers with empty list clears drivers', () {
      notifier.state = PassengerState(
        isCheckedIn: true,
        checkInState: checkIn.copyWith(incomingDrivers: [
          IncomingDriver(driverId: 'drv', seatsAvailable: 5),
        ]),
      );
      notifier.updateIncomingDrivers([]);
      expect(notifier.state.checkInState?.incomingDrivers, isEmpty);
    });

    test('updateIncomingDrivers does nothing when not checked in', () {
      notifier.updateIncomingDrivers([
        IncomingDriver(driverId: 'drv', seatsAvailable: 5),
      ]);
      expect(notifier.state.checkInState, isNull);
    });
  });

  group('PassengerNotifier — error handling', () {
    late PassengerNotifier notifier;

    setUp(() {
      notifier = PassengerNotifier();
    });

    test('clearError removes error', () {
      notifier.state = PassengerState(error: 'something broke');
      notifier.clearError();
      expect(notifier.state.error, isNull);
    });

    test('clearError is idempotent', () {
      notifier.clearError();
      expect(notifier.state.error, isNull);
    });
  });

  group('PassengerNotifier — state transitions', () {
    late PassengerNotifier notifier;

    setUp(() {
      notifier = PassengerNotifier();
    });

    test('full lifecycle: select → check in → update → check out', () {
      // 1. Select destination
      notifier.selectDestination('Madina');
      notifier.setPassengerCount(2);
      expect(notifier.state.selectedDestination, 'Madina');
      expect(notifier.state.passengerCount, 2);

      // 2. Simulate check-in success
      final checkIn = PassengerCheckInState(
        checkinId: 'chk_1',
        systemId: 'Legon_bustop',
        destination: 'Madina',
        passengerCount: 2,
        queuePosition: 7,
        totalWaiting: 20,
        checkedInAt: DateTime.now(),
        incomingDrivers: [],
      );
      notifier.state = PassengerState(
        isCheckedIn: true,
        checkInState: checkIn,
      );
      expect(notifier.state.isCheckedIn, true);
      expect(notifier.state.checkInState?.destination, 'Madina');

      // 3. Queue update
      notifier.updateQueuePosition(5, 18);
      expect(notifier.state.checkInState?.queuePosition, 5);

      // 4. Driver approaching
      notifier.updateIncomingDrivers([
        IncomingDriver(driverId: 'drv_1', licensePlate: 'GR-111', busColor: 'blue', eta: 3, seatsAvailable: 8),
      ]);
      expect(notifier.state.checkInState?.incomingDrivers.length, 1);

      // 5. Simulate check-out
      notifier.state = PassengerState(
        isCheckedIn: false,
        checkInState: null,
      );
      expect(notifier.state.isCheckedIn, false);
      expect(notifier.state.checkInState, isNull);
    });
  });
}
