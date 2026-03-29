import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/driver_earnings.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'earnings_repository.g.dart';

@riverpod
EarningsRepository earningsRepository(EarningsRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return EarningsRepository(dio);
}

/// Repository for driver earnings and statistics
class EarningsRepository {
  final Dio _dio;
  final String _webServerUrl = ServerConstants.webServerUrl;

  EarningsRepository(this._dio);

  /// Get driver statistics (today, week, month, all time)
  /// GET /api/driver/stats/?driver_id=xxx
  Future<Either<AppFailure, DriverStats>> getDriverStats({
    required String driverId,
  }) async {
    try {
      final response = await _dio.get(
        '$_webServerUrl/api/driver/stats/',
        queryParameters: {'driver_id': driverId},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return Right(DriverStats.fromMap(data));
        } else {
          return Left(AppFailure(data['message'] ?? 'Failed to load stats'));
        }
      } else {
        return Left(AppFailure(
          'Could not load your stats. Please try again.',
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure(_handleDioError(e)));
    } catch (e) {
      return Left(AppFailure('Something went wrong. Please try again.'));
    }
  }

  /// Get detailed earnings history
  /// GET /api/driver/earnings/?driver_id=xxx&period=today|week|month|all
  Future<Either<AppFailure, EarningsHistory>> getEarningsHistory({
    required String driverId,
    String period = 'all',
  }) async {
    try {
      final response = await _dio.get(
        '$_webServerUrl/api/driver/earnings/',
        queryParameters: {
          'driver_id': driverId,
          'period': period,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return Right(EarningsHistory.fromMap(data));
        } else {
          return Left(AppFailure(data['message'] ?? 'Failed to load earnings'));
        }
      } else {
        return Left(AppFailure(
          'Could not load your earnings. Please try again.',
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure(_handleDioError(e)));
    } catch (e) {
      return Left(AppFailure('Something went wrong. Please try again.'));
    }
  }

  String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection is slow. Please check your internet and try again.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server is taking too long. Please try again.';
    } else if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ?? data['error'] ?? 'Request failed';
      }
      return 'Request failed. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please try again later.';
    }
    return 'Could not connect. Please check your internet and try again.';
  }
}

/// Earnings history response
class EarningsHistory {
  final String driverId;
  final String period;
  final double totalEarnings;
  final int totalTrips;
  final double averagePerTrip;
  final List<DriverEarnings> earnings;
  final List<TopRoute> topRoutes;

  EarningsHistory({
    required this.driverId,
    required this.period,
    required this.totalEarnings,
    required this.totalTrips,
    required this.averagePerTrip,
    required this.earnings,
    required this.topRoutes,
  });

  factory EarningsHistory.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? map;
    return EarningsHistory(
      driverId: data['driver_id'] ?? '',
      period: data['period'] ?? 'all',
      totalEarnings: (data['total_earnings'] ?? 0).toDouble(),
      totalTrips: data['total_trips'] ?? 0,
      averagePerTrip: (data['average_per_trip'] ?? 0).toDouble(),
      earnings: (data['earnings'] as List<dynamic>?)
              ?.map((e) => DriverEarnings.fromMap(e))
              .toList() ??
          [],
      topRoutes: (data['top_routes'] as List<dynamic>?)
              ?.map((r) => TopRoute.fromMap(r))
              .toList() ??
          [],
    );
  }
}

/// Top earning route
class TopRoute {
  final String route;
  final int trips;
  final double earnings;

  TopRoute({
    required this.route,
    required this.trips,
    required this.earnings,
  });

  factory TopRoute.fromMap(Map<String, dynamic> map) {
    return TopRoute(
      route: map['route'] ?? '',
      trips: map['trips'] ?? 0,
      earnings: (map['earnings'] ?? 0).toDouble(),
    );
  }
}
