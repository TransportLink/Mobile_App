// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getAllDocumentsHash() => r'cfeca18a0f9bff7e0f3fe4199d7f0dc474b10fc4';

/// See also [getAllDocuments].
@ProviderFor(getAllDocuments)
final getAllDocumentsProvider =
    AutoDisposeFutureProvider<List<DriverDocument>>.internal(
  getAllDocuments,
  name: r'getAllDocumentsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getAllDocumentsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GetAllDocumentsRef = AutoDisposeFutureProviderRef<List<DriverDocument>>;
String _$driverViewModelHash() => r'44aca84439b6c5cccceffabb1a7375af8c24ef46';

/// See also [DriverViewModel].
@ProviderFor(DriverViewModel)
final driverViewModelProvider = AutoDisposeNotifierProvider<DriverViewModel,
    AsyncValue<DriverDocument>?>.internal(
  DriverViewModel.new,
  name: r'driverViewModelProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$driverViewModelHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DriverViewModel = AutoDisposeNotifier<AsyncValue<DriverDocument>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
