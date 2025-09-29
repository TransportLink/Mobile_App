import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';
import 'package:mobileapp/core/model/driver_model.dart';

class MockMapRepository extends Mock implements MapRepository {}

class _FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    return Position(
      latitude: 10.0,
      longitude: 20.0,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
    );
  }
}

void main() {
  late MockMapRepository mockMapRepo;

  setUp(() {
    mockMapRepo = MockMapRepository();
    GeolocatorPlatform.instance = _FakeGeolocator();
  });

  test('acceptTrip happy path updates MapState', () async {
    final container = ProviderContainer(overrides: [
      mapRepositoryProvider.overrideWithValue(mockMapRepo),
    ]);

    // Add a fake current driver
    container.read(currentDriverProvider.notifier).addCurrentDriver(
          DriverModel(
            id: 'driver-1',
            driverId: 'driver-1',
            full_name: 'Test Driver',
            email: 'test@example.com',
            password_hash: 'hash',
            phone_number: '000',
            date_of_birth: '1990-01-01',
            license_number: 'L123',
            license_expiry: '2030-01-01',
            national_id: 'NID123',
          ),
        );

    final busStop = BusStop(
      systemId: 'stop-1',
      latitude: 10.0,
      longitude: 20.0,
      destinations: {'Center': 3},
      totalCount: 3,
    );

    final destinations = [
      Destination(destination: 'Center', passengerCount: 2)
    ];

    // Mock fetchRoute to return success with a route structure and trip_id
    final fakeRouteJson = {
      'route': {
        'geometry': {
          'coordinates': [
            [20.0, 10.0],
            [21.0, 11.0]
          ]
        },
        'eta': 120.0,
        'distance': 5000.0,
        'destination': 'Center'
      },
      'trip_id': 123
    };

    when(() => mockMapRepo.fetchRoute(
          driverId: any(named: 'driverId'),
          systemId: any(named: 'systemId'),
          busStop: any(named: 'busStop'),
          busStopLat: any(named: 'busStopLat'),
          busStopLng: any(named: 'busStopLng'),
          destinations: any(named: 'destinations'),
          vehicleId: any(named: 'vehicleId'),
        )).thenAnswer((_) async => Right(fakeRouteJson));

    // Ensure the autoDispose provider is kept alive during the test
    container.listen(mapViewModelProvider, (_, __) {}, fireImmediately: true);
    // Call acceptTrip on the provider notifier
    final notifier = container.read(mapViewModelProvider.notifier);
    // Ensure notifier build runs so _mapRepository is wired
    notifier.runBuild();

    // Set selected vehicle id to satisfy validation
    notifier.updateSelectedVehicle('vehicle-1');

    await notifier.acceptTrip(
        busStop: busStop, destinations: destinations, vehicleId: 'vehicle-1');

    final notifierState = notifier.state;
    if (notifierState == null) fail('Notifier state is null');

    notifierState.when(
      data: (state) {
        expect(state, isNotNull);
        expect(state.isOnTrip, isTrue);
        expect(state.tripId, 123);
        expect(state.currentRoute, isNotNull);
        expect(state.selectedVehicleId, 'vehicle-1');
      },
      loading: () => fail('State is still loading'),
      error: (e, st) => fail('Notifier errored: $e'),
    );
  });

  test('cancelTrip happy path clears trip state', () async {
    final container = ProviderContainer(overrides: [
      mapRepositoryProvider.overrideWithValue(mockMapRepo),
    ]);

    // Seed current driver
    container.read(currentDriverProvider.notifier).addCurrentDriver(
          DriverModel(
            id: 'driver-1',
            driverId: 'driver-1',
            full_name: 'Test Driver',
            email: 'test@example.com',
            password_hash: 'hash',
            phone_number: '000',
            date_of_birth: '1990-01-01',
            license_number: 'L123',
            license_expiry: '2030-01-01',
            national_id: 'NID123',
          ),
        );

    // Prepare a MapState with an ongoing trip via notifier
    // Ensure the autoDispose provider is kept alive during the test
    container.listen(mapViewModelProvider, (_, __) {}, fireImmediately: true);
    final notifier = container.read(mapViewModelProvider.notifier);
    notifier.runBuild();
    // Simulate that the driver accepted a trip earlier
    notifier.updateSelectedVehicle('vehicle-1');
    // Directly set state to emulate an ongoing trip (simplified)
    final currentState = const MapState().copyWith(
      isOnTrip: true,
      tripId: 321,
      currentBusStopId: 'stop-1',
      selectedVehicleId: 'vehicle-1',
      selectedDestinations: [
        Destination(destination: 'Center', passengerCount: 1)
      ],
      busStops: [
        BusStop(
            systemId: 'stop-1',
            latitude: 10,
            longitude: 20,
            destinations: {'Center': 1},
            totalCount: 1)
      ],
    );
    // Use internal setter to set state
    notifier.state = AsyncValue.data(currentState);

    // Mock cancelRoute to return success
    when(() => mockMapRepo.cancelRoute(
          driverId: any(named: 'driverId'),
          systemId: any(named: 'systemId'),
          vehicleId: any(named: 'vehicleId'),
          destination: any(named: 'destination'),
          destLat: any(named: 'destLat'),
          destLng: any(named: 'destLng'),
          passengerCount: any(named: 'passengerCount'),
          tripId: any(named: 'tripId'),
        )).thenAnswer((_) async => Right({'success': true}));

    await notifier.cancelTrip();

    final finalState = notifier.state;
    if (finalState == null) fail('Notifier state is null after cancel');
    finalState.when(
      data: (s) {
        expect(s.isOnTrip, isFalse);
        expect(s.tripId, isNull);
        expect(s.currentRoute, isNull);
      },
      loading: () => fail('State is still loading after cancel'),
      error: (e, st) => fail('Notifier errored after cancel: $e'),
    );
  });
}
