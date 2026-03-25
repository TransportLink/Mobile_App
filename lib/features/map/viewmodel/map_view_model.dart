import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:mobileapp/features/map/repository/driver_location_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'map_view_model.g.dart';

@riverpod
class MapViewModel extends _$MapViewModel {
  late MapRepository _mapRepository;
  late DriverLocationRepository _driverLocationRepository;

  Timer? _locationUpdateTimer;
  Timer? _busStopUpdateTimer;
  Timer? _routeUpdateTimer;
  bool _approachingNotified = false;

  @override
  AsyncValue<MapState>? build() {
    _mapRepository = ref.watch(mapRepositoryProvider);
    _driverLocationRepository = ref.watch(driverLocationRepositoryProvider);

    return const AsyncValue.data(MapState());
  }

  Future<void> initializeMap() async {
    state = const AsyncValue.loading();

    try {
      final prefs = await SharedPreferences.getInstance();
      final tripId = prefs.getInt('trip_id');

      final currentState = state?.value ?? const MapState();
      final newState = currentState.copyWith(
        tripId: tripId,
        isOnTrip: tripId != null,
      );

      state = AsyncValue.data(newState);

      _startLocationUpdates();
      _startBusStopUpdates();

      if (tripId != null) {
        _startRouteUpdates();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> fetchBusStops({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    const maxRetries = 3;
    var retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final currentState = state?.value ?? const MapState();

        geo.Position? position;
        if (latitude == null || longitude == null) {
          position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }

        final searchRadius = radius ?? currentState.searchRadius;

        final result = await _mapRepository.fetchBusStops(
          latitude: latitude,
          longitude: longitude,
          radius: searchRadius,
        );

        switch (result) {
          case Left(value: final error):
            if (error.message.contains('503')) {
              retryCount++;
              print('Retrying fetch bus stops ($retryCount/$maxRetries)');
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            state = AsyncValue.error(error.message, StackTrace.current);
            return;
          case Right(value: final busStops):
            final newState = currentState.copyWith(
              busStops: busStops,
              searchRadius: searchRadius,
            );
            state = AsyncValue.data(newState);
            return;
        }
      } catch (e, st) {
        if (e.toString().contains('503')) {
          retryCount++;
          print('Retrying fetch bus stops ($retryCount/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        state = AsyncValue.error(e, st);
        return;
      }
    }
    state = AsyncValue.error(
        'Failed to fetch bus stops after $maxRetries retries',
        StackTrace.current);
  }

  Future<void> acceptTrip({
    required BusStop busStop,
    required List<Destination> destinations,
    required String vehicleId,
  }) async {
    try {
      final currentDriver = ref.read(currentDriverNotifierProvider);
      if (currentDriver?.driverId == null) {
        state = AsyncValue.error('Driver ID not found', StackTrace.current);
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      final destinationsData = destinations
          .map((d) => {
                'destination': d.destination,
                'passenger_count': d.passengerCount,
              })
          .toList();

      final result = await _mapRepository.fetchRoute(
        driverId: currentDriver!.driverId!,
        systemId: busStop.systemId,
        busStop: busStop.systemId,
        busStopLat: busStop.latitude,
        busStopLng: busStop.longitude,
        destinations: destinationsData,
        vehicleId: vehicleId,
      );

      switch (result) {
        case Left(value: final error):
          state = AsyncValue.error(error.message, StackTrace.current);
          break;
        case Right(value: final routeData):
          final route = Route.fromJson(routeData['route']);
          final tripId = routeData['trip_id'] as int;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('trip_id', tripId);

          final currentState = state?.value ?? const MapState();
          final newState = currentState.copyWith(
            currentRoute: route,
            selectedDestinations: destinations,
            currentBusStopId: busStop.systemId,
            selectedVehicleId: vehicleId,
            tripId: tripId,
            isOnTrip: true,
          );

          state = AsyncValue.data(newState);

          // Show trip confirmed notification
          final totalPassengers =
              destinations.fold(0, (sum, d) => sum + d.passengerCount);
          NotificationService().showTripConfirmed(
            tripId: tripId,
            stopName: busStop.systemId,
            etaMinutes: route.eta / 60,
            passengerCount: totalPassengers,
            destination: destinations.isNotEmpty
                ? (destinations.first.destination ?? '')
                : '',
          );

          _startRouteUpdates();
          break;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelTrip() async {
    try {
      final currentState = state?.value;
      if (currentState == null ||
          !currentState.isOnTrip ||
          currentState.tripId == null ||
          currentState.currentBusStopId == null ||
          currentState.selectedVehicleId == null ||
          currentState.selectedDestinations.isEmpty) {
        await _clearTripState();
        return;
      }

      final currentDriver = ref.read(currentDriverNotifierProvider);
      if (currentDriver?.driverId == null) {
        state = AsyncValue.error('Driver ID not found', StackTrace.current);
        return;
      }

      final firstDestination = currentState.selectedDestinations.first;
      final busStop = currentState.busStops.firstWhere(
        (stop) => stop.systemId == currentState.currentBusStopId,
      );

      final result = await _mapRepository.cancelRoute(
        driverId: currentDriver!.driverId!,
        systemId: currentState.currentBusStopId!,
        vehicleId: currentState.selectedVehicleId!,
        destination: firstDestination.destination ?? '',
        destLat: busStop.latitude,
        destLng: busStop.longitude,
        passengerCount: firstDestination.passengerCount,
        tripId: currentState.tripId!,
      );

      switch (result) {
        case Left(value: final error):
          state = AsyncValue.error(error.message, StackTrace.current);
          break;
        case Right(value: final _):
          await _clearTripState();
          break;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> arrivedAtDestination() async {
    final currentState = state?.value;
    if (currentState != null && currentState.selectedDestinations.isNotEmpty) {
      final firstDest = currentState.selectedDestinations.first;
      if (firstDest.destination != null) {
        await _driverLocationRepository.updateDestination(
          firstDest.destination!,
          'available',
        );
      }
    }
    await _clearTripState();
  }

  Future<void> updateSearchRadius(double radius) async {
    final currentState = state?.value ?? const MapState();
    final newState = currentState.copyWith(searchRadius: radius);
    state = AsyncValue.data(newState);

    await fetchBusStops(radius: radius);
  }

  void updateSelectedVehicle(String vehicleId) {
    final currentState = state?.value ?? const MapState();
    final newState = currentState.copyWith(selectedVehicleId: vehicleId);
    state = AsyncValue.data(newState);
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        try {
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
          );

          // Reverse geocode current position
          final addressResult = await _mapRepository.fetchReverseGeocoding(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          String address = 'Unknown';
          switch (addressResult) {
            case Right(value: final data):
              address = data['place_name']?.toString() ?? 'Unknown';
              break;
            case Left():
              break;
          }

          // Update driver location on the auth service
          await _driverLocationRepository.updateDriverLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
          );
        } catch (e) {
          print('Error updating driver location: $e');
        }
      },
    );
  }

  /// Start bus stop updates every 30 seconds
  void _startBusStopUpdates() {
    _busStopUpdateTimer?.cancel();
    _busStopUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          await fetchBusStops();
        } catch (e) {
          print('Error in periodic bus stop update: $e');
        }
      },
    );
  }

  void _startRouteUpdates() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) async {
        try {
          await _updateLocationOnRoute();
        } catch (e) {
          print('Error in route update: $e');
        }
      },
    );
  }

  Future<void> _updateLocationOnRoute() async {
    final currentState = state?.value;
    if (currentState == null || !currentState.isOnTrip) {
      _routeUpdateTimer?.cancel();
      return;
    }

    final currentDriver = ref.read(currentDriverNotifierProvider);
    if (currentDriver?.driverId == null ||
        currentState.tripId == null ||
        currentState.currentBusStopId == null ||
        currentState.selectedVehicleId == null) {
      return;
    }

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      final busStop = currentState.busStops.firstWhere(
        (stop) => stop.systemId == currentState.currentBusStopId,
      );

      // Check if approaching bus stop (within 500m)
      final distanceToBusStop = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        busStop.latitude,
        busStop.longitude,
      );
      if (distanceToBusStop < 500 && !_approachingNotified) {
        _approachingNotified = true;
        final totalPassengers = currentState.selectedDestinations
            .fold(0, (sum, d) => sum + d.passengerCount);
        NotificationService().showApproachingBusStop(
          stopName: currentState.currentBusStopId ?? '',
          passengerCount: totalPassengers,
          destination: currentState.selectedDestinations.isNotEmpty
              ? (currentState.selectedDestinations.first.destination ?? '')
              : '',
        );
      }

      // Calculate ETA to the bus stop using OSRM
      final eta = await _mapRepository.calculateEta(
        driverLat: position.latitude,
        driverLng: position.longitude,
        busStopLat: busStop.latitude,
        busStopLng: busStop.longitude,
      );

      final result = await _mapRepository.updateLocation(
        driverId: currentDriver!.driverId!,
        systemId: currentState.currentBusStopId!,
        vehicleId: currentState.selectedVehicleId!,
        tripId: currentState.tripId!,
        busStopLat: busStop.latitude,
        busStopLng: busStop.longitude,
        eta: eta,
      );

      switch (result) {
        case Left(value: final error):
          print('Error updating location: ${error.message}');
          break;
        case Right(value: final data):
          if (data['route'] != null) {
            final updatedRoute = Route.fromJson(data['route']);
            final newState = currentState.copyWith(currentRoute: updatedRoute);
            state = AsyncValue.data(newState);
          }
          break;
      }
    } catch (e) {
      print('Error in location update: $e');
    }
  }

  Future<void> _clearTripState() async {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = null;
    _approachingNotified = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trip_id');

    final currentState = state?.value ?? const MapState();
    final newState = currentState.copyWith(
      currentRoute: null,
      selectedDestinations: [],
      currentBusStopId: null,
      tripId: null,
      isOnTrip: false,
    );

    state = AsyncValue.data(newState);
  }

  void _cancelTimers() {
    _locationUpdateTimer?.cancel();
    _busStopUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
  }
}

@riverpod
List<BusStop> busStops(BusStopsRef ref) {
  final mapState = ref.watch(mapViewModelProvider);
  return mapState?.value?.busStops ?? [];
}

@riverpod
Route? currentRoute(CurrentRouteRef ref) {
  final mapState = ref.watch(mapViewModelProvider);
  return mapState?.value?.currentRoute;
}

@riverpod
bool isOnTrip(IsOnTripRef ref) {
  final mapState = ref.watch(mapViewModelProvider);
  return mapState?.value?.isOnTrip ?? false;
}

@riverpod
List<Destination> selectedDestinations(SelectedDestinationsRef ref) {
  final mapState = ref.watch(mapViewModelProvider);
  return mapState?.value?.selectedDestinations ?? [];
}
