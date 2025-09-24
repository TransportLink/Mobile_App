// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_file_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UploadFile)
const uploadFileProvider = UploadFileProvider._();

final class UploadFileProvider
    extends $NotifierProvider<UploadFile, AsyncValue<String>?> {
  const UploadFileProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'uploadFileProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$uploadFileHash();

  @$internal
  @override
  UploadFile create() => UploadFile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String>?>(value),
    );
  }
}

String _$uploadFileHash() => r'6adbd8d21ae348be82c0e9b8b0ed84e67cddff24';

abstract class _$UploadFile extends $Notifier<AsyncValue<String>?> {
  AsyncValue<String>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String>?, AsyncValue<String>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<String>?, AsyncValue<String>?>,
        AsyncValue<String>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
