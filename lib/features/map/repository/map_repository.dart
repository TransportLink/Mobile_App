import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/features/driver/repository/vehicle_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart' as geo;

part 'map_repository.g.dart';

@riverpod
MapRepository mapRepository(Ref ref) {
  final authLocalRepository = ref.watch(authLocalRepositoryProvider);
  final vehicleRepository = ref.watch(vehicleRepositoryProvider);

  return MapRepository(authLocalRepository, vehicleRepository);
}

class MapRepository {
  final String microserviceUrl = ServerConstants.baseUrl;
  final AuthLocalRepository _authLocalRepository;
  final VehicleRepository _vehicleRepository;
  late Dio _dio;

  MapRepository(this._authLocalRepository, this._vehicleRepository) {
    _dio = Dio();
    _dio.options.baseUrl = microserviceUrl;
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

  Future<Either<AppFailure, Map<String, dynamic>>> fetchRoute({
    required String driverId,
    required String systemId,
    String? busStop,
    double? busStopLat,
    double? busStopLng,
    required List<Map<String, dynamic>>
        destinations, // List of {destination, passenger_count}
    required String vehicleId, // To fetch vehicle details
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      // Get stored access token from auth local repository provider
      final accessToken = _authLocalRepository.getToken('access_token') ?? '';
      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return Left(AppFailure("Access token missing."));
      }

      // Fetch vehicle details
      final res = await _vehicleRepository.getVehicle(vehicleId,
          accessToken: accessToken);

      final Map<String, dynamic> vehicleResponse = switch (res) {
        Left(value: final l) => throw l.message,
        Right(value: final r) => r
      };

      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return Left(AppFailure("Vehicle color or license plate missing."));
      }

      // Validate bus stop parameters
      if ((busStopLat == null || busStopLng == null) && busStop == null) {
        print("❌ Bus stop name or coordinates missing");
        return Left(AppFailure(
            "Either bus stop name or coordinates must be provided."));
      }

      // Validate destinations
      if (destinations.isEmpty) {
        print("❌ No destinations provided");
        return Left(AppFailure("At least one destination must be provided."));
      }

      // Ensure destinations only include destination and passenger_count
      final validatedDestinations = destinations.map((dest) {
        if (dest['destination'] == null || dest['passenger_count'] == null) {
          throw Exception(
              "Destination and passenger_count are required for each destination.");
        }
        return {
          'destination': dest['destination'],
          'passenger_count': dest['passenger_count'],
        };
      }).toList();

      // Convert destinations to JSON string
      final destinationsJson = jsonEncode(validatedDestinations);

      print(
          "📡 Sending request to /routes with driver_id: $driverId, bus_stop: $busStop, "
          "bus_stop_lat: $busStopLat, bus_stop_lng: $busStopLng, destinations: $destinationsJson, "
          "system_id: $systemId, vehicle_capacity: $vehicleCapacity, bus_color: $busColor, "
          "license_plate: $licensePlate");

      final queryParameters = <String, dynamic>{
        'driver_id': driverId,
        'destinations': destinationsJson,
        'system_id': systemId,
        'vehicle_capacity': vehicleCapacity,
        'bus_color': busColor,
        'license_plate': licensePlate,
      };
      if (busStop != null) {
        queryParameters['bus_stop'] = busStop;
      }
      if (busStopLat != null) {
        queryParameters['bus_stop_lat'] = busStopLat;
      }
      if (busStopLng != null) {
        queryParameters['bus_stop_lng'] = busStopLng;
      }

      final response = await _dio.get(
        '/routes',
        queryParameters: queryParameters,
        options: Options(headers: {
          'x-api-key': apiKey,
          'Authorization': 'Bearer $accessToken',
        }),
      );

      print(
          "🟣 Fetch Route Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        // Store trip_id in SharedPreferences
        final tripId = response.data['trip_id'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('trip_id', tripId);
        return Right(response.data);
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
    } catch (e) {
      print("❌ Fetch Route Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  Future<Either<AppFailure, Map<String, dynamic>>> cancelRoute({
    required String driverId,
    required String systemId,
    required String vehicleId,
    required String destination,
    double? destLat,
    double? destLng,
    required int passengerCount,
    required int tripId,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      // Get stored access token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return Left(AppFailure("Access token missing."));
      }

      // Fetch vehicle details
      final res = await _vehicleRepository.getVehicle(vehicleId,
          accessToken: accessToken);

      final vehicleResponse = switch (res) {
        Left(value: final l) => throw l.message,
        Right(value: final r) => r
      };

      if (!vehicleResponse['success']) {
        print(
            "❌ Failed to fetch vehicle details: ${vehicleResponse['message']}");
        return Left(AppFailure(
            "Failed to fetch vehicle details: ${vehicleResponse['message']}"));
      }

      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return Left(AppFailure("Vehicle color or license plate missing."));
      }

      // Validate destination parameters
      if (destination.isEmpty && (destLat == null || destLng == null)) {
        print("❌ Destination name or coordinates missing");
        return Left(AppFailure(
            "Either destination name or coordinates must be provided."));
      }

      if (passengerCount <= 0) {
        print("❌ Invalid passenger count");
        return Left(AppFailure("Passenger count must be greater than zero."));
      }

      print("📡 Sending request to /routes/cancel with driver_id: $driverId, "
          "destination: $destination, dest_lat: $destLat, dest_lng: $destLng, "
          "passenger_count: $passengerCount, trip_id: $tripId, system_id: $systemId");

      final queryParameters = <String, dynamic>{
        'driver_id': driverId,
        'system_id': systemId,
        'passenger_count': passengerCount,
        'vehicle_capacity': vehicleCapacity,
        'bus_color': busColor,
        'license_plate': licensePlate,
        'trip_id': tripId,
      };
      if (destination.isNotEmpty) {
        queryParameters['destination'] = destination;
      }
      if (destLat != null) {
        queryParameters['dest_lat'] = destLat;
      }
      if (destLng != null) {
        queryParameters['dest_lng'] = destLng;
      }

      final response = await _dio.post(
        '/routes/cancel',
        queryParameters: queryParameters,
        options: Options(headers: {
          'x-api-key': apiKey,
          'Authorization': 'Bearer $accessToken',
        }),
      );

      print(
          "🟣 Cancel Route Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        // Clear trip_id from SharedPreferences if no destinations remain
        if (response.data['destinations'] == null ||
            response.data['destinations'].isEmpty) {
          await prefs.remove('trip_id');
        }
        return Right(response.data);
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
      print("❌ Cancel Route Error: $e");
      return Left(AppFailure(errorMessage));
    }
  }

  // Calculate ETA using Mapbox Directions API
  Future<double?> calculateEta({
    required double driverLat,
    required double driverLng,
    required double busStopLat,
    required double busStopLng,
  }) async {
    try {
      final mapboxAccessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (mapboxAccessToken.isEmpty) {
        print("❌ MAPBOX_ACCESS_TOKEN is missing in .env");
        return null;
      }

      final response = await _dio.get(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$driverLng,$driverLat;$busStopLng,$busStopLat',
        queryParameters: {
          'access_token': mapboxAccessToken,
          'geometries': 'geojson',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final duration = data['routes'][0]['duration']?.toDouble();
          if (duration != null) {
            print("✅ Calculated ETA: $duration seconds");
            return duration;
          }
        }
        print("❌ No valid routes found in Mapbox response");
        return null;
      } else {
        print("❌ Mapbox API error: ${response.statusCode} - ${response.data}");
        return null;
      }
    } catch (e) {
      print("❌ Error calculating ETA: $e");
      return null;
    }
  }

  Future<Either<AppFailure, Map<String, dynamic>>> updateLocation({
    required String driverId,
    required String systemId,
    required String vehicleId,
    required int tripId,
    required double busStopLat,
    required double busStopLng,
    double? eta, // Optional ETA
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(
            AppFailure("API key is missing. Please check your configuration."));
      }

      final String? accessToken = _authLocalRepository.getToken('access_token');
      if (accessToken == null) {
        print("❌ Access token missing");
        return Left(AppFailure("Access token missing."));
      }

      // Fetch vehicle details
      final res = await _vehicleRepository.getVehicle(vehicleId,
          accessToken: accessToken);

      final vehicleResponse = switch (res) {
        Left(value: final l) => throw l.message,
        Right(value: final r) => r
      };

      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return Left(AppFailure("Vehicle color or license plate missing."));
        }

      // Validate coordinates
      if (busStopLat < -90 ||
          busStopLat > 90 ||
          busStopLng < -180 ||
          busStopLng > 180) {
        print("❌ Invalid bus stop coordinates");
        return Left(AppFailure("Invalid bus stop coordinates."));
      }

      // Calculate ETA if not provided
      double? finalEta = eta;
      if (finalEta == null) {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        final etaResult = await calculateEta(
          driverLat: position.latitude,
          driverLng: position.longitude,
          busStopLat: busStopLat,
          busStopLng: busStopLng,
        );
        if (etaResult == null) {
          print("❌ Failed to calculate ETA");
          return Left(AppFailure("Failed to calculate ETA."));
        }
        finalEta = etaResult;
      }

      if (finalEta < 0) {
        print("❌ Invalid ETA");
        return Left(AppFailure("ETA must be non-negative."));
      }

      print("📡 Sending request to /update_location with driver_id: $driverId, "
          "eta: $finalEta, bus_stop_lat: $busStopLat, bus_stop_lng: $busStopLng, "
          "system_id: $systemId, trip_id: $tripId, vehicle_capacity: $vehicleCapacity, "
          "bus_color: $busColor, license_plate: $licensePlate");

      final queryParameters = <String, dynamic>{
        'driver_id': driverId,
        'system_id': systemId,
        'trip_id': tripId,
        'eta': finalEta,
        'bus_stop_lat': busStopLat,
        'bus_stop_lng': busStopLng,
        'vehicle_capacity': vehicleCapacity,
        'bus_color': busColor,
        'license_plate': licensePlate,
      };

      final response = await _dio.post(
        '/routes/update_location',
        queryParameters: queryParameters,
        options: Options(headers: {
          'x-api-key': apiKey,
          'Authorization': 'Bearer $accessToken',
        }),
      );

      print(
          "🟣 Update Location Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        return Right(response.data);
      } else {
        return Left(AppFailure(extractErrorMessage(response.data, response.statusCode ?? 500)));
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
      print("❌ Update Location Error: $e");
      return Left(AppFailure(errorMessage));
    } catch (e) {
      print("❌ Update Location Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  Future<Either<AppFailure, Map<String, dynamic>>> fetchReverseGeocoding({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(AppFailure("API key is missing. Please check your configuration."));
        }

      print(
          "📡 Sending request to /geocoding/reverse with lat: $latitude, lon: $longitude");
      final response = await _dio.get(
        '/geocoding/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
        },
        options: Options(headers: {'x-api-key': apiKey}),
      );
      print(
          "🟣 Reverse Geocoding Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
        return Right(response.data);
      } else {
        return Left(AppFailure(extractErrorMessage(response.data, response.statusCode ?? 500)));
        }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Reverse Geocoding Timeout: $e");
        return Left(AppFailure("Request timed out. Please check your internet connection."));
        }
      print("❌ Reverse Geocoding Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

    Future<Either<AppFailure, Map<String, dynamic>>> fetchForwardGeocoding(String address) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return Left(AppFailure("API key is missing. Please check your configuration."));
        }

      print("📡 Sending request to /geocoding/forward with address: $address");

      final response = await _dio.get(
        '/geocoding/forward',
        queryParameters: {
          'address': address,
        },
        options: Options(headers: {'x-api-key': apiKey}),
      );

      print(
          "🟣 Forward Geocoding Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200) {
        return Right(response.data);
      } else {
        return Left(AppFailure(extractErrorMessage(response.data, response.statusCode ?? 500)));
        }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Forward Geocoding Timeout: $e");
        return Left(AppFailure("Request timed out. Please check your internet connection."));
        }

      print("❌ Forward Geocoding Error: $e");
      return Left(AppFailure("Unexpected error: $e"));
    }
  }
}
