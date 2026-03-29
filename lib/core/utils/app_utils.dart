import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';

/// REFRESH TOKEN
Future<Map<String, dynamic>> refreshToken(String refreshToken, Dio dio) async {
  try {
    final response = await dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    print(
        "🟢 Refresh Token Response: ${response.statusCode} -> ${response.data}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {"success": true, "data": response.data};
    } else {
      return {
        "success": false,
        "message":
            extractErrorMessage(response.data, response.statusCode ?? 500)
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

void showSnackBar(
  BuildContext context, 
  String content, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: isError ? Colors.red.shade700 : AppPalette.primaryDark,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        action: isError 
          ? SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            )
          : null,
      ),
    );
}
