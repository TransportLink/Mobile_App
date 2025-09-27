import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/driver_model.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteRepository(dio);
}

class AuthRemoteRepository {
  final String baseUrl = ServerConstants.baseUrl;
  final Dio _dio;

  AuthRemoteRepository(this._dio);

  /// LOGIN: Stores both access and refresh tokens
  Future<Either<AppFailure, Map<String, dynamic>>> login(
      String email, String password) async {
    final body = {
      "identifier": email,
      "password": password,
    };

    try {
      final response = await _dio.post('/auth/login', data: json.encode(body));

      print("Login Body Sent: $body");
      print("Login Response: ${response.statusCode} -> ${response.data}");

      final data = response.data;

      if (response.statusCode == 200) {
        final result = data as Map<String, dynamic>;
        return Right(result);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }

      print("❌ Login Error: ${e.toString()}");

      return Left(AppFailure("Unexpected error: ${e.toString()}"));
    } catch (e) {
      print(e.toString());

      return Left(
        AppFailure("Something went wrong. Please try again after sometime"),
      );
    }
  }

  /// REGISTER DRIVER
  Future<Either<AppFailure, Map<String, dynamic>>> registerDriver({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String dob,
    required String licenseNumber,
    required String licenseExpiry,
    required String nationalId,
  }) async {
    final body = {
      "full_name": fullName,
      "email": email,
      "phone_number": phoneNumber,
      "password": password,
      "date_of_birth": dob,
      "license_number": licenseNumber,
      "license_expiry_date": licenseExpiry,
      "national_id": nationalId,
    };
    print(body);

    try {
      final response = await _dio.post('/auth/register', data: body);

      print("🟢 Register Body Sent: $body");
      print("🟢 Register Response: ${response.statusCode} -> ${response.data}");

      final data = response.data;
      final result = data as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return Right(result);
      } else {
        return Left(AppFailure(result["error"]!));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }

      print("❌ Register Error: ${e.toString()}");
      return Left(
          AppFailure("Something went wrong. Check the details and try again."));
    } catch (e) {
      return Left(
        AppFailure("Something went wrong. Please try again after sometime"),
      );
    }
  }

  /// FETCH DRIVER PROFILE
  Future<Either<AppFailure, DriverModel>> fetchDriverProfile() async {
    try {
      final response = await _dio.get('/drivers/me');

      print(
          "🟣 Fetch Driver Profile Response: ${response.statusCode} -> ${response.data}");

      final data = response.data as Map<String, dynamic>;

      if (response.statusCode == 200) {
        print(data);
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
        print("Internet issue");
        return Left(
          AppFailure(
              "Request timed out. Please check your internet connection."),
        );
      }

      print("❌ Fetch Driver Profile Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
    } catch (e) {
      print(e);
      return Left(AppFailure(
          "An error occurred connecting to servers. Check your internet connection and try again."));
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
