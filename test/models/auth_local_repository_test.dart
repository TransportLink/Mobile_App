import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthLocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = AuthLocalRepository();
    await repo.init();
  });

  group('Token management', () {
    test('setToken and getToken round trip', () {
      repo.setToken('access_token', 'abc123');
      expect(repo.getToken('access_token'), 'abc123');
    });

    test('getToken returns null for missing key', () {
      expect(repo.getToken('nonexistent'), isNull);
    });

    test('setToken with null value is no-op', () {
      repo.setToken('access_token', 'initial');
      repo.setToken('access_token', null);
      expect(repo.getToken('access_token'), 'initial');
    });

    test('removeToken clears stored value', () {
      repo.setToken('access_token', 'abc');
      repo.removeToken('access_token');
      expect(repo.getToken('access_token'), isNull);
    });

    test('removeToken on nonexistent key is safe', () {
      repo.removeToken('ghost_key');
      expect(repo.getToken('ghost_key'), isNull);
    });
  });

  group('Default vehicle', () {
    test('setDefaultVehicleId and getDefaultVehicleId', () async {
      await repo.setDefaultVehicleId('vehicle_123');
      expect(repo.getDefaultVehicleId(), 'vehicle_123');
    });

    test('getDefaultVehicleId returns null when not set', () {
      expect(repo.getDefaultVehicleId(), isNull);
    });

    test('removeDefaultVehicleId clears value', () async {
      await repo.setDefaultVehicleId('v1');
      await repo.removeDefaultVehicleId();
      expect(repo.getDefaultVehicleId(), isNull);
    });

    test('overwriting default vehicle', () async {
      await repo.setDefaultVehicleId('v1');
      await repo.setDefaultVehicleId('v2');
      expect(repo.getDefaultVehicleId(), 'v2');
    });
  });

  group('Active trip caching', () {
    test('cacheActiveTrip and getCachedActiveTrip round trip', () async {
      final tripData = {
        'trip_id': 42,
        'system_id': 'Legon_bustop',
        'destinations': [
          {'destination': 'Madina', 'passenger_count': 5},
        ],
      };

      await repo.cacheActiveTrip(tripData);
      final cached = repo.getCachedActiveTrip();

      expect(cached, isNotNull);
      expect(cached!['trip_id'], 42);
      expect(cached['system_id'], 'Legon_bustop');
      expect((cached['destinations'] as List).length, 1);
    });

    test('getCachedActiveTrip returns null when no cache', () {
      expect(repo.getCachedActiveTrip(), isNull);
    });

    test('clearCachedActiveTrip removes cache', () async {
      await repo.cacheActiveTrip({'trip_id': 1});
      await repo.clearCachedActiveTrip();
      expect(repo.getCachedActiveTrip(), isNull);
    });

    test('getCachedActiveTrip handles corrupted JSON gracefully', () async {
      // Manually set invalid JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_active_trip', 'not-valid-json{{{');

      expect(repo.getCachedActiveTrip(), isNull);
    });

    test('cacheActiveTrip with empty map', () async {
      await repo.cacheActiveTrip({});
      final cached = repo.getCachedActiveTrip();
      expect(cached, isNotNull);
      expect(cached, isEmpty);
    });

    test('cacheActiveTrip overwrites previous cache', () async {
      await repo.cacheActiveTrip({'trip_id': 1});
      await repo.cacheActiveTrip({'trip_id': 2});
      expect(repo.getCachedActiveTrip()!['trip_id'], 2);
    });
  });
}
