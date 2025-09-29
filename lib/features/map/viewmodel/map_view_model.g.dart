// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MapViewModel)
const mapViewModelProvider = MapViewModelProvider._();

final class MapViewModelProvider
    extends $NotifierProvider<MapViewModel, AsyncValue<MapState>?> {
  const MapViewModelProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'mapViewModelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$mapViewModelHash();

  @$internal
  @override
  MapViewModel create() => MapViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<MapState>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<MapState>?>(value),
    );
  }
}

String _$mapViewModelHash() => r'bb1d8122554b4192a9a4f5bbd3c5b5562efa94f4';

abstract class _$MapViewModel extends $Notifier<AsyncValue<MapState>?> {
  AsyncValue<MapState>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<MapState>?, AsyncValue<MapState>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<MapState>?, AsyncValue<MapState>?>,
        AsyncValue<MapState>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(busStops)
const busStopsProvider = BusStopsProvider._();

final class BusStopsProvider
    extends $FunctionalProvider<List<BusStop>, List<BusStop>, List<BusStop>>
    with $Provider<List<BusStop>> {
  const BusStopsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'busStopsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$busStopsHash();

  @$internal
  @override
  $ProviderElement<List<BusStop>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<BusStop> create(Ref ref) {
    return busStops(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<BusStop> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<BusStop>>(value),
    );
  }
}

String _$busStopsHash() => r'0cb76efa8323a516d7ae2af462ab89b084ffc454';

@ProviderFor(currentRoute)
const currentRouteProvider = CurrentRouteProvider._();

final class CurrentRouteProvider
    extends $FunctionalProvider<Route?, Route?, Route?> with $Provider<Route?> {
  const CurrentRouteProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentRouteProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentRouteHash();

  @$internal
  @override
  $ProviderElement<Route?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Route? create(Ref ref) {
    return currentRoute(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Route? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Route?>(value),
    );
  }
}

String _$currentRouteHash() => r'5dd6ba4dc09cc918bddd5ca0b0b745cdc03c0d87';

@ProviderFor(isOnTrip)
const isOnTripProvider = IsOnTripProvider._();

final class IsOnTripProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsOnTripProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isOnTripProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isOnTripHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isOnTrip(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isOnTripHash() => r'542473107dcf5469f69c1220457af5de86691956';

@ProviderFor(selectedDestinations)
const selectedDestinationsProvider = SelectedDestinationsProvider._();

final class SelectedDestinationsProvider extends $FunctionalProvider<
    List<Destination>,
    List<Destination>,
    List<Destination>> with $Provider<List<Destination>> {
  const SelectedDestinationsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'selectedDestinationsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$selectedDestinationsHash();

  @$internal
  @override
  $ProviderElement<List<Destination>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Destination> create(Ref ref) {
    return selectedDestinations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Destination> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Destination>>(value),
    );
  }
}

String _$selectedDestinationsHash() =>
    r'62f18848ae0a102a96d6516e90a144f9a0a9b200';
