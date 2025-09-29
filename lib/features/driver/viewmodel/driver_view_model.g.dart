// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getAllDocuments)
const getAllDocumentsProvider = GetAllDocumentsProvider._();

final class GetAllDocumentsProvider extends $FunctionalProvider<
        AsyncValue<List<DriverDocument>>,
        List<DriverDocument>,
        FutureOr<List<DriverDocument>>>
    with
        $FutureModifier<List<DriverDocument>>,
        $FutureProvider<List<DriverDocument>> {
  const GetAllDocumentsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getAllDocumentsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getAllDocumentsHash();

  @$internal
  @override
  $FutureProviderElement<List<DriverDocument>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<DriverDocument>> create(Ref ref) {
    return getAllDocuments(ref);
  }
}

String _$getAllDocumentsHash() => r'bec64c0ce21b278d0f63216a3cb17cd219df6368';

@ProviderFor(DriverViewModel)
const driverViewModelProvider = DriverViewModelProvider._();

final class DriverViewModelProvider
    extends $NotifierProvider<DriverViewModel, AsyncValue<DriverDocument>?> {
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
  Override overrideWithValue(AsyncValue<DriverDocument>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DriverDocument>?>(value),
    );
  }
}

String _$driverViewModelHash() => r'44aca84439b6c5cccceffabb1a7375af8c24ef46';

abstract class _$DriverViewModel
    extends $Notifier<AsyncValue<DriverDocument>?> {
  AsyncValue<DriverDocument>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref
        as $Ref<AsyncValue<DriverDocument>?, AsyncValue<DriverDocument>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DriverDocument>?, AsyncValue<DriverDocument>?>,
        AsyncValue<DriverDocument>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
