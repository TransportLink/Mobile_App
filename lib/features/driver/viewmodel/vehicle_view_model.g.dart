// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getAllVehicles)
const getAllVehiclesProvider = GetAllVehiclesProvider._();

final class GetAllVehiclesProvider extends $FunctionalProvider<
        AsyncValue<List<VehicleModel>>,
        List<VehicleModel>,
        FutureOr<List<VehicleModel>>>
    with
        $FutureModifier<List<VehicleModel>>,
        $FutureProvider<List<VehicleModel>> {
  const GetAllVehiclesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getAllVehiclesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getAllVehiclesHash();

  @$internal
  @override
  $FutureProviderElement<List<VehicleModel>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<VehicleModel>> create(Ref ref) {
    return getAllVehicles(ref);
  }
}

String _$getAllVehiclesHash() => r'91802851cc0b24b1058d308555643c15c7594a67';

@ProviderFor(VehicleViewModel)
const vehicleViewModelProvider = VehicleViewModelProvider._();

final class VehicleViewModelProvider
    extends $NotifierProvider<VehicleViewModel, AsyncValue<dynamic>?> {
  const VehicleViewModelProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vehicleViewModelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vehicleViewModelHash();

  @$internal
  @override
  VehicleViewModel create() => VehicleViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<dynamic>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<dynamic>?>(value),
    );
  }
}

String _$vehicleViewModelHash() => r'6fbff724c2d72dae0655b29fb0e3787a45b5144d';

abstract class _$VehicleViewModel extends $Notifier<AsyncValue<dynamic>?> {
  AsyncValue<dynamic>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<dynamic>?, AsyncValue<dynamic>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<dynamic>?, AsyncValue<dynamic>?>,
        AsyncValue<dynamic>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
