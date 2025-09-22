import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/utils/app_utils.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(Ref ref) {
  return AuthRemoteRepository();
}

class AuthRemoteRepository {
  final String baseUrl = ServerConstants.baseUrl;
  final _authLocalRepository = AuthLocalRepository();
  final Dio _dio;

  AuthRemoteRepository() : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken =
              _authLocalRepository.getToken('access_token') ?? '';
          if (accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final storedRefreshToken =
                _authLocalRepository.getToken('refresh_token') ?? '';
            if (storedRefreshToken.isNotEmpty) {
              final refreshResult = await refreshToken(storedRefreshToken, _dio);
              if (refreshResult['success']) {
                final newAccessToken = refreshResult['data']['access_token'];
                final newRefreshToken = refreshResult['data']['refresh_token'];
                _authLocalRepository.setToken('access_token', newAccessToken);
                _authLocalRepository.setToken('refresh_token', newRefreshToken);

                // Retry the original request with the new token
                e.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                try {
                  final retryResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  return handler.reject(DioException(
                    requestOptions: e.requestOptions,
                    error: retryError,
                  ));
                }
              } else {
                // Refresh failed; clear tokens and require re-login
                _authLocalRepository.removeToken('access_token');
                _authLocalRepository.removeToken('refresh_token');
                return handler.reject(DioException(
                  requestOptions: e.requestOptions,
                  error: 'Token refresh failed: ${refreshResult['message']}',
                ));
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// LOGIN
  Future<Either<AppFailure, Map<String, String>>> login(
      String email, String password) async {
    final body = {
      "identifier": email,
      "password": password,
    };

    try {
      final response = await _dio.post('/auth/login', data: json.encode(body));

      print("Login Body Sent: $body");
      print("Login Response: ${response.statusCode} -> ${response.data}");

      final data = jsonDecode(response.data);

      if (response.statusCode == 200) {
        final result = data as Map<String, String>;
        return Right(result);
      } else {
        return Left(AppFailure(
            extractErrorMessage(response.data, response.statusCode ?? 500)));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(AppFailure(
            "Request timed out. Please check your internet connection."));
      }
      ;

      print("❌ Login Error: ${e.toString()}");

      return Left(AppFailure("Unexpected error: ${e.toString()}"));
    }
  }
}
