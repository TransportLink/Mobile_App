import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/core/services/sse_client.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/features/driver/repository/demand_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobileapp/core/providers/current_driver_notifier_provider.dart';

part 'demand_viewmodel.g.dart';

@riverpod
class DemandViewmodel extends _$DemandViewmodel {
  SSEClient? _sseClient;

  @override
  DemandState build() {
    // Initialize SSE connection on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSSE();
    });
    return const DemandState.initial();
  }

  void _setupSSE() {
    final sseUrl = '${ServerConstants.microserviceUrl}stream/updates';
    _sseClient = SSEClient(url: sseUrl);
    
    _sseClient!.onEvent = (type, data) {
      _handleSSEEvent(type, data);
    };
    
    _sseClient!.onError = (error) {
      // Silently handle SSE errors - don't disrupt UI
      // The demand data is still valid from last poll
    };
    
    _sseClient!.connect();
  }

  void _handleSSEEvent(String type, dynamic data) {
    switch (type) {
      case SSEEventType.demandUpdate:
        // Refresh demand data when passenger count changes
        final systemId = data['system_id'];
        final destination = data['destination'];
        final newCount = data['count'];
        
        // Update local state if we have data
        if (state.demand != null) {
          final updatedStops = state.demand!.busStops.map((stop) {
            if (stop.systemId == systemId && stop.demand.containsKey(destination)) {
              // Create updated stop with new passenger count
              final updatedDemand = Map<String, DestinationDemand>.from(stop.demand);
              updatedDemand[destination] = DestinationDemand(
                passengers: newCount,
                estimatedRevenue: updatedDemand[destination].estimatedRevenue,
              );
              
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
        
      case SSEEventType.tripStarted:
      case SSEEventType.tripCompleted:
        // Refresh demand data on trip events
        loadDemand();
        break;
        
      case SSEEventType.systemStatus:
        // Handle system status changes if needed
        break;
    }
  }

  /// Load demand data from API
  Future<void> loadDemand({double radius = 10.0}) async {
    state = const DemandState.loading();

    try {
      final driver = ref.read(currentDriverNotifierProvider);
      if (driver == null) {
        state = const DemandState.error('Driver not logged in');
        return;
      }

      // For now, use driver's last known location or default to Legon
      // TODO: Get real-time driver location from location service
      final latitude = driver.latitude ?? 5.6037;
      final longitude = driver.longitude ?? -0.1870;

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

  /// Refresh demand data
  Future<void> refresh() async {
    await loadDemand();
  }

  @override
  void dispose() {
    _sseClient?.dispose();
    super.dispose();
  }
}

/// Demand view state
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

  const DemandState.loaded(this.demand)
      : this._(isLoading: false, demand: demand, error: null);

  const DemandState.error(this.error)
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
