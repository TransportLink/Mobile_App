import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart';

class MapState {
  final List<BusStop> busStops;
  final Route? currentRoute;
  final List<Destination> selectedDestinations;
  final String? currentBusStopId;
  final String? selectedVehicleId;
  final int? tripId;
  final double searchRadius;
  final bool isOnTrip;

  const MapState({
    this.busStops = const [],
    this.currentRoute,
    this.selectedDestinations = const [],
    this.currentBusStopId,
    this.selectedVehicleId,
    this.tripId,
    this.searchRadius = 5.0,
    this.isOnTrip = false,
  });

  MapState copyWith({
    List<BusStop>? busStops,
    Route? currentRoute,
    List<Destination>? selectedDestinations,
    String? currentBusStopId,
    String? selectedVehicleId,
    int? tripId,
    double? searchRadius,
    bool? isOnTrip,
  }) {
    return MapState(
      busStops: busStops ?? this.busStops,
      currentRoute: currentRoute ?? this.currentRoute,
      selectedDestinations: selectedDestinations ?? this.selectedDestinations,
      currentBusStopId: currentBusStopId ?? this.currentBusStopId,
      selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
      tripId: tripId ?? this.tripId,
      searchRadius: searchRadius ?? this.searchRadius,
      isOnTrip: isOnTrip ?? this.isOnTrip,
    );
  }

  @override
  String toString() {
    return 'MapState(busStops: ${busStops.length}, hasRoute: ${currentRoute != null}, '
           'destinations: ${selectedDestinations.length}, tripId: $tripId, isOnTrip: $isOnTrip)';
  }
}