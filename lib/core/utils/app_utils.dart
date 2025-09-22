import 'package:dio/dio.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';

 /// REFRESH TOKEN
  Future<Map<String, dynamic>> refreshToken(String refreshToken, Dio _dio) async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      print("🟢 Refresh Token Response: ${response.statusCode} -> ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": response.data};
      } else {
        return {
          "success": false,
          "message": extractErrorMessage(response.data, response.statusCode ?? 500)
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return {
          "success": false,
          "message": "Request timed out. Please check your internet connection."
        };
      }
      print("❌ Refresh Token Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }