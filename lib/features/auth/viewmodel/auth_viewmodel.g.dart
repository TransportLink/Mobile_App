// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthViewmodel)
const authViewmodelProvider = AuthViewmodelProvider._();

final class AuthViewmodelProvider
    extends $NotifierProvider<AuthViewmodel, AsyncValue<DriverModel>?> {
  const AuthViewmodelProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authViewmodelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authViewmodelHash();

  @$internal
  @override
  AuthViewmodel create() => AuthViewmodel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<DriverModel>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DriverModel>?>(value),
    );
  }
}

String _$authViewmodelHash() => r'c34394998e2780e3fba4cbb62a838abbf7483e50';

abstract class _$AuthViewmodel extends $Notifier<AsyncValue<DriverModel>?> {
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
