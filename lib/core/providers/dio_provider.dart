import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';

part 'dio_provider.g.dart';

@riverpod
Dio dio(Ref ref) {
  final authLocalRepository = ref.watch(authLocalRepositoryProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ServerConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = authLocalRepository.getToken('access_token') ?? '';
        if (accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final storedRefreshToken = authLocalRepository.getToken('refresh_token') ?? '';
          if (storedRefreshToken.isNotEmpty) {
            try {
              final response = await dio.post(
                '/auth/refresh',
                data: {'refresh_token': storedRefreshToken},
              );
              if (response.statusCode == 200 || response.statusCode == 201) {
                final newAccessToken = response.data['access_token'];
                final newRefreshToken = response.data['refresh_token'];
                authLocalRepository.setToken('access_token', newAccessToken);
                authLocalRepository.setToken('refresh_token', newRefreshToken);

                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final retryResponse = await dio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              }
            } catch (refreshError) {
              authLocalRepository.removeToken('access_token');
              authLocalRepository.removeToken('refresh_token');
              return handler.reject(
                DioException(
                  requestOptions: e.requestOptions,
                  error: 'Token refresh failed: $refreshError',
                ),
              );
            }
          }
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
}
