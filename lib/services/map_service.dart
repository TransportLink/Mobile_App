import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './auth_service.dart'; // Import AuthService to fetch vehicle details

class MapService {
  final String baseUrl = 'https://smart-trotro-map-microservice.vercel.app/';
  final Dio _dio;
  final AuthService _authService;

  MapService()
      : _dio = Dio(),
        _authService = AuthService() {
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
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
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
        options: Options(headers: {'x-api-key': apiKey}),
      );
      print(
          "🟣 Fetch Bus Stops Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Fetch Bus Stops Timeout: $e");
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
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
      }

      // Get stored access token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return {"success": false, "message": "Access token missing."};
      }

      // Fetch vehicle details
      final vehicleResponse = await _authService.getVehicle(vehicleId);
      if (!vehicleResponse['success']) {
        print(
            "❌ Failed to fetch vehicle details: ${vehicleResponse['message']}");
        return {
          "success": false,
          "message":
              "Failed to fetch vehicle details: ${vehicleResponse['message']}"
        };
      }
      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return {
          "success": false,
          "message": "Vehicle color or license plate missing."
        };
      }

      // Validate bus stop parameters
      if ((busStopLat == null || busStopLng == null) && busStop == null) {
        print("❌ Bus stop name or coordinates missing");
        return {
          "success": false,
          "message": "Either bus stop name or coordinates must be provided."
        };
      }

      // Validate destinations
      if (destinations.isEmpty) {
        print("❌ No destinations provided");
        return {
          "success": false,
          "message": "At least one destination must be provided."
        };
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
        await prefs.setInt('trip_id', tripId);
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
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
        errorMessage = _extractErrorMessage(
            e.response?.data, e.response?.statusCode ?? 500);
      }
      print("❌ Fetch Route Error: $e");
      return {"success": false, "message": errorMessage};
    } catch (e) {
      print("❌ Fetch Route Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> cancelRoute({
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
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
      }

      // Get stored access token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return {"success": false, "message": "Access token missing."};
      }

      // Fetch vehicle details
      final vehicleResponse = await _authService.getVehicle(vehicleId);
      if (!vehicleResponse['success']) {
        print(
            "❌ Failed to fetch vehicle details: ${vehicleResponse['message']}");
        return {
          "success": false,
          "message":
              "Failed to fetch vehicle details: ${vehicleResponse['message']}"
        };
      }
      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return {
          "success": false,
          "message": "Vehicle color or license plate missing."
        };
      }

      // Validate destination parameters
      if (destination.isEmpty && (destLat == null || destLng == null)) {
        print("❌ Destination name or coordinates missing");
        return {
          "success": false,
          "message": "Either destination name or coordinates must be provided."
        };
      }

      if (passengerCount <= 0) {
        print("❌ Invalid passenger count");
        return {
          "success": false,
          "message": "Passenger count must be greater than zero."
        };
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
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
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
        errorMessage = _extractErrorMessage(
            e.response?.data, e.response?.statusCode ?? 500);
      }
      print("❌ Cancel Route Error: $e");
      return {"success": false, "message": errorMessage};
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

  Future<Map<String, dynamic>> updateLocation({
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
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      if (accessToken.isEmpty) {
        print("❌ Access token missing");
        return {"success": false, "message": "Access token missing."};
      }

      // Fetch vehicle details
      final vehicleResponse = await _authService.getVehicle(vehicleId);
      if (!vehicleResponse['success']) {
        print(
            "❌ Failed to fetch vehicle details: ${vehicleResponse['message']}");
        return {
          "success": false,
          "message":
              "Failed to fetch vehicle details: ${vehicleResponse['message']}"
        };
      }
      final vehicleData = vehicleResponse['data'];
      final vehicleCapacity = vehicleData['seating_capacity'] ?? 15;
      final busColor = vehicleData['color'] ?? '';
      final licensePlate = vehicleData['plate_number'] ?? '';

      if (busColor.isEmpty || licensePlate.isEmpty) {
        print("❌ Vehicle color or license plate missing");
        return {
          "success": false,
          "message": "Vehicle color or license plate missing."
        };
      }

      // Validate coordinates
      if (busStopLat < -90 ||
          busStopLat > 90 ||
          busStopLng < -180 ||
          busStopLng > 180) {
        print("❌ Invalid bus stop coordinates");
        return {"success": false, "message": "Invalid bus stop coordinates."};
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
          return {"success": false, "message": "Failed to calculate ETA."};
        }
        finalEta = etaResult;
      }

      if (finalEta < 0) {
        print("❌ Invalid ETA");
        return {"success": false, "message": "ETA must be non-negative."};
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
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
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
        errorMessage = _extractErrorMessage(
            e.response?.data, e.response?.statusCode ?? 500);
      }
      print("❌ Update Location Error: $e");
      return {"success": false, "message": errorMessage};
    } catch (e) {
      print("❌ Update Location Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> fetchReverseGeocoding({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
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
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Reverse Geocoding Timeout: $e");
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Reverse Geocoding Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  Future<Map<String, dynamic>> fetchForwardGeocoding(String address) async {
    try {
      final apiKey = dotenv.env['MAP_SERVICE_API_KEY'] ??
          'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';
      if (apiKey.isEmpty) {
        print("❌ MAP_SERVICE_API_KEY is missing in .env");
        return {
          "success": false,
          "message": "API key is missing. Please check your configuration."
        };
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
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message":
              _extractErrorMessage(response.data, response.statusCode ?? 500),
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        print("❌ Forward Geocoding Timeout: $e");
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Forward Geocoding Error: $e");
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
        return "Unauthorized. Please check your API key.";
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
