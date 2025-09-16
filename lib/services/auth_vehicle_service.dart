import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String apiBaseUrl = 'https://trotro-hailing-authentication-servi.vercel.app';

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data, {String? photoPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    var request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/vehicles'));
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields.addAll(data.map((key, value) => MapEntry(key, value.toString())));
    
    if (photoPath != null) {
      final file = await http.MultipartFile.fromPath('file', photoPath);
      request.files.add(file);
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  Future<List<dynamic>> listVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$apiBaseUrl/vehicles'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getVehicle(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$apiBaseUrl/vehicles/$vehicleId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateVehicle(String vehicleId, Map<String, dynamic> data, {String? photoPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    var request = http.MultipartRequest('PATCH', Uri.parse('$apiBaseUrl/vehicles/$vehicleId'));
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields.addAll(data.map((key, value) => MapEntry(key, value.toString())));
    
    if (photoPath != null) {
      final file = await http.MultipartFile.fromPath('file', photoPath);
      request.files.add(file);
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final response = await http.delete(
      Uri.parse('$apiBaseUrl/vehicles/$vehicleId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return jsonDecode(response.body);
  }
}