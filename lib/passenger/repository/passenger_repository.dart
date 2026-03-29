import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/server_constants.dart';
import '../model/passenger_state.dart';

/// Passenger Repository
///
/// Handles all HTTP API calls for passenger check-in functionality.
/// Uses the same auth service as the driver app.
class PassengerRepository {
  final String baseUrl = ServerConstants.webServerUrl;

  /// Get stored auth token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Check in at a bus stop
  Future<Result<PassengerCheckInState, String>> checkIn({
    required String systemId,
    required String destination,
    int passengerCount = 1,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return Result.failure('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/passenger/check_in/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'system_id': systemId,
          'destination': destination,
          'passenger_count': passengerCount,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Result.success(PassengerCheckInState.fromJson(data));
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Result.failure(data['error'] ?? 'Invalid request');
      } else if (response.statusCode == 401) {
        return Result.failure('Unauthorized - please log in again');
      } else if (response.statusCode == 404) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Result.failure(data['error'] ?? 'Bus stop not found');
      } else {
        return Result.failure('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  /// Check out from a bus stop
  Future<Result<bool, String>> checkOut({String reason = 'manual'}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return Result.failure('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/passenger/check_out/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return Result.success(true);
      } else if (response.statusCode == 404) {
        return Result.failure('No active check-in found');
      } else if (response.statusCode == 401) {
        return Result.failure('Unauthorized - please log in again');
      } else {
        return Result.failure('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  /// Get current demand at a bus stop
  Future<Result<BusStopDemand, String>> getStopInfo({
    required String systemId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/passenger/stop_info/$systemId/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Result.success(BusStopDemand.fromJson(data));
      } else if (response.statusCode == 404) {
        return Result.failure('Bus stop not found');
      } else {
        return Result.failure('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  /// Get passenger's active check-in
  Future<Result<PassengerCheckInState?, String>> getMyCheckIn() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return Result.failure('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/passenger/my_checkin/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final checkinData = data['active_checkin'];
        if (checkinData == null) {
          return Result.success(null);
        }
        return Result.success(PassengerCheckInState.fromJson(checkinData));
      } else if (response.statusCode == 401) {
        return Result.failure('Unauthorized - please log in again');
      } else {
        return Result.failure('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  /// Get active drivers for tracking map
  Future<Result<List<Map<String, dynamic>>, String>> getActiveDrivers({
    String? systemId,
    String? destination,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/passenger/drivers/').replace(
        queryParameters: {
          if (systemId != null) 'system_id': systemId,
          if (destination != null) 'destination': destination,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final drivers = (data['drivers'] as List)
            .map((d) => d as Map<String, dynamic>)
            .toList();
        return Result.success(drivers);
      } else {
        return Result.failure('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }
}

/// Result type for repository operations
class Result<T, E> {
  final T? _data;
  final E? _error;

  Result._({T? data, E? error})
      : _data = data,
        _error = error;

  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(E error) => Result._(error: error);

  bool get isSuccess => _data != null;
  bool get isFailure => _error != null;

  T? get data => _data;
  E? get error => _error;

  T get requireData {
    if (_data == null) throw StateError('Result is failure');
    return _data!;
  }

  E get requireError {
    if (_error == null) throw StateError('Result is success');
    return _error!;
  }

  Result<R, E> map<R>(R Function(T value) converter) {
    if (isSuccess) {
      return Result.success(converter(_data!));
    } else {
      return Result.failure(_error as E);
    }
  }
}

// Singleton instance
final passengerRepository = PassengerRepository();
