import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/core/services/sse_client.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/features/driver/repository/demand_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';

part 'demand_viewmodel.g.dart';

@riverpod
class DemandViewmodel extends _$DemandViewmodel {
  SSEClient? _sseClient;

  @override
  DemandState build() {
    return const DemandState.initial();
  }

  void setupSSE() {
    _sseClient?.dispose();
    final sseUrl = '${ServerConstants.microserviceUrl}stream/updates';
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

  Future<void> loadDemand({double radius = 10.0}) async {
    state = const DemandState.loading();

    try {
      final driver = ref.read(currentDriverNotifierProvider);
      if (driver == null) {
        state = const DemandState.error('Driver not logged in');
        return;
      }

      // Use default location for now (Legon, Accra)
      // TODO: Get real-time driver location from GPS
      const latitude = 5.6037;
      const longitude = -0.1870;

      final demandRepo = ref.read(demandRepositoryProvider);
      final result = await demandRepo.getDemandBroadcast(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      result.fold(
        (failure) => state = DemandState.error(failure.message),
        (demand) => state = DemandState.loaded(demand),
      );
    } catch (e) {
      state = DemandState.error('Failed to load demand: $e');
    }
  }

  Future<void> refresh() async {
    await loadDemand();
  }

  void disposeSSE() {
    _sseClient?.dispose();
    _sseClient = null;
  }
}

class DemandState {
  final bool isLoading;
  final DemandData? demand;
  final String? error;

  const DemandState._({
    required this.isLoading,
    this.demand,
    this.error,
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
    DemandData? demand,
    String? error,
  }) {
    return DemandState._(
      isLoading: isLoading ?? this.isLoading,
      demand: demand ?? this.demand,
      error: error ?? this.error,
    );
  }
}
