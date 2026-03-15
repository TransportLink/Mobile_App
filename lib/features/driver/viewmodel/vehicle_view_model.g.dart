// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getAllVehiclesHash() => r'88899361e3f1fbf3f2949f5e6bb9ddec1308f2d5';

/// See also [getAllVehicles].
@ProviderFor(getAllVehicles)
final getAllVehiclesProvider =
    AutoDisposeFutureProvider<List<VehicleModel>>.internal(
  getAllVehicles,
  name: r'getAllVehiclesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getAllVehiclesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GetAllVehiclesRef = AutoDisposeFutureProviderRef<List<VehicleModel>>;
String _$vehicleViewModelHash() => r'c1f22339653490efe51aee05e6ac5da64f2fe3f0';

/// See also [VehicleViewModel].
@ProviderFor(VehicleViewModel)
final vehicleViewModelProvider = AutoDisposeNotifierProvider<VehicleViewModel,
    AsyncValue<VehicleModel?>?>.internal(
  VehicleViewModel.new,
  name: r'vehicleViewModelProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vehicleViewModelHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VehicleViewModel = AutoDisposeNotifier<AsyncValue<VehicleModel?>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
