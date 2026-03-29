// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getAllDocumentsHash() => r'33a4738fbfcd088e9a4aa03a38b8a7889af231f8';

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
String _$driverViewModelHash() => r'841a5d154873793162227836f11682b74b74fc81';

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
