// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$busStopsHash() => r'251a4f320a4044e94c978744bed2bc09d92614f9';

/// See also [busStops].
@ProviderFor(busStops)
final busStopsProvider = AutoDisposeProvider<List<BusStop>>.internal(
  busStops,
  name: r'busStopsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$busStopsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BusStopsRef = AutoDisposeProviderRef<List<BusStop>>;
String _$currentRouteHash() => r'8654734c2572a835a13c798c7ce1240fea7ab0a1';

/// See also [currentRoute].
@ProviderFor(currentRoute)
final currentRouteProvider = AutoDisposeProvider<Route?>.internal(
  currentRoute,
  name: r'currentRouteProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentRouteHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentRouteRef = AutoDisposeProviderRef<Route?>;
String _$isOnTripHash() => r'185116ba519fc1224f5a650bae99f8765db9acc9';

/// See also [isOnTrip].
@ProviderFor(isOnTrip)
final isOnTripProvider = AutoDisposeProvider<bool>.internal(
  isOnTrip,
  name: r'isOnTripProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isOnTripHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IsOnTripRef = AutoDisposeProviderRef<bool>;
String _$selectedDestinationsHash() =>
    r'9702c065916afd5ccba39fbf02d2931ee96fecd2';

/// See also [selectedDestinations].
@ProviderFor(selectedDestinations)
final selectedDestinationsProvider =
    AutoDisposeProvider<List<Destination>>.internal(
  selectedDestinations,
  name: r'selectedDestinationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedDestinationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SelectedDestinationsRef = AutoDisposeProviderRef<List<Destination>>;
String _$mapViewModelHash() => r'79c4a22f7f303ece386830f07551f22c20761b76';

/// See also [MapViewModel].
@ProviderFor(MapViewModel)
final mapViewModelProvider =
    NotifierProvider<MapViewModel, AsyncValue<MapState>?>.internal(
  MapViewModel.new,
  name: r'mapViewModelProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mapViewModelHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MapViewModel = Notifier<AsyncValue<MapState>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
