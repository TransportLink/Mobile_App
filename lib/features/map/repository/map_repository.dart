import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/route.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_repository.g.dart';

@riverpod
MapRepository mapRepository(Ref ref) {
  return MapRepository();
}

class MapRepository {
  final String baseUrl = ServerConstants.baseUrl;
  final Dio _dio = Dio();

  MapRepository() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  Future<Either<AppFailure, List<BusStop>>> fetchBusStops({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      final queryParameters = <String, dynamic>{};
      if (latitude != null && longitude != null && radius != null) {
        queryParameters['lat'] = latitude;
        queryParameters['lon'] = longitude;
        queryParameters['radius'] = radius;
      }
      print("📡 Sending request to /map/systems with params: $queryParameters");
      final response = await _dio.get(
        '/map/systems',
        queryParameters: queryParameters,
        options: Options(headers: {'X-API-KEY': apiKey}),
      );
      print(
          "🟣 Fetch Bus Stops Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        final features = response.data['features'] as List<dynamic>? ?? [];
        final busStops = features.map((f) => BusStop.fromJson(f)).toList();
        return Right(busStops);
      } else {
        return Left(
          AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Fetch Bus Stops Timeout: $e");
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }
      print("❌ Fetch Bus Stops Error: $e");
      return Left(
        AppFailure("An unexpected error occurred!"),
      );
    } catch (e) {
      print("❌ Fetch Bus Stops Error: $e");
      return Left(
        AppFailure("An unexpected error occurred!"),
      );
    }
  }

  Future<Either<AppFailure, Route>> fetchRoute(
      {required String driverId,
      required String destination,
      required String systemId,
      required double destLat,
      required double destLng,
      required double startLat,
      required double startLng,
      required String accessToken}) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return Left(AppFailure("Access token missing."));
      }

      print(
          "📡 Sending request to /routes with driver_id: $driverId, destination: $destination, system_id: $systemId, dest_lat: $destLat, dest_lng: $destLng");

      final response = await _dio.get(
        '/routes',
        queryParameters: {
          'driver_id': driverId,
          'destination': destination,
          'system_id': systemId,
          'dest_lat': destLat,
          'dest_lng': destLng,
        },
        options: Options(headers: {
          'X-API-KEY': apiKey,
          'Authorization': 'Bearer $accessToken',
        }),
      );

      print(
          "🟣 Fetch Route Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        return Right(Route.fromJson(response.data));
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      String errorMessage;
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage =
            "Request timed out. Please check your internet connection.";
      } else if (e.response?.statusCode == 401) {
        errorMessage = "Unauthorized. Please log in again.";
      } else if (e.response?.statusCode == 403) {
        errorMessage = "Forbidden. You don’t have permission.";
      } else {
        errorMessage = extractErrorMessage(
            e.response?.data, e.response?.statusCode ?? 500);
      }
      print("❌ Fetch Route Error: $e");
      return Left(AppFailure(errorMessage));
    }
  }

  Future<Either<AppFailure, Map<String, dynamic>>> fetchReverseGeocoding(
      {required double latitude,
      required double longitude}) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      print(
          "📡 Sending request to /geocoding/reverse with lat: $latitude, lon: $longitude");
      final response = await _dio.get(
        '/geocoding/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
        },
        options: Options(headers: {'X-API-KEY': apiKey}),
      );
      print(
          "🟣 Reverse Geocoding Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Reverse Geocoding Timeout: $e");
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }

      print("❌ Reverse Geocoding Error: $e");
      return Left(
          AppFailure("Reverse Geocoding failed. Please try again later."));
    } catch (e) {
      print(e);
      return Left(
          AppFailure("Something went wrong!")); 
    }
  }
}
