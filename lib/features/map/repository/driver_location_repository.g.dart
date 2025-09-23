// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_location_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(driverLocationRepository)
const driverLocationRepositoryProvider = DriverLocationRepositoryProvider._();

final class DriverLocationRepositoryProvider extends $FunctionalProvider<
    DriverLocationRepository,
    DriverLocationRepository,
    DriverLocationRepository> with $Provider<DriverLocationRepository> {
  const DriverLocationRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'driverLocationRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$driverLocationRepositoryHash();

  @$internal
  @override
  $ProviderElement<DriverLocationRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DriverLocationRepository create(Ref ref) {
    return driverLocationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriverLocationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriverLocationRepository>(value),
    );
  }
}

String _$driverLocationRepositoryHash() =>
    r'0e12beb1e84037f5cb6715bad0caa3421cb3d359';
