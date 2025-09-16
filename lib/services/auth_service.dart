import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://trotro-hailing-authentication-servi.vercel.app';
  final Dio _dio;

  AuthService() : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final accessToken = prefs.getString('access_token') ?? '';
          if (accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            final storedRefreshToken = prefs.getString('refresh_token') ?? '';
            if (storedRefreshToken.isNotEmpty) {
              final refreshResult = await refreshToken(storedRefreshToken);
              if (refreshResult['success']) {
                final newAccessToken = refreshResult['data']['access_token'];
                final newRefreshToken = refreshResult['data']['refresh_token'];
                await prefs.setString('access_token', newAccessToken);
                await prefs.setString('refresh_token', newRefreshToken);

                // Retry the original request with the new token
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
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
                await prefs.remove('access_token');
                await prefs.remove('refresh_token');
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
  Future<Map<String, dynamic>> login(String email, String password) async {
    final body = {
      "identifier": email,
      "password": password,
    };

    try {
      final response = await _dio.post('/auth/login', data: body);

      print("Login Body Sent: $body");
      print("Login Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data["access_token"] != null && data["refresh_token"] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', data["access_token"]);
          await prefs.setString('refresh_token', data["refresh_token"]);
          return {"success": true, "data": data};
        } else {
          return {"success": false, "message": "No access or refresh token received"};
        }
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Login Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// REGISTER DRIVER
  Future<Map<String, dynamic>> registerDriver({
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

    try {
      final response = await _dio.post('/auth/register', data: body);

      print("🟢 Register Body Sent: $body");
      print("🟢 Register Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data["access_token"] != null && data["refresh_token"] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', data["access_token"]);
          await prefs.setString('refresh_token', data["refresh_token"]);
        }
        return {"success": true, "data": data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Register Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// FETCH DRIVER PROFILE
  Future<Map<String, dynamic>> fetchDriverProfile() async {
    try {
      final response = await _dio.get('/drivers/me');

      print("🟣 Fetch Driver Profile Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Fetch Driver Profile Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// UPDATE DRIVER PROFILE
  Future<Map<String, dynamic>> updateDriverProfile({
    required Map<String, dynamic> data,
    String? photoPath, required String accessToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath, filename: 'profile_photo.jpg'),
        ));
      }

      final response = await _dio.patch(
        '/drivers/me',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      print("🟢 Update Driver Profile Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Update Driver Profile Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// UPLOAD DOCUMENT
  Future<Map<String, dynamic>> uploadDocument({
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    String? documentPath, required String accessToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

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

      print("🟢 Upload Document Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Upload Document Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// LIST DOCUMENTS
  Future<Map<String, dynamic>> listDocuments() async {
    try {
      final response = await _dio.get('/documents');

      print("🟣 List Documents Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ List Documents Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// ADD VEHICLE
  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data, {String? photoPath, required String accessToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath, filename: 'vehicle_photo.jpg'),
        ));
      }

      final response = await _dio.post(
        '/vehicles',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      print("🟢 Add Vehicle Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Add Vehicle Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// LIST VEHICLES
  Future<Map<String, dynamic>> listVehicles() async {
    try {
      final response = await _dio.get('/vehicles');

      print("🟣 List Vehicles Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ List Vehicles Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// GET VEHICLE
  Future<Map<String, dynamic>> getVehicle(String vehicleId) async {
    try {
      final response = await _dio.get('/vehicles/$vehicleId');

      print("🟣 Get Vehicle Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Get Vehicle Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// UPDATE VEHICLE
  Future<Map<String, dynamic>> updateVehicle(String vehicleId, Map<String, dynamic> data, {String? photoPath, required String accessToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      FormData formData = FormData.fromMap(data);
      if (photoPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(photoPath, filename: 'vehicle_photo.jpg'),
        ));
      }

      final response = await _dio.patch(
        '/vehicles/$vehicleId',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      print("🟢 Update Vehicle Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Update Vehicle Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// DELETE VEHICLE
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId, {required String accessToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      final response = await _dio.delete(
        '/vehicles/$vehicleId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      print("🟢 Delete Vehicle Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Delete Vehicle Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// REFRESH TOKEN
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      print("🟢 Refresh Token Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Refresh Token Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// Helpers
  String _extractErrorMessage(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      if (data["message"] != null) return data["message"].toString();
      if (data["error"] != null) return data["error"].toString();
      if (data["errors"] is Map) {
        return (data["errors"] as Map)
            .values
            .expand((e) => e is List ? e : [e])
            .join(", ");
      }
    } else if (data is List && data.isNotEmpty) {
      return data.join(", ");
    } else if (data is String && data.isNotEmpty) {
      return data;
    }

    switch (statusCode) {
      case 400:
        return "Bad request. Please check your input.";
      case 401:
        return "Unauthorized. Please log in again.";
      case 403:
        return "Forbidden. You don’t have permission.";
      case 404:
        return "Not found. Please try again.";
      case 500:
        return "Server error. Please try later.";
      default:
        return "An unknown error occurred (code $statusCode).";
    }
  }
}