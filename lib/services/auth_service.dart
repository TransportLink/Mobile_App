import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://trotro-hailing-authentication-servi.vercel.app';

  /// LOGIN: Stores the latest access token after each login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final body = {
      "identifier": email,
      "password": password,
    };

    try {
      final response = await http.post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print(" Login Body Sent: $body");
      print("Login Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data["access_token"] != null) {
          // Always store the latest token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', data["access_token"]);
          return {"success": true, "data": data};
        } else {
          return {"success": false, "message": "No access token received"};
        }
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          "success": false,
          "message": _extractErrorMessage(decoded, response.statusCode)
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Request timed out. Please check your internet connection."
      };
    } catch (e) {
      print("❌ Login Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// REGISTER DRIVER
  Future<Map<String, dynamic>> registerDriver({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String dob,
    required String licenseNumber,
    required String licenseExpiry,
    required String nationalId,
  }) async {
    final body = {
      "full_name": fullName,
      "email": email,
      "phone_number": phoneNumber,
      "password": password,
      "date_of_birth": dob,
      "license_number": licenseNumber,
      "license_expiry_date": licenseExpiry,
      "national_id": nationalId,
    };

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("🟢 Register Body Sent: $body");
      print("🟢 Register Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          "success": false,
          "message": _extractErrorMessage(decoded, response.statusCode)
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Request timed out. Please check your internet connection."
      };
    } catch (e) {
      print("❌ Register Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// FETCH DRIVER PROFILE: Always uses the latest token from SharedPreferences
  Future<Map<String, dynamic>> fetchDriverProfile([String? accessToken]) async {
    if (accessToken == null || accessToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token') ?? '';
    }

    print('🟣 Using access token: $accessToken');

    try {
      final response = await http.get(
            Uri.parse('$baseUrl/drivers/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      print("🟣 Fetch Driver Profile Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          "success": false,
          "message": _extractErrorMessage(decoded, response.statusCode)
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Request timed out. Please check your internet connection."
      };
    } catch (e) {
      print("❌ Fetch Driver Profile Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// UPDATE DRIVER PROFILE
  Future<Map<String, dynamic>> updateDriverProfile({
    required String accessToken,
    required Map<String, dynamic> data,
    String? photoPath,
  }) async {
    try {
      var request = http.MultipartRequest('PATCH', Uri.parse('$baseUrl/drivers/me'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.headers['Content-Type'] = 'multipart/form-data';

      request.fields.addAll(data.map((key, value) => MapEntry(key, value.toString())));

      if (photoPath != null) {
        final file = await http.MultipartFile.fromPath('file', photoPath);
        request.files.add(file);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final decoded = jsonDecode(responseBody);

      print("🟢 Update Driver Profile Response: ${response.statusCode} -> $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(decoded, response.statusCode)
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Request timed out. Please check your internet connection."
      };
    } catch (e) {
      print("❌ Update Driver Profile Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }


  /// UPLOAD DOCUMENT
  Future<Map<String, dynamic>> uploadDocument({
    required String accessToken,
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    String? documentPath,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.headers['Content-Type'] = 'multipart/form-data';

      request.fields.addAll({
        'document_type': documentType,
        'document_number': documentNumber,
        'expiry_date': expiryDate,
      });

      if (documentPath != null) {
        final file = await http.MultipartFile.fromPath('file', documentPath);
        request.files.add(file);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final decoded = jsonDecode(responseBody);

      print("🟢 Upload Document Response: ${response.statusCode} -> $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": _extractErrorMessage(decoded, response.statusCode)
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Request timed out. Please check your internet connection."
      };
    } catch (e) {
      print("❌ Upload Document Error: $e");
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  /// LIST DOCUMENTS
  Future<List<dynamic>> listDocuments(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 15));

      print("🟣 List Documents Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final decoded = _safeJsonDecode(response.body);
        throw Exception(_extractErrorMessage(decoded, response.statusCode));
      }
    } on TimeoutException {
      throw Exception("Request timed out. Please check your internet connection.");
    } catch (e) {
      print("❌ List Documents Error: $e");
      throw Exception("Unexpected error: $e");
    }
  }


  /// Helpers
  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  String _extractErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      if (decoded["message"] != null) return decoded["message"].toString();
      if (decoded["error"] != null) return decoded["error"].toString();
      if (decoded["errors"] is Map) {
        return (decoded["errors"] as Map)
            .values
            .expand((e) => e is List ? e : [e])
            .join(", ");
      }
    } else if (decoded is List && decoded.isNotEmpty) {
      return decoded.join(", ");
    } else if (decoded is String && decoded.isNotEmpty) {
      return decoded;
    }

    switch (statusCode) {
      case 400:
        return "Bad request. Please check your input.";
      case 401:
        return "Unauthorized. Please log in again.";
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