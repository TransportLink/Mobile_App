import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_repository.g.dart';

@riverpod
VehicleRepository vehicleRepository(Ref ref) {
  return VehicleRepository();
}

class VehicleRepository {
  final String baseUrl = ServerConstants.baseUrl;
  late Dio _dio;

  VehicleRepository() {
    _dio = Dio();
    _dio.options.baseUrl;
  }
  /// UPLOAD DOCUMENT
  Future<Either<AppFailure, Map<String, dynamic>>> uploadDocument({
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    String? documentPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'document_type': documentType,
        'document_number': documentNumber,
        'expiry_date': expiryDate,
      });
      if (documentPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(documentPath, filename: 'document.jpg'),
        ));
      }

      final response = await _dio.post(
        '/documents',
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
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// LIST DOCUMENTS
  Future<Either<AppFailure, List<dynamic>>> listDocuments() async {
    try {
      final response = await _dio.get('/documents');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as List<dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

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
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// LIST VEHICLES
  Future<Either<AppFailure, List<dynamic>>> listVehicles() async {
    try {
      final response = await _dio.get('/vehicles');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as List<dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// GET VEHICLE
  Future<Either<AppFailure, Map<String, dynamic>>> getVehicle(
      String vehicleId) async {
    try {
      final response = await _dio.get('/vehicles/$vehicleId');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
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
        return Right(true);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }
}
