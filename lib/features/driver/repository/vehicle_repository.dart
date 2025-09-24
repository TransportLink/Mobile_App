import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_repository.g.dart';

@riverpod
VehicleRepository vehicleRepository(Ref ref) {
  final dio = ref.read(dioProvider);
  return VehicleRepository(dio);
}

class VehicleRepository {
  final String baseUrl = ServerConstants.baseUrl;
  late final Dio _dio;

  VehicleRepository(this._dio);

  /// ADD VEHICLE
  Future<Either<AppFailure, Map<String, dynamic>>> addVehicle(
    Map<String, dynamic> data, {
    String? photoPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath,
              filename: 'vehicle_photo.jpg'),
        ));
      }

      final response = await _dio.post(
        '/vehicles',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Network error: ${e.message}"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// LIST VEHICLES
  Future<Either<AppFailure, List<dynamic>>> listVehicles({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get(
        '/vehicles',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as List<dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Network error: ${e.message}"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// GET VEHICLE
  Future<Either<AppFailure, Map<String, dynamic>>> getVehicle(
    String vehicleId, {
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get(
        '/vehicles/$vehicleId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Network error: ${e.message}"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// UPDATE VEHICLE
  Future<Either<AppFailure, Map<String, dynamic>>> updateVehicle(
    String vehicleId,
    Map<String, dynamic> data, {
    String? photoPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath,
              filename: 'vehicle_photo.jpg'),
        ));
      }

      final response = await _dio.patch(
        '/vehicles/$vehicleId',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Network error: ${e.message}"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// DELETE VEHICLE
  Future<Either<AppFailure, bool>> deleteVehicle(
    String vehicleId, {
    required String accessToken,
  }) async {
    try {
      final response = await _dio.delete(
        '/vehicles/$vehicleId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return const Right(true);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Network error: ${e.message}"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }
}
