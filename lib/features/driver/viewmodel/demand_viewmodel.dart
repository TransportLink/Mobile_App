import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/core/services/sse_client.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/features/driver/repository/demand_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';

part 'demand_viewmodel.g.dart';

@riverpod
class DemandViewmodel extends _$DemandViewmodel {
  SSEClient? _sseClient;
  Timer? _refreshTimer;

  @override
  DemandState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _sseClient?.dispose();
    });
    return const DemandState.initial();
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => loadDemand(silent: true));
  }

  void setupSSE() {
    _sseClient?.dispose();
    final sseUrl = '${ServerConstants.mapServiceUrl}stream/updates';
    _sseClient = SSEClient(url: sseUrl);

    _sseClient!.onEvent = (type, data) {
      _handleSSEEvent(type, data);
    };

    _sseClient!.onError = (error) {
      // Silently handle SSE errors - don't disrupt UI
    };

    _sseClient!.connect();
  }

  void _handleSSEEvent(String type, dynamic data) {
    if (data is! Map<String, dynamic>) return;

    switch (type) {
      case 'demand_update':
        if (state.demand != null) {
          final systemId = data['system_id'];
          final destination = data['destination'];
          final newCount = data['count'];

          final updatedStops = state.demand!.busStops.map((stop) {
            if (stop.systemId == systemId &&
                stop.demand.containsKey(destination)) {
              final oldCount = stop.demand[destination]?.passengers ?? 0;
              final updatedDemand =
                  Map<String, DestinationDemand>.from(stop.demand);
              updatedDemand[destination] = DestinationDemand(
                passengers: newCount,
                estimatedRevenue:
                    updatedDemand[destination]?.estimatedRevenue ?? 0,
              );

              // Notify high demand
              final totalDemand =
                  updatedDemand.values.fold(0, (a, b) => a + b.passengers);
              if (totalDemand >= 5) {
                final demandMap = <String, int>{};
                for (final e in updatedDemand.entries) {
                  demandMap[e.key] = e.value.passengers;
                }
                NotificationService().showHighDemandAlert(
                  systemId: systemId ?? '',
                  stopName: stop.location ?? systemId ?? '',
                  demand: demandMap,
                  driversEnRoute: stop.driversEnRoute ?? 0,
                  etaMinutes: stop.etaMinutes ?? 0,
                );
              }

              // Notify demand change during trip
              if (oldCount != newCount) {
                NotificationService().showDemandChangedDuringTrip(
                  stopName: stop.location ?? systemId ?? '',
                  destination: destination ?? '',
                  oldCount: oldCount,
                  newCount: newCount,
                );
              }

              return BusStopOpportunity(
                systemId: stop.systemId,
                location: stop.location,
                coordinates: stop.coordinates,
                distanceKm: stop.distanceKm,
                etaMinutes: stop.etaMinutes,
                demand: updatedDemand,
                totalPassengers: stop.totalPassengers,
                driversEnRoute: stop.driversEnRoute,
                revenueScore: stop.revenueScore,
                demandLevel: stop.demandLevel,
                destinations: stop.destinations,
                estimatedRevenue: stop.estimatedRevenue,
              );
            }
            return stop;
          }).toList();

          state = state.copyWith(
            demand: DemandData(
              driverLocation: state.demand!.driverLocation,
              searchRadiusKm: state.demand!.searchRadiusKm,
              timestamp: DateTime.now().toIso8601String(),
              summary: state.demand!.summary,
              busStops: updatedStops,
            ),
          );
        }
        break;

      case 'trip_cancelled':
        NotificationService().showTripCancelledAlert(
          tripId: data['trip_id'] ?? 0,
          stopName: data['stop_name'] ?? 'Bus stop',
          reason: data['reason'] ?? 'left before arrival',
        );
        loadDemand();
        break;

      case 'systemStatus':
        if (data['is_online'] == false) {
          NotificationService().showSystemOfflineAlert(
            systemId: data['system_id'] ?? '',
            stopName: data['stop_name'] ?? data['system_id'] ?? '',
            minutesSinceLastUpdate: data['minutes_since_heartbeat'] ?? 0,
          );
        }
        break;

      case 'trip_started':
      case 'trip_completed':
        loadDemand();
        break;

      case 'system_status':
        break;
    }
  }

  /// [silent] = true keeps existing data visible while refreshing in background.
  Future<void> loadDemand({double radius = 10.0, bool silent = false}) async {
    final driver = ref.read(currentUserNotifierProvider);
    if (driver == null) {
      state = const DemandState.error('Please log in to view demand.');
      return;
    }

    // Show spinner only on first load; keep old data visible on refresh
    if (!silent && state.demand == null) {
      state = const DemandState.loading();
    } else if (!silent) {
      state = state.copyWith(isRefreshing: true);
    }

    try {
      // Use last known GPS position (instant), fall back to Accra centre
      double latitude = 5.6037;
      double longitude = -0.1870;
      try {
        final pos = await geo.Geolocator.getLastKnownPosition() ??
            await geo.Geolocator.getCurrentPosition(
              desiredAccuracy: geo.LocationAccuracy.medium,
            );
        latitude = pos.latitude;
        longitude = pos.longitude;
      } catch (_) {}

      final demandRepo = ref.read(demandRepositoryProvider);
      final result = await demandRepo.getDemandBroadcast(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      result.fold(
        (failure) {
          // On silent refresh failure keep existing data — just clear spinner
          if (state.demand != null) {
            state = state.copyWith(isRefreshing: false, lastError: failure.message);
          } else {
            state = DemandState.error(failure.message);
          }
        },
        (demand) => state = DemandState.loaded(demand),
      );
    } catch (e) {
      if (state.demand != null) {
        state = state.copyWith(isRefreshing: false);
      } else {
        state = const DemandState.error('Could not load demand data. Please try again.');
      }
    }
  }

  Future<void> refresh() async => loadDemand();

  void disposeSSE() {
    _sseClient?.dispose();
    _sseClient = null;
  }
}

class DemandState {
  final bool isLoading;
  final bool isRefreshing;
  final DemandData? demand;
  final String? error;
  final String? lastError; // non-fatal error during silent refresh

  const DemandState._({
    required this.isLoading,
    this.isRefreshing = false,
    this.demand,
    this.error,
    this.lastError,
  });

  const DemandState.initial()
      : this._(isLoading: false, demand: null, error: null);

  const DemandState.loading()
      : this._(isLoading: true, demand: null, error: null);

  const DemandState.loaded(DemandData? demand)
      : this._(isLoading: false, demand: demand, error: null);

  const DemandState.error(String? error)
      : this._(isLoading: false, demand: null, error: error);

  DemandState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    DemandData? demand,
    String? error,
    String? lastError,
  }) {
    return DemandState._(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      demand: demand ?? this.demand,
      error: error ?? this.error,
      lastError: lastError ?? this.lastError,
    );
  }
}
