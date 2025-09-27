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
    extends $NotifierProvider<MapViewModel, AsyncValue<DriverModel>?> {
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
  Override overrideWithValue(AsyncValue<DriverModel>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DriverModel>?>(value),
    );
  }
}

String _$mapViewModelHash() => r'2b8e85586355c968df78c95399ff9383f600335b';

abstract class _$MapViewModel extends $Notifier<AsyncValue<DriverModel>?> {
  AsyncValue<DriverModel>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<DriverModel>?, AsyncValue<DriverModel>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DriverModel>?, AsyncValue<DriverModel>?>,
        AsyncValue<DriverModel>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
