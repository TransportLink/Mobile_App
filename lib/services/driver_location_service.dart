import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverLocationService {
  final String baseUrl = 'https://trotro-hailing-authentication-servi.vercel.app';
  final Dio _dio;

  DriverLocationService() : _dio = Dio() {
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
              try {
                final response = await _dio.post(
                  '/auth/refresh',
                  data: {'refresh_token': storedRefreshToken},
                );
                if (response.statusCode == 200 || response.statusCode == 201) {
                  final newAccessToken = response.data['access_token'];
                  final newRefreshToken = response.data['refresh_token'];
                  await prefs.setString('access_token', newAccessToken);
                  await prefs.setString('refresh_token', newRefreshToken);
                  e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  final retryResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                await prefs.remove('access_token');
                await prefs.remove('refresh_token');
                return handler.reject(DioException(
                  requestOptions: e.requestOptions,
                  error: 'Token refresh failed: $refreshError',
                ));
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> updateDriverLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final response = await _dio.post(
        '/locations',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
      );
      print("🟢 Update Location Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 201) {
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
      print("❌ Update Location Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> createDestination({
    required String routeName,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    required String availabilityStatus,
  }) async {
    try {
      final response = await _dio.post(
        '/destinations',
        data: {
          'route_name': routeName,
          'start_latitude': startLatitude,
          'start_longitude': startLongitude,
          'end_latitude': endLatitude,
          'end_longitude': endLongitude,
          'availability_status': availabilityStatus,
        },
      );
      print("🟢 Create Destination Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 201) {
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
      print("❌ Create Destination Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> listDestinations(String driverId) async {
    try {
      final response = await _dio.get('/destinations/$driverId');
      print("🟣 List Destinations Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
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
      print("❌ List Destinations Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> updateDestination(String destinationId, String availabilityStatus) async {
    try {
      final response = await _dio.patch(
        '/destinations/$destinationId',
        data: {'availability_status': availabilityStatus},
      );
      print("🟢 Update Destination Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
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
      print("❌ Update Destination Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

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