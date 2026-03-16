import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demand_repository.g.dart';

@riverpod
DemandRepository demandRepository(DemandRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return DemandRepository(dio);
}

/// Repository for demand broadcast endpoint.
/// 
/// Task 2.5: Demand List View for drivers
class DemandRepository {
  final Dio _dio;
  final String _baseUrl = ServerConstants.microserviceUrl;

  DemandRepository(this._dio);

  /// Get ranked bus stop opportunities.
  /// 
  /// GET /demand/broadcast?lat=...&lon=...&radius=10
  Future<Either<AppFailure, DemandData>> getDemandBroadcast({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/demand/broadcast',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'radius': radius,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return Right(DemandData.fromMap(data));
      } else {
        return Left(AppFailure(
          'Failed to load demand data: ${response.statusCode}',
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure(_handleDioError(e)));
    } catch (e) {
      return Left(AppFailure('Unexpected error: $e'));
    }
  }

  /// Get top 5 opportunities - lightweight response.
  /// 
  /// GET /demand/top-opportunities?lat=...&lon=...
  Future<Either<AppFailure, TopOpportunities>> getTopOpportunities({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/demand/top-opportunities',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return Right(TopOpportunities.fromMap(data));
      } else {
        return Left(AppFailure(
          'Failed to load opportunities: ${response.statusCode}',
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure(_handleDioError(e)));
    } catch (e) {
      return Left(AppFailure('Unexpected error: $e'));
    }
  }

  String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Response timeout. Please try again.';
    } else if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ?? data['error'] ?? 'Request failed';
      }
      return 'Request failed with status ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please try again later.';
    }
    return 'Network error. Please try again.';
  }
}

/// Top opportunities response
class TopOpportunities {
  final DriverLocation driverLocation;
  final String timestamp;
  final List<TopOpportunity> topOpportunities;

  TopOpportunities({
    required this.driverLocation,
    required this.timestamp,
    required this.topOpportunities,
  });

  factory TopOpportunities.fromMap(Map<String, dynamic> map) {
    return TopOpportunities(
      driverLocation: DriverLocation.fromMap(map['driver_location'] ?? {}),
      timestamp: map['timestamp'] ?? '',
      topOpportunities: (map['top_opportunities'] as List<dynamic>?)
              ?.map((o) => TopOpportunity.fromMap(o))
              .toList() ??
          [],
    );
  }
}

/// Top opportunity item
class TopOpportunity {
  final int rank;
  final String? location;
  final double? distanceKm;
  final double? etaMinutes;
  final int? totalPassengers;
  final double? revenueScore;
  final String? demandLevel;
  final List<String> topDestinations;

  TopOpportunity({
    required this.rank,
    this.location,
    this.distanceKm,
    this.etaMinutes,
    this.totalPassengers,
    this.revenueScore,
    this.demandLevel,
    required this.topDestinations,
  });

  factory TopOpportunity.fromMap(Map<String, dynamic> map) {
    return TopOpportunity(
      rank: map['rank'] ?? 0,
      location: map['location'],
      distanceKm: (map['distance_km'] ?? 0).toDouble(),
      etaMinutes: (map['eta_minutes'] ?? 0).toDouble(),
      totalPassengers: map['total_passengers'] ?? 0,
      revenueScore: (map['revenue_score'] ?? 0).toDouble(),
      demandLevel: map['demand_level'],
      topDestinations:
          (map['top_destinations'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
