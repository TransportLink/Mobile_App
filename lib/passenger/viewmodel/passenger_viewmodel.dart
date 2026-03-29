import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/passenger_state.dart';
import '../repository/passenger_repository.dart';
import '../services/geofence_service.dart';

/// Passenger Check-In Viewmodel State
class PassengerState {
  final bool isLoading;
  final bool isCheckedIn;
  final PassengerCheckInState? checkInState;
  final String? error;
  final String? selectedDestination;
  final int passengerCount;

  PassengerState({
    this.isLoading = false,
    this.isCheckedIn = false,
    this.checkInState,
    this.error,
    this.selectedDestination,
    this.passengerCount = 1,
  });

  PassengerState copyWith({
    bool? isLoading,
    bool? isCheckedIn,
    PassengerCheckInState? checkInState,
    String? error,
    String? selectedDestination,
    int? passengerCount,
  }) {
    return PassengerState(
      isLoading: isLoading ?? this.isLoading,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkInState: checkInState ?? this.checkInState,
      error: error ?? this.error,
      selectedDestination: selectedDestination ?? this.selectedDestination,
      passengerCount: passengerCount ?? this.passengerCount,
    );
  }
}

/// Passenger Check-In Notifier
class PassengerNotifier extends StateNotifier<PassengerState> {
  PassengerNotifier() : super(PassengerState());

  /// Set selected destination and clear any error
  void selectDestination(String destination) {
    state = PassengerState(
      isLoading: state.isLoading,
      isCheckedIn: state.isCheckedIn,
      checkInState: state.checkInState,
      error: null,
      selectedDestination: destination,
      passengerCount: state.passengerCount,
    );
  }

  /// Set passenger count (for groups) and clear any error
  void setPassengerCount(int count) {
    state = PassengerState(
      isLoading: state.isLoading,
      isCheckedIn: state.isCheckedIn,
      checkInState: state.checkInState,
      error: null,
      selectedDestination: state.selectedDestination,
      passengerCount: count,
    );
  }

  /// Check in at a bus stop
  Future<bool> checkIn({
    required String systemId,
    required String destination,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await passengerRepository.checkIn(
      systemId: systemId,
      destination: destination,
      passengerCount: state.passengerCount,
      latitude: latitude,
      longitude: longitude,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        isCheckedIn: true,
        checkInState: result.data,
        error: null,
        selectedDestination: null,
      );

      await geofenceService.saveCheckInState(systemId);

      // Start exit monitoring — auto-checkout when passenger walks >150m away
      if (latitude != null && longitude != null) {
        geofenceService.onAutoCheckout = (_) => checkOut(reason: 'auto_exit');
        await geofenceService.startExitMonitoring(
          systemId: systemId,
          stopLat: latitude,
          stopLng: longitude,
        );
      }

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.error,
      );
      return false;
    }
  }

  /// Check out from a bus stop
  Future<bool> checkOut({String reason = 'manual'}) async {
    // Stop exit monitoring immediately (prevent double-trigger)
    await geofenceService.stopExitMonitoring();

    state = state.copyWith(isLoading: true, error: null);

    final result = await passengerRepository.checkOut(reason: reason);

    if (result.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        isCheckedIn: false,
        checkInState: null,
        error: null,
      );

      // Clear check-in state
      await geofenceService.clearCheckInState();

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.error,
      );
      return false;
    }
  }

  /// Refresh check-in state from server.
  /// Also handles stale check-ins (>2 hours old) by auto-checking out.
  Future<void> refreshCheckIn() async {
    // Check for stale local check-in first
    final staleStopId = await geofenceService.checkForStaleCheckIn();
    if (staleStopId != null) {
      // Force checkout of stale check-in
      await passengerRepository.checkOut(reason: 'app_restart');
      await geofenceService.clearCheckInState();
      state = state.copyWith(isCheckedIn: false, checkInState: null, error: null);
      return;
    }

    final result = await passengerRepository.getMyCheckIn();

    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        isCheckedIn: true,
        checkInState: result.data,
        error: null,
      );
    } else if (result.isSuccess) {
      // No active check-in on server — clear local state
      await geofenceService.clearCheckInState();
      state = state.copyWith(
        isCheckedIn: false,
        checkInState: null,
        error: null,
      );
    } else {
      // Don't show auth/network errors from refreshCheckIn — it's a background check
      // The user can still check in manually even if this fails
      await geofenceService.clearCheckInState();
      state = state.copyWith(
        isCheckedIn: false,
        checkInState: null,
        error: null,
      );
    }
  }

  /// Clear error
  void clearError() {
    state = PassengerState(
      isLoading: state.isLoading,
      isCheckedIn: state.isCheckedIn,
      checkInState: state.checkInState,
      error: null,
      selectedDestination: state.selectedDestination,
      passengerCount: state.passengerCount,
    );
  }

  /// Update queue position from SSE update
  void updateQueuePosition(int queuePosition, int totalWaiting) {
    if (state.checkInState != null) {
      state = state.copyWith(
        checkInState: state.checkInState!.copyWith(
          queuePosition: queuePosition,
          totalWaiting: totalWaiting,
        ),
      );
    }
  }

  /// Update incoming drivers from SSE or periodic refresh
  void updateIncomingDrivers(List<IncomingDriver> drivers) {
    if (state.checkInState != null) {
      state = state.copyWith(
        checkInState: state.checkInState!.copyWith(
          incomingDrivers: drivers,
        ),
      );
    }
  }
}

/// Riverpod provider for passenger state
final passengerNotifierProvider =
    StateNotifierProvider<PassengerNotifier, PassengerState>((ref) {
  return PassengerNotifier();
});

/// Provider for current bus stop demand (refreshed via SSE)
final busStopDemandProvider =
    FutureProvider.autoDispose.family<dynamic, String>((ref, systemId) async {
  final result = await passengerRepository.getStopInfo(systemId: systemId);
  if (result.isSuccess) {
    return result.data;
  } else {
    throw Exception(result.error ?? 'Unknown error');
  }
});

/// Provider for active drivers (for tracking map)
final activeDriversProvider =
    FutureProvider.autoDispose.family<dynamic, Map<String, String?>>(
  (ref, params) async {
    final result = await passengerRepository.getActiveDrivers(
      systemId: params['systemId'],
      destination: params['destination'],
    );
    if (result.isSuccess) {
      return result.data;
    } else {
      throw Exception(result.error ?? 'Unknown error');
    }
  },
);
