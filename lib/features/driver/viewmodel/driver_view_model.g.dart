// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DriverViewModel)
const driverViewModelProvider = DriverViewModelProvider._();

final class DriverViewModelProvider extends $NotifierProvider<DriverViewModel,
    AsyncValue<Map<String, dynamic>>?> {
  const DriverViewModelProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'driverViewModelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$driverViewModelHash();

  @$internal
  @override
  DriverViewModel create() => DriverViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<Map<String, dynamic>>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<Map<String, dynamic>>?>(value),
    );
  }
}

String _$driverViewModelHash() => r'633d9c39cfb377c9dbccdf18eab4ea09ad1add04';

abstract class _$DriverViewModel
    extends $Notifier<AsyncValue<Map<String, dynamic>>?> {
  AsyncValue<Map<String, dynamic>>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<Map<String, dynamic>>?,
        AsyncValue<Map<String, dynamic>>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Map<String, dynamic>>?,
            AsyncValue<Map<String, dynamic>>?>,
        AsyncValue<Map<String, dynamic>>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
