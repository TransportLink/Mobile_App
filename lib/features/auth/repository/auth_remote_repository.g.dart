// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_remote_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authRemoteRepository)
const authRemoteRepositoryProvider = AuthRemoteRepositoryProvider._();

final class AuthRemoteRepositoryProvider extends $FunctionalProvider<
    AuthRemoteRepository,
    AuthRemoteRepository,
    AuthRemoteRepository> with $Provider<AuthRemoteRepository> {
  const AuthRemoteRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authRemoteRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authRemoteRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRemoteRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRemoteRepository create(Ref ref) {
    return authRemoteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRemoteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRemoteRepository>(value),
    );
  }
}

String _$authRemoteRepositoryHash() =>
    r'681cc87dd1957b7902a5bebce2d2719dee9ae637';
