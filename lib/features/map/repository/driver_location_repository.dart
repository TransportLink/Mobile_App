import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_location_repository.g.dart';

@riverpod
DriverLocationRepository driverLocationRepository(DriverLocationRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return DriverLocationRepository(dio);
}

class DriverLocationRepository {
  final Dio _dio;

  DriverLocationRepository(this._dio);

  /// Update Driver Location
  Future<Either<AppFailure, Map<String, dynamic>>> updateDriverLocation({
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure("Request timed out. Please check your internet connection."));
      }
      return Left(AppFailure("Something went wrong. Please try again."));
    }
  }

  /// Create Destination
  Future<Either<AppFailure, Map<String, dynamic>>> createDestination({
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
      if (response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure("Request timed out. Please check your internet connection."));
      }
      return Left(AppFailure("Something went wrong. Please try again."));
    }
  }

  /// List Destinations
  Future<Either<AppFailure, Map<String, dynamic>>> listDestinations(
      String driverId) async {
    try {
      final response = await _dio.get('/destinations/$driverId');
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure("Request timed out. Please check your internet connection."));
      }
      return Left(AppFailure("Something went wrong. Please try again."));
    }
  }

  /// Update Destination availability
  Future<Either<AppFailure, Map<String, dynamic>>> updateDestination(
      String destinationId, String availabilityStatus) async {
    try {
      final response = await _dio.patch(
        '/destinations/$destinationId',
        data: {'availability_status': availabilityStatus},
      );
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure("Request timed out. Please check your internet connection."));
      }
      return Left(AppFailure("Something went wrong. Please try again."));
    }
  }
}
