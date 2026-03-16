import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/features/driver/repository/demand_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobileapp/core/providers/current_driver_notifier_provider.dart';

part 'demand_viewmodel.g.dart';

@riverpod
class DemandViewmodel extends _$DemandViewmodel {
  @override
  DemandState build() {
    return const DemandState.initial();
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
