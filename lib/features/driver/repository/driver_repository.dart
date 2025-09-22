// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';

import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/models/driver_model.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_repository.g.dart';

@riverpod
DriverRepository driverRepository(Ref ref) {
  return DriverRepository();
}

class DriverRepository {
  final String baseUrl = ServerConstants.baseUrl;
  late Dio _dio;

  DriverRepository() {
    _dio = Dio();
    _dio.options.baseUrl;
  }

  /// FETCH DRIVER PROFILE
  Future<Either<AppFailure, DriverModel>> fetchDriverProfile() async {
    try {
      final response = await _dio.get('/drivers/me');

      print(
          "🟣 Fetch Driver Profile Response: ${response.statusCode} -> ${response.data}");

      final data = jsonDecode(response.data) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return Right(DriverModel.fromMap(data));
      } else {
        return Left(
          AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(
          AppFailure(
              "Request timed out. Please check your internet connection."),
        );
      }
      ;

      print("❌ Fetch Driver Profile Error: ${e.toString()}");
      return Left(AppFailure("Unexpected error: ${e.toString()}"));
    }
  }

  /// UPDATE DRIVER PROFILE
  Future<Either<AppFailure, Map<String, dynamic>>> updateDriverProfile({
    required Map<String, dynamic> data,
    String? photoPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath,
              filename: 'profile_photo.jpg'),
        ));
      }

      final response = await _dio.patch(
        '/drivers/me',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      print(
          "🟢 Update Driver Profile Response: ${response.statusCode} -> ${response.data}");

      data = jsonDecode(response.data) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(data);
      } else {
        return Left(
          AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        Left(
          AppFailure(
              "Request timed out. Please check your internet connection."),
        );
      }
      print("❌ Update Driver Profile Error: ${e.toString()}");
      return Left(AppFailure("Unexpected error: ${e.toString()}"));
    }
  }
}
