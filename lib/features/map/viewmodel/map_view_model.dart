import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/features/map/model/map_state.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:mobileapp/features/map/repository/driver_location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as flutter_riverpod;
import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'map_view_model.g.dart';

@Riverpod(keepAlive: true)
class MapViewModel extends _$MapViewModel {
  late MapRepository _mapRepository;
  late DriverLocationRepository _driverLocationRepository;

  Timer? _locationUpdateTimer;
  Timer? _busStopUpdateTimer;
  Timer? _routeUpdateTimer;        // Fast polyline + ETA recalc (15s)
  Timer? _serverUpdateTimer;       // Slower server push (30s)
  bool _approachingNotified = false;
  geo.Position? _lastDriverPosition; // Updated by location timer; used by bus stop fetches
  geo.Position? _lastRoutePosition;  // Position when route was last recalculated
  bool _fetchingBusStops = false;   // Prevents concurrent /map/systems requests
  bool _recalculatingRoute = false; // Prevents overlapping OSRM calls
  final Set<int> _cancellingTripIds = {}; // Prevents duplicate /api/cancel_trip/ requests
  final Set<int> _completingTripIds = {}; // Prevents duplicate /api/complete_trip/ requests

  @override
  AsyncValue<MapState>? build() {
    _mapRepository = ref.watch(mapRepositoryProvider);
    _driverLocationRepository = ref.watch(driverLocationRepositoryProvider);

    return const AsyncValue.data(MapState());
  }

  bool _initialized = false;
  bool _initializing = false; // Guards against concurrent initializeMap() calls

  Future<void> initializeMap() async {
    // Skip if already running or done — prevents parallel invocations racing through
    if (_initialized || _initializing) return;
    _initializing = true;

    // Keep existing data state (never block map with loading overlay)
    if (state?.hasValue != true) {
      state = const AsyncValue.data(MapState());
    }

    try {
      final currentDriver = ref.read(currentUserNotifierProvider);
      final driverId = currentDriver?.driverId ?? currentDriver?.id ?? '';

      // Grab last known position instantly (no GPS hardware wait)
      final lastKnown = await geo.Geolocator.getLastKnownPosition();

      // Fire immediate bus stop fetch in background using last known position.
      // This means bus stops appear as soon as the network responds — no 30s wait.
      if (lastKnown != null) {
        fetchBusStops(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
        );
      } else {
        fetchBusStops(); // Will acquire GPS position itself
      }

      // Check Django for active trip (source of truth), fall back to local cache
      final authLocal = ref.read(authLocalRepositoryProvider);
      int? tripId;
      String? busStopId;
      List<Destination> tripDestinations = [];

      if (driverId.isNotEmpty) {
        Map<String, dynamic>? activeTrip;
        try {
          activeTrip = await _mapRepository.getDriverActiveTrip(driverId);
        } catch (_) {
          // Network failed — use cached trip data
          activeTrip = null;
        }

        // Fall back to local cache if server unreachable
        activeTrip ??= authLocal.getCachedActiveTrip();

        if (activeTrip != null) {
          tripId = activeTrip['trip_id'] as int?;
          busStopId = activeTrip['system_id'] as String?;
          final dests = activeTrip['destinations'] as List<dynamic>? ?? [];
          tripDestinations = dests.map((d) => Destination(
            destination: d['destination'] as String?,
            passengerCount: d['passenger_count'] as int? ?? 0,
          )).toList();

          // Cache the trip data locally for future offline restores
          authLocal.cacheActiveTrip(activeTrip);
        } else {
          // No active trip — clear any stale cache
          authLocal.clearCachedActiveTrip();
        }
      }

      var defaultVehicleId = authLocal.getDefaultVehicleId();

      // If no default vehicle set, auto-detect from API
      if (defaultVehicleId == null && driverId.isNotEmpty) {
        try {
          final token = authLocal.getToken('access_token');
          if (token != null) {
            final vehicleResp = await Dio().get(
              '${ServerConstants.authServiceUrl}/vehicles/',
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );
            if (vehicleResp.statusCode == 200) {
              final vehicles = vehicleResp.data is List
                  ? vehicleResp.data as List
                  : ((vehicleResp.data as Map)['vehicles'] ?? []) as List;
              if (vehicles.isNotEmpty) {
                // Auto-select first vehicle as default
                final vid = vehicles[0]['vehicle_id'] ?? vehicles[0]['id'];
                if (vid != null) {
                  defaultVehicleId = vid.toString();
                  await authLocal.setDefaultVehicleId(defaultVehicleId!);
                  print('Auto-selected vehicle as default: $defaultVehicleId');
                }
              }
            }
          }
        } catch (e) {
          print('Vehicle auto-detect failed: $e');
        }
      }

      // Merge trip info into current state (bus stops may already be populated)
      final currentState = state?.value ?? const MapState();
      state = AsyncValue.data(currentState.copyWith(
        tripId: tripId,
        isOnTrip: tripId != null,
        currentBusStopId: busStopId,
        selectedDestinations: tripDestinations.isNotEmpty ? tripDestinations : null,
        selectedVehicleId: defaultVehicleId,
      ));

      _startLocationUpdates();
      _startBusStopUpdates();

      if (tripId != null) {
        _startRouteUpdates();
        // Calculate route immediately (don't wait for first 15s timer tick)
        _recalculateRoute();
      }

      _initialized = true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _initializing = false;
    }
  }

  Future<void> fetchBusStops({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    // Drop duplicate calls — prevents 3 concurrent /map/systems requests after cancel
    if (_fetchingBusStops) return;
    _fetchingBusStops = true;

    const maxRetries = 3;
    var retryCount = 0;

    try {
    while (retryCount < maxRetries) {
      try {
        final currentState = state?.value ?? const MapState();

        if (latitude == null || longitude == null) {
          // Prefer the position already tracked by the location timer (most
          // accurate + no extra GPS wake), then fall back to last-known, then
          // force a fresh fix only as a last resort.
          if (_lastDriverPosition != null) {
            latitude = _lastDriverPosition!.latitude;
            longitude = _lastDriverPosition!.longitude;
          } else {
            final lastKnown = await geo.Geolocator.getLastKnownPosition();
            if (lastKnown != null) {
              latitude = lastKnown.latitude;
              longitude = lastKnown.longitude;
            } else {
              final position = await geo.Geolocator.getCurrentPosition(
                desiredAccuracy: geo.LocationAccuracy.medium,
              );
              latitude = position.latitude;
              longitude = position.longitude;
            }
          }
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
            // Only rebuild the widget tree if stops actually changed —
            // unnecessary rebuilds cancel in-flight OSM tile downloads.
            final unchanged = busStops.length == currentState.busStops.length &&
                busStops.asMap().entries.every((e) {
                  final old = currentState.busStops[e.key];
                  return e.value.systemId == old.systemId &&
                      e.value.totalCount == old.totalCount;
                });
            if (!unchanged) {
              final newState = currentState.copyWith(
                busStops: busStops,
                searchRadius: searchRadius,
              );
              state = AsyncValue.data(newState);
            }
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
        'Could not load bus stops. Please check your internet and try again.',
        StackTrace.current);
    } finally {
      _fetchingBusStops = false;
    }
  }

  Future<void> acceptTrip({
    required BusStop busStop,
    required List<Destination> destinations,
    required String vehicleId,
  }) async {
    try {
      final currentDriver = ref.read(currentUserNotifierProvider);
      if (currentDriver?.driverId == null) {
        state = AsyncValue.error('Please log in to continue.', StackTrace.current);
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
        driverLat: position.latitude,
        driverLng: position.longitude,
      );

      switch (result) {
        case Left(value: final error):
          state = AsyncValue.error(error.message, StackTrace.current);
          break;
        case Right(value: final routeData):
          final route = Route.fromJson(routeData['route']);
          final tripId = routeData['trip_id'] as int;

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

          // Cache trip locally for offline restoration
          final authLocal = ref.read(authLocalRepositoryProvider);
          authLocal.cacheActiveTrip({
            'trip_id': tripId,
            'system_id': busStop.systemId,
            'destinations': destinations.map((d) => {
              'destination': d.destination,
              'passenger_count': d.passengerCount,
            }).toList(),
          });

          // Show trip confirmed notification (non-critical — don't block trip on failure)
          try {
            final totalPassengers =
                destinations.fold(0, (sum, d) => sum + d.passengerCount);
            NotificationService().showTripConfirmed(
              tripId: tripId,
              stopName: busStop.systemId,
              etaMinutes: route.eta,
              passengerCount: totalPassengers,
              destination: destinations.isNotEmpty
                  ? (destinations.first.destination ?? '')
                  : '',
            );
          } catch (_) {
            // Notification failure should never prevent trip acceptance
          }

          _startRouteUpdates();
          break;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> cancelTrip() async {
    final currentState = state?.value;
    final currentDriver = ref.read(currentUserNotifierProvider);
    final driverId = currentDriver?.driverId ?? currentDriver?.id ?? '';
    final tripId = currentState?.tripId;

    if (tripId == null) {
      await _clearTripState();
      return true;
    }

    if (_cancellingTripIds.contains(tripId)) {
      print('Trip $tripId is already being cancelled, skipping duplicate call');
      return false;
    }

    _cancellingTripIds.add(tripId);

    // Step 1: Cancel on Django (source of truth)
    // Django handles everything: deactivate trip → release passengers →
    // broadcast demand update → notify Edge System for announcement
    bool success = false;
    if (driverId.isNotEmpty) {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await dio.post(
            '${ServerConstants.webServerUrl}/api/cancel_trip/',
            data: {
              'trip_id': tripId,
              'driver_id': driverId,
            },
            options: Options(headers: {
              'X-API-KEY': ServerConstants.mapApiKey,
              'Content-Type': 'application/json',
            }),
          );

          if (response.statusCode == 200) {
            print('Trip $tripId cancelled on server: ${response.data}');
            success = true;
            break;
          }
        } catch (e) {
          print('Cancel attempt $attempt/3 for trip $tripId failed: $e');
          if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
        }
      }
    } else {
      // No driver ID but we have a trip ID? Clear it locally anyway
      success = true;
    }

    _cancellingTripIds.remove(tripId);

    // Step 2: Clear local state (only if server succeeded or if we have no driver info)
    if (success) {
      await _clearTripState();
    }
    
    return success;
  }

  Future<bool> arrivedAtDestination() async {
    final currentState = state?.value;
    final currentDriver = ref.read(currentUserNotifierProvider);
    final driverId = currentDriver?.driverId ?? currentDriver?.id ?? '';
    final tripId = currentState?.tripId;

    if (tripId == null) {
      await _clearTripState();
      return true;
    }

    if (_completingTripIds.contains(tripId)) {
      print('Trip $tripId is already being completed, skipping duplicate call');
      return false;
    }

    _completingTripIds.add(tripId);

    // Tell Django the trip is complete
    // Django handles: deactivate trip → calculate earnings → release passengers →
    // broadcast demand update → notify Edge System
    bool success = false;
    if (driverId.isNotEmpty) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
        final response = await dio.post(
          '${ServerConstants.webServerUrl}/complete_trip/',
          data: {
            'trip_id': tripId,
            'system_id': currentState?.currentBusStopId ?? '',
            'driver_id': driverId,
          },
          options: Options(headers: {
            'X-API-KEY': ServerConstants.mapApiKey,
            'Content-Type': 'application/json',
          }),
        );
        if (response.statusCode == 200) {
          print('Trip $tripId completed on server');
          success = true;
        }
      } catch (e) {
        print('Complete trip $tripId failed, falling back to cancel: $e');
        // Fallback: at minimum, cancel the trip so passengers are released
        success = await cancelTrip();
      }
    } else {
      success = true;
    }

    _completingTripIds.remove(tripId);

    if (success) {
      await _clearTripState();
    }
    
    return success;
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

  String _lastGeocodedAddress = 'Unknown';
  double _lastGeocodedLat = 0;
  double _lastGeocodedLng = 0;

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 30), // Every 30s, not 10s — reduces network load
      (timer) async {
        try {
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.medium,
          );

          // Keep a fresh position so fetchBusStops() doesn't use stale cache
          _lastDriverPosition = position;

          // Only reverse geocode if moved >100m (avoid spamming Nominatim)
          final distance = geo.Geolocator.distanceBetween(
            _lastGeocodedLat, _lastGeocodedLng,
            position.latitude, position.longitude,
          );

          if (distance > 100 || _lastGeocodedAddress == 'Unknown') {
            final addressResult = await _mapRepository.fetchReverseGeocoding(
              latitude: position.latitude,
              longitude: position.longitude,
            );
            switch (addressResult) {
              case Right(value: final data):
                _lastGeocodedAddress = data['place_name']?.toString() ?? 'Unknown';
                _lastGeocodedLat = position.latitude;
                _lastGeocodedLng = position.longitude;
                break;
              case Left():
                break;
            }
          }

          // Update driver location on the auth service
          await _driverLocationRepository.updateDriverLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            address: _lastGeocodedAddress,
          );

          // Task: Automatic Arrival Detection
          // If on a trip, check distance to destination (last point in route)
          final currentState = state?.value;
          if (currentState != null && currentState.isOnTrip && currentState.currentRoute != null) {
            final routeCoords = currentState.currentRoute!.coordinates;
            if (routeCoords.isNotEmpty) {
              final destCoord = routeCoords.last; // [lng, lat] from GeoJSON
              final destLat = destCoord[1];
              final destLng = destCoord[0];

              final distanceToDest = geo.Geolocator.distanceBetween(
                position.latitude, position.longitude,
                destLat, destLng,
              );

              // 200m radius for "Arrived" verification
              final isNear = distanceToDest < 200;
              if (isNear != currentState.isNearDestination) {
                state = AsyncValue.data(currentState.copyWith(isNearDestination: isNear));
                if (isNear) {
                  print("Driver arrived at destination: ${currentState.currentRoute!.destination}");
                }
              }
            }
          }
        } catch (e) {
          // Non-critical — app works without location updates
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
    _serverUpdateTimer?.cancel();

    // Fast polyline + ETA recalculation every 15 seconds
    // Only hits OSRM if driver moved >50m since last recalc
    _routeUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) async {
        try {
          await _recalculateRoute();
        } catch (e) {
          print('Error in route recalculation: $e');
        }
      },
    );

    // Server location push every 30 seconds (notifies Django + Edge System)
    _serverUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          await _pushLocationToServer();
        } catch (e) {
          print('Error in server location push: $e');
        }
      },
    );
  }

  /// Recalculate route polyline + ETA from OSRM (runs every 15s, skips if not moved)
  Future<void> _recalculateRoute() async {
    final currentState = state?.value;
    if (currentState == null || !currentState.isOnTrip) {
      _routeUpdateTimer?.cancel();
      _serverUpdateTimer?.cancel();
      return;
    }

    if (_recalculatingRoute) return; // Previous OSRM call still in-flight
    _recalculatingRoute = true;

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _lastDriverPosition = position;

      // Skip OSRM call if driver hasn't moved >50m since last recalc
      if (_lastRoutePosition != null) {
        final moved = geo.Geolocator.distanceBetween(
          _lastRoutePosition!.latitude, _lastRoutePosition!.longitude,
          position.latitude, position.longitude,
        );
        if (moved < 50) return; // Hasn't moved enough — skip
      }

      final busStop = currentState.busStops.cast<BusStop?>().firstWhere(
        (stop) => stop?.systemId == currentState.currentBusStopId,
        orElse: () => null,
      );
      if (busStop == null) return;

      // Calculate live distance
      final distanceToBusStop = geo.Geolocator.distanceBetween(
        position.latitude, position.longitude,
        busStop.latitude, busStop.longitude,
      );
      final distanceKm = distanceToBusStop / 1000;

      // Approaching notification
      if (distanceToBusStop < 500 && !_approachingNotified) {
        _approachingNotified = true;
        try {
          final totalPassengers = currentState.selectedDestinations
              .fold(0, (sum, d) => sum + d.passengerCount);
          NotificationService().showApproachingBusStop(
            stopName: currentState.currentBusStopId ?? '',
            passengerCount: totalPassengers,
            destination: currentState.selectedDestinations.isNotEmpty
                ? (currentState.selectedDestinations.first.destination ?? '')
                : '',
          );
        } catch (_) {
          // Non-critical — don't crash route update on notification failure
        }
      }

      // Fetch live route from OSRM (polyline + ETA)
      double etaMinutes;
      List<List<double>>? liveCoordinates;
      try {
        final osrmResponse = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        )).get(
          'https://router.project-osrm.org/route/v1/driving/'
          '${position.longitude},${position.latitude};'
          '${busStop.longitude},${busStop.latitude}',
          queryParameters: {
            'overview': 'full',
            'geometries': 'geojson',
          },
        );
        if (osrmResponse.statusCode == 200 &&
            osrmResponse.data['routes'] != null &&
            (osrmResponse.data['routes'] as List).isNotEmpty) {
          final osrmRoute = osrmResponse.data['routes'][0];
          final durationSeconds = osrmRoute['duration']?.toDouble() ?? 0.0;
          etaMinutes = durationSeconds / 60.0;
          final geometry = osrmRoute['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            liveCoordinates = (geometry['coordinates'] as List)
                .map((c) => List<double>.from(c))
                .toList();
          }
        } else {
          // Fallback: assume ~30 km/h avg city driving speed
          etaMinutes = (distanceKm / 30) * 60;
        }
      } catch (_) {
        etaMinutes = (distanceKm / 30) * 60;
      }

      _lastRoutePosition = position;

      // Update UI with live route
      if (currentState.currentRoute != null) {
        final liveRoute = Route(
          coordinates: liveCoordinates ?? currentState.currentRoute!.coordinates,
          destination: currentState.currentRoute!.destination,
          distance: distanceKm,
          eta: etaMinutes,
        );
        state = AsyncValue.data(currentState.copyWith(currentRoute: liveRoute));
      }
    } finally {
      _recalculatingRoute = false;
    }
  }

  /// Push driver location + ETA to server (runs every 30s, notifies Django + Edge System)
  Future<void> _pushLocationToServer() async {
    final currentState = state?.value;
    if (currentState == null || !currentState.isOnTrip) return;

    final currentDriver = ref.read(currentUserNotifierProvider);
    if (currentDriver?.driverId == null ||
        currentState.tripId == null ||
        currentState.currentBusStopId == null ||
        currentState.selectedVehicleId == null) {
      return;
    }

    final busStop = currentState.busStops.cast<BusStop?>().firstWhere(
      (stop) => stop?.systemId == currentState.currentBusStopId,
      orElse: () => null,
    );
    if (busStop == null) return;

    // Use the latest ETA from the route (already in minutes)
    final etaMinutes = currentState.currentRoute?.eta;

    try {
      await _mapRepository.updateLocation(
        driverId: currentDriver!.driverId!,
        systemId: currentState.currentBusStopId!,
        vehicleId: currentState.selectedVehicleId!,
        tripId: currentState.tripId!,
        busStopLat: busStop.latitude,
        busStopLng: busStop.longitude,
        eta: etaMinutes,
      );
    } catch (e) {
      print('Error pushing location to server: $e');
    }
  }

  Future<void> _clearTripState() async {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = null;
    _serverUpdateTimer?.cancel();
    _serverUpdateTimer = null;
    _approachingNotified = false;
    _lastRoutePosition = null;

    // Clear cached trip so it won't restore after completion/cancellation
    final authLocal = ref.read(authLocalRepositoryProvider);
    authLocal.clearCachedActiveTrip();

    final currentState = state?.value ?? const MapState();
    // Create fresh state — copyWith can't clear nullable fields
    final newState = MapState(
      busStops: currentState.busStops,
      searchRadius: currentState.searchRadius,
      selectedVehicleId: currentState.selectedVehicleId,
      isOnTrip: false,
      isNearDestination: false,
      // currentRoute, tripId, currentBusStopId, selectedDestinations = defaults (null/empty)
    );

    state = AsyncValue.data(newState);
  }

  void _cancelTimers() {
    _locationUpdateTimer?.cancel();
    _busStopUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _serverUpdateTimer?.cancel();
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

/// Focus request from Demand page → Map page.
/// Set systemId to focus the map on that bus stop and auto-select it.
class FocusBusStopRequest {
  final String systemId;
  final double latitude;
  final double longitude;
  FocusBusStopRequest({required this.systemId, required this.latitude, required this.longitude});
}

final pendingFocusBusStopProvider = flutter_riverpod.StateProvider<FocusBusStopRequest?>((ref) => null);
