import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_location_repository.g.dart';

@riverpod
DriverLocationRepository driverLocationRepository(Ref ref) {
  final localAuthRepo = ref.watch(authLocalRepositoryProvider);
  return DriverLocationRepository(localAuthRepo);
}

class DriverLocationRepository {
  final String baseUrl = ServerConstants.baseUrl;
  final AuthLocalRepository _authLocalRepository;
  final Dio _dio;

  DriverLocationRepository(this._authLocalRepository) : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = _authLocalRepository.getToken('access_token') ?? '';
          if (accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final storedRefreshToken = _authLocalRepository.getToken('refresh_token') ?? '';
            if (storedRefreshToken.isNotEmpty) {
              try {
                final response = await _dio.post(
                  '/auth/refresh',
                  data: {'refresh_token': storedRefreshToken},
                );
                if (response.statusCode == 200 || response.statusCode == 201) {
                  final newAccessToken = response.data['access_token'];
                  final newRefreshToken = response.data['refresh_token'];
                  _authLocalRepository.setToken('access_token', newAccessToken);
                  _authLocalRepository.setToken('refresh_token', newRefreshToken);
                  e.requestOptions.headers['Authorization'] =
                      'Bearer $newAccessToken';
                  final retryResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                _authLocalRepository.removeToken('access_token');
                _authLocalRepository.removeToken('refresh_token');
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

      print("🟢 Update Location Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      return Left(_handleDioError(e, "Update Location failed"));
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
      print("🟢 Create Destination Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      return Left(_handleDioError(e, "Create Destination failed"));
    }
  }

  /// List Destinations
  Future<Either<AppFailure, Map<String, dynamic>>> listDestinations(
      String driverId) async {
    try {
      final response = await _dio.get('/destinations/$driverId');
      print("🟣 List Destinations Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      return Left(_handleDioError(e, "List Destinations failed"));
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
      print("🟢 Update Destination Response: ${response.statusCode} -> ${response.data}");
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      return Left(_handleDioError(e, "Update Destination failed"));
    }
  }

  // === Helpers ===
  AppFailure _handleDioError(DioException e, String context) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return AppFailure("Request timed out. Please check your internet connection.");
    }
    print("❌ $context Error: $e");
    return AppFailure("Unexpected error: ${e.message}");
  }
}
