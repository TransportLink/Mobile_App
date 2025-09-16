import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapService {
  final String baseUrl = 'https://smart-trotro-map-microservice.vercel.app/';
  final Dio _dio;

  MapService() : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  Future<Map<String, dynamic>> fetchBusStops({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      final queryParameters = <String, dynamic>{};
      if (latitude != null && longitude != null && radius != null) {
        queryParameters['lat'] = latitude;
        queryParameters['lon'] = longitude;
        queryParameters['radius'] = radius;
      }
      final response = await _dio.get(
        '/map/systems',
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      print("🟣 Fetch Bus Stops Response: ${response.statusCode} -> ${response.data}");
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
      print("❌ Fetch Bus Stops Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> fetchRoute({
    required String driverId,
    required String destination,
    required String systemId,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      final response = await _dio.get(
        '/routes',
        queryParameters: {
          'driver_id': driverId,
          'destination': destination,
          'system_id': systemId,
        },
        options: Options(headers: {'X-API-KEY': apiKey}),
      );
      print("🟣 Fetch Route Response: ${response.statusCode} -> ${response.data}");
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
      print("❌ Fetch Route Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> fetchReverseGeocoding({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      final response = await _dio.get(
        '/geocoding/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
        },
        options: Options(headers: {'X-API-KEY': apiKey}),
      );
      print("🟣 Reverse Geocoding Response: ${response.statusCode} -> ${response.data}");
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
      print("❌ Reverse Geocoding Error: $e");
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