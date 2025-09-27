import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobileapp/core/model/driver_model.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/features/map/repository/driver_location_repository.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_view_model.g.dart';

@riverpod
class MapViewModel extends _$MapViewModel {
  late final AuthViewmodel _authViewmodel;
  late final AuthLocalRepository _authLocalRepository;
  late final DriverLocationRepository _driverLocationRepository;
  late final MapRepository _mapRepository;

  Timer? _locationUpdateTimer;
  Timer? _busStopUpdateTimer;
  Timer? _routeUpdateTimer;

  @override
  AsyncValue<DriverModel>? build() {
    _authViewmodel = ref.watch(authViewmodelProvider.notifier);
    _driverLocationRepository = ref.watch(driverLocationRepositoryProvider);
    _mapRepository = ref.watch(mapRepositoryProvider);
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);

    return null;
  }
  
  Future<void> initializeDriverId() async {
    state = const AsyncValue.loading();

    final res = await _authViewmodel.getDriverData();
    print(res?.full_name);

    final val = switch (res) {
      Right(value: final r) => state =
          AsyncValue.data(r.copyWith(driverId: res!.driverId)),
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      DriverModel() => state =
          AsyncValue.error("Something went wrong!", StackTrace.current),
      null => state =
          AsyncValue.error("Something went wrong!", StackTrace.current),
    };

    print(val);
    return;
  }

  /// Request location permission
  Future<void> requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isGranted) {
      await fetchBusStops();
      startBusStopUpdates();
    } else {
      state =
          AsyncValue.error("Location permission denied", StackTrace.current);
    }
  }

  /// Start updating driver location every 10s
  void startLocationUpdates() {
    state = AsyncValue.loading();

    _locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );

        final res = await _mapRepository.fetchReverseGeocoding(
            latitude: position.latitude, longitude: position.longitude);

        String? address;
        final _ = switch (res) {
          Right(value: final r) => address = r['place_name']?.toString(),
          Left(value: final _) => address = 'Unknown',
        };

        print(
            "📍 Updating location: ${position.latitude}, ${position.longitude}, address: $address");

        final result = await _driverLocationRepository.updateDriverLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address!);

        final val = switch (result) {
          Left(value: final l) => state =
              AsyncValue.error(l.message, StackTrace.current),
          Right(value: final _) => state
        };
        print(val);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  /// Fetch bus stops near driver
  Future<void> fetchBusStops() async {
    state = const AsyncValue.loading();

    final pos = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    final res = await _mapRepository.fetchBusStops(
      latitude: pos.latitude,
      longitude: pos.longitude,
      radius: state!.value?.searchRadius ?? 5.0,
    );

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state =
          AsyncValue.data(state!.value!.copyWith(busStops: r))
    };

    print(val);
  }

  /// Poll bus stops every 30s
  void startBusStopUpdates() {
    _busStopUpdateTimer ??=
        Timer.periodic(const Duration(seconds: 30), (_) => fetchBusStops());
  }

  /// Start updating route every 15s
  Future<void> startRouteUpdates() async {
    _routeUpdateTimer ??=
        Timer.periodic(const Duration(seconds: 15), (_) async {
      final currentState = state!.value;
      if (currentState?.currentDestination == null ||
          currentState?.driverId == null) {
        return;
      }

      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );

        final dest = currentState!.currentDestination!;
        final res = await _mapRepository.fetchRoute(
          driverId: currentState.driverId!,
          destination: dest.routeName.split(' to ').last,
          systemId: dest.routeName.split(' to ').first,
          destLat: dest.endLatitude,
          destLng: dest.endLongitude,
          startLat: pos.latitude,
          startLng: pos.longitude,
          accessToken: _authLocalRepository.getToken('access_token')!,
        );

        final val = switch (res) {
          Left(value: final l) => state =
              AsyncValue.error(l.message, StackTrace.current),
          Right(value: final r) => state =
              AsyncValue.data(state!.value!.copyWith(currentRoute: r))
        };
        print(val.value);
      } catch (e) {
        print("❌ Error updating route: $e");
        state = AsyncValue.error(
            "Something went wrong. Error updating route.", StackTrace.current);
      }
    });
  }

  /// Cleanup timers
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _busStopUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
  }
}
