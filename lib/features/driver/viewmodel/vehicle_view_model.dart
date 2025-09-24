import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/driver/repository/vehicle_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_view_model.g.dart';

@riverpod
Future<List<VehicleModel>> getAllVehicles(Ref ref) async {
  final authLocalRepository = ref.watch(authLocalRepositoryProvider);
  final accessToken = authLocalRepository.getToken('access_token');
  
  if (accessToken == null) {
    throw 'Access token not found';
  }

  final res = await ref.watch(vehicleRepositoryProvider).listVehicles(
    accessToken: accessToken,
  );
  
  return switch (res) {
    Left(value: final l) => throw l.message,
    Right(value: final r) =>
      r.map((vehicle) => VehicleModel.fromJson(vehicle)).toList(),
  };
}

@riverpod
class VehicleViewModel extends _$VehicleViewModel {
  late VehicleRepository _vehicleRepository;
  late AuthLocalRepository _authLocalRepository;

  @override
  AsyncValue<VehicleModel>? build() {
    _vehicleRepository = ref.watch(vehicleRepositoryProvider);
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    return null;
  }

  Future<void> addVehicle({
    required Map<String, dynamic> data,
    String? photoPath,
  }) async {
    state = const AsyncValue.loading();
    final accessToken = _authLocalRepository.getToken('access_token');
    
    if (accessToken == null) {
      state = AsyncValue.error("Access token not found", StackTrace.current);
      return;
    }

    final res = await _vehicleRepository.addVehicle(
      data,
      photoPath: photoPath,
      accessToken: accessToken,
    );
    
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state =
          AsyncValue.data(VehicleModel.fromJson(r)),
    };
    print('Add vehicle result: ${val.value}');
  }

  Future<void> updateVehicle({
    required String vehicleId,
    required Map<String, dynamic> data,
    String? photoPath,
  }) async {
    state = const AsyncValue.loading();
    final accessToken = _authLocalRepository.getToken('access_token');
    
    if (accessToken == null) {
      state = AsyncValue.error("Access token not found", StackTrace.current);
      return;
    }

    final res = await _vehicleRepository.updateVehicle(
      vehicleId,
      data,
      photoPath: photoPath,
      accessToken: accessToken,
    );
    
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state =
          AsyncValue.data(VehicleModel.fromJson(r)),
    };
    print('Update vehicle result: ${val.value}');
  }

  Future<void> deleteVehicle(String vehicleId) async {
    state = const AsyncValue.loading();
    final accessToken = _authLocalRepository.getToken('access_token');
    
    if (accessToken == null) {
      state = AsyncValue.error("Access token not found", StackTrace.current);
      return;
    }

    final res = await _vehicleRepository.deleteVehicle(
      vehicleId,
      accessToken: accessToken,
    );
    
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final _) => state = AsyncValue.data(null),
    };
    print('Delete vehicle result: ${val.value}');
  }

  Future<void> getVehicle(String vehicleId) async {
    state = const AsyncValue.loading();
    final accessToken = _authLocalRepository.getToken('access_token');
    
    if (accessToken == null) {
      state = AsyncValue.error("Access token not found", StackTrace.current);
      return;
    }

    final res = await _vehicleRepository.getVehicle(
      vehicleId,
      accessToken: accessToken,
    );
    
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state =
          AsyncValue.data(VehicleModel.fromJson(r)),
    };
    print('Get vehicle result: ${val.value}');
  }
}