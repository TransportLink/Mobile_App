import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/driver_model.dart';
import 'package:mobileapp/core/utils/app_utils.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(Ref ref) {
  final localAuthRepo = ref.watch(authLocalRepositoryProvider);
  return AuthRemoteRepository(localAuthRepo);
}

class AuthRemoteRepository {
  final String baseUrl = ServerConstants.baseUrl;
  final AuthLocalRepository _authLocalRepository;
  final Dio _dio;

  AuthRemoteRepository(this._authLocalRepository) : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken =
              _authLocalRepository.getToken('access_token') ?? '';
          if (accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final storedRefreshToken =
                _authLocalRepository.getToken('refresh_token') ?? '';
            if (storedRefreshToken.isNotEmpty) {
              final refreshResult =
                  await refreshToken(storedRefreshToken, _dio);
              if (refreshResult['success']) {
                final newAccessToken = refreshResult['data']['access_token'];
                final newRefreshToken = refreshResult['data']['refresh_token'];
                _authLocalRepository.setToken('access_token', newAccessToken);
                _authLocalRepository.setToken('refresh_token', newRefreshToken);

                // Retry the original request with the new token
                e.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                try {
                  final retryResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  return handler.reject(DioException(
                    requestOptions: e.requestOptions,
                    error: retryError,
                  ));
                }
              } else {
                // Refresh failed; clear tokens and require re-login
                _authLocalRepository.removeToken('access_token');
                _authLocalRepository.removeToken('refresh_token');
                return handler.reject(DioException(
                  requestOptions: e.requestOptions,
                  error: 'Token refresh failed: ${refreshResult['message']}',
                ));
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// LOGIN: Stores both access and refresh tokens
  Future<Either<AppFailure, Map<String, String>>> login(
      String email, String password) async {
    final body = {
      "identifier": email,
      "password": password,
    };

    try {
      final response = await _dio.post('/auth/login', data: json.encode(body));

      print("Login Body Sent: $body");
      print("Login Response: ${response.statusCode} -> ${response.data}");

      final data = jsonDecode(response.data);

      if (response.statusCode == 200) {
        final result = data as Map<String, String>;
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
      ;

      print("❌ Login Error: ${e.toString()}");

      return Left(AppFailure("Unexpected error: ${e.toString()}"));
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

      print("❌ Fetch Driver Profile Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
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
