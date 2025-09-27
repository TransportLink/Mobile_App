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

String _$getAllVehiclesHash() => r'24d44ee39ac9ad4e196538fce9ae8b062ae0eb05';

@ProviderFor(VehicleViewModel)
const vehicleViewModelProvider = VehicleViewModelProvider._();

final class VehicleViewModelProvider
    extends $NotifierProvider<VehicleViewModel, AsyncValue<VehicleModel?>?> {
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
  Override overrideWithValue(AsyncValue<VehicleModel?>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<VehicleModel?>?>(value),
    );
  }
}

String _$vehicleViewModelHash() => r'c1f22339653490efe51aee05e6ac5da64f2fe3f0';

abstract class _$VehicleViewModel
    extends $Notifier<AsyncValue<VehicleModel?>?> {
  AsyncValue<VehicleModel?>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref
        as $Ref<AsyncValue<VehicleModel?>?, AsyncValue<VehicleModel?>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<VehicleModel?>?, AsyncValue<VehicleModel?>?>,
        AsyncValue<VehicleModel?>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
