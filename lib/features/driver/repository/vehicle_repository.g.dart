// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vehicleRepository)
const vehicleRepositoryProvider = VehicleRepositoryProvider._();

final class VehicleRepositoryProvider extends $FunctionalProvider<
    VehicleRepository,
    VehicleRepository,
    VehicleRepository> with $Provider<VehicleRepository> {
  const VehicleRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vehicleRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vehicleRepositoryHash();

  @$internal
  @override
  $ProviderElement<VehicleRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VehicleRepository create(Ref ref) {
    return vehicleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehicleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehicleRepository>(value),
    );
  }
}

String _$vehicleRepositoryHash() => r'e08eff52fca61d3d9e30d35c5ec98f93fbaa5b0e';
