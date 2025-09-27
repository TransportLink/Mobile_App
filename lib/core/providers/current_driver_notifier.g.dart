// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_driver_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentDriverNotifier)
const currentDriverProvider = CurrentDriverNotifierProvider._();

final class CurrentDriverNotifierProvider
    extends $NotifierProvider<CurrentDriverNotifier, DriverModel?> {
  const CurrentDriverNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentDriverProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentDriverNotifierHash();

  @$internal
  @override
  CurrentDriverNotifier create() => CurrentDriverNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriverModel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriverModel?>(value),
    );
  }
}

String _$currentDriverNotifierHash() =>
    r'dd61025f3c12df9bcfc1e180d4366e6fdb336d4e';

abstract class _$CurrentDriverNotifier extends $Notifier<DriverModel?> {
  DriverModel? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DriverModel?, DriverModel?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DriverModel?, DriverModel?>,
        DriverModel?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
