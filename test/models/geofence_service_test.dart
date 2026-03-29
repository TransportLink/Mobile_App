import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobileapp/passenger/services/geofence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeofenceService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = GeofenceService();
  });

  group('Check-in state persistence', () {
    test('saveCheckInState stores time and stop', () async {
      await service.saveCheckInState('Legon_bustop');
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('last_check_in_time'), isNotNull);
      expect(prefs.getString('last_check_in_stop'), 'Legon_bustop');
    });

    test('clearCheckInState removes stored data', () async {
      await service.saveCheckInState('Legon_bustop');
      await service.clearCheckInState();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('last_check_in_time'), isNull);
      expect(prefs.getString('last_check_in_stop'), isNull);
    });

    test('clearCheckInState when nothing saved is safe', () async {
      await service.clearCheckInState();
      // No exception thrown
    });
  });

  group('Stale check-in detection', () {
    test('checkForStaleCheckIn returns null when no check-in', () async {
      final result = await service.checkForStaleCheckIn();
      expect(result, isNull);
    });

    test('checkForStaleCheckIn returns null for recent check-in', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_check_in_time', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_check_in_stop', 'Legon_bustop');

      final result = await service.checkForStaleCheckIn();
      expect(result, isNull);
    });

    test('checkForStaleCheckIn returns stopId for old check-in (>2h)', () async {
      final prefs = await SharedPreferences.getInstance();
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      await prefs.setInt('last_check_in_time', threeHoursAgo.millisecondsSinceEpoch);
      await prefs.setString('last_check_in_stop', 'Legon_bustop');

      final result = await service.checkForStaleCheckIn();
      expect(result, 'Legon_bustop');
    });

    test('checkForStaleCheckIn returns null if only time saved (no stop)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_check_in_time', 0);

      final result = await service.checkForStaleCheckIn();
      expect(result, isNull);
    });

    test('checkForStaleCheckIn returns null if only stop saved (no time)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_check_in_stop', 'Legon_bustop');

      final result = await service.checkForStaleCheckIn();
      expect(result, isNull);
    });

    test('stale detection clears check-in state', () async {
      final prefs = await SharedPreferences.getInstance();
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      await prefs.setInt('last_check_in_time', threeHoursAgo.millisecondsSinceEpoch);
      await prefs.setString('last_check_in_stop', 'test_stop');

      await service.checkForStaleCheckIn();

      // After detecting stale, it should be cleared
      expect(prefs.getInt('last_check_in_time'), isNull);
      expect(prefs.getString('last_check_in_stop'), isNull);
    });
  });

  group('Monitoring state', () {
    test('isMonitoring is false initially', () {
      expect(service.isMonitoring, false);
    });
  });
}
