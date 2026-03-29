import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/user_model.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(AuthRemoteRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteRepository(dio);
}

class AuthRemoteRepository {
  final String baseUrl = ServerConstants.authServiceUrl;
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
      print("❌ Login Error: ${e.toString()}");

      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }

      // Extract the actual error message from the server response
      if (e.response != null) {
        final data = e.response?.data;
        final statusCode = e.response?.statusCode;

        if (data is Map<String, dynamic>) {
          final serverError = data['error'] as String? ?? '';

          if (statusCode == 401) {
            if (serverError.contains('Invalid credentials')) {
              return Left(AppFailure(
                  "Incorrect email or password. Please try again, or create a new account if you don't have one."));
            }
            return Left(AppFailure(
                "Your session has expired. Please log in again."));
          }

          if (statusCode == 400) {
            return Left(AppFailure(
                "Please enter your email and password."));
          }

          if (statusCode == 429) {
            return Left(AppFailure(
                "Too many login attempts. Please wait a few minutes and try again."));
          }

          if (serverError.isNotEmpty) {
            return Left(AppFailure(serverError));
          }
        }

        return Left(AppFailure(
            "Login failed. Please check your details and try again."));
      }

      return Left(AppFailure(
          "Could not connect to the server. Please check your internet and try again."));
    } catch (e) {
      print(e.toString());
      return Left(AppFailure(
          "Could not connect to the server. Please check your internet and try again."));
    }
  }

  /// REGISTER DRIVER
  Future<Either<AppFailure, Map<String, dynamic>>> registerUser({
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
    print("🟢 Register Body Sent: $body");

    try {
      final response = await _dio.post('/auth/register', data: body);

      print("🟢 Register Response: ${response.statusCode} -> ${response.data}");

      final data = response.data;
      final result = data as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return Right(result);
      } else {
        // Server returned an error message
        final serverError = result["error"] as String? ?? "Registration failed";
        return Left(AppFailure(_mapRegistrationError(serverError, response.statusCode)));
      }
    } on DioException catch (e) {
      print("❌ Register Error: ${e.toString()}");
      
      // Handle different Dio error types with user-friendly messages
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure(
          "Connection timed out. Please check your internet connection and try again."
        ));
      }
      
      if (e.type == DioExceptionType.sendTimeout) {
        return Left(AppFailure(
          "Request took too long. Please check your connection and try again."
        ));
      }
      
      if (e.type == DioExceptionType.receiveTimeout) {
        return Left(AppFailure(
          "Server took too long to respond. Please try again later."
        ));
      }
      
      // Handle HTTP error status codes
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        // Try to extract error message from response
        String serverMessage = "Registration failed";
        if (responseData is Map<String, dynamic>) {
          serverMessage = responseData["error"] as String? ?? serverMessage;
        }
        
        return Left(AppFailure(_mapRegistrationError(serverMessage, statusCode)));
      }
      
      // Network error (no response)
      return Left(AppFailure(
        "Network error. Please check your internet connection and try again."
      ));
    } catch (e) {
      print("❌ Unexpected Error: ${e.toString()}");
      return Left(
        AppFailure("An unexpected error occurred. Please try again later."),
      );
    }
  }

  /// Map server error messages to user-friendly messages
  String _mapRegistrationError(String error, int? statusCode) {
    // Check for specific error messages from server
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('email or phone already exists')) {
      return 'An account with this email or phone number already exists. Please login instead.';
    }
    
    if (errorLower.contains('email') && errorLower.contains('exists')) {
      return 'This email is already registered. Please use a different email or login.';
    }
    
    if (errorLower.contains('phone') && errorLower.contains('exists')) {
      return 'This phone number is already registered. Please use a different number or login.';
    }
    
    if (errorLower.contains('last_active_at') || errorLower.contains('column')) {
      return 'Server configuration error. Please contact support.';
    }
    
    // Handle by status code
    switch (statusCode) {
      case 400:
        return 'Invalid information. Please check all fields and try again.';
      case 401:
        return 'Unauthorized. Please login to continue.';
      case 403:
        return 'Access denied. Please contact support.';
      case 409:
        return 'Account already exists. Please login instead.';
      case 500:
        return 'Server error. Please try again later or contact support.';
      case 502:
        return 'Server temporarily unavailable. Please try again later.';
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return error.isNotEmpty ? error : 'Registration failed. Please try again.';
    }
  }

  /// FETCH DRIVER PROFILE
  Future<Either<AppFailure, UserModel>> fetchUserProfile() async {
    try {
      final response = await _dio.get('/drivers/me');

      print(
          "🟣 Fetch Driver Profile Response: ${response.statusCode} -> ${response.data}");

      final data = response.data as Map<String, dynamic>;

      if (response.statusCode == 200) {
        print(data);
        return Right(UserModel.fromMap(data));
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
      return Left(AppFailure("Something went wrong. Please try again."));
    } catch (e) {
      print(e);
      return Left(AppFailure(
          "Could not connect to the server. Please check your internet and try again."));
    }
  }

  /// UPDATE DRIVER PROFILE
  Future<Either<AppFailure, Map<String, dynamic>>> updateUserProfile({
    required Map<String, dynamic> data,
    String? photoPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'profile_photo',
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
      return Left(AppFailure("Something went wrong. Please try again."));
    }
  }
}
