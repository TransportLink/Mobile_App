import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_local_repository.g.dart';

@Riverpod(keepAlive: true)
AuthLocalRepository authLocalRepository(AuthLocalRepositoryRef ref) {
  return AuthLocalRepository();
}

class AuthLocalRepository {
  late SharedPreferences _sharedPreferences;

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  void setToken(String tokenType, String? token) {
    if (token == null) {
      return;
    }
    _sharedPreferences.setString(
      tokenType,
      token,
    );
  }

  String? getToken(String tokenType) {
    return _sharedPreferences.getString(tokenType);
  }

  void removeToken(String tokenType) {
    _sharedPreferences.remove(tokenType);
  }

  // Default vehicle persistence
  Future<void> setDefaultVehicleId(String vehicleId) async {
    await _sharedPreferences.setString('default_vehicle_id', vehicleId);
  }

  String? getDefaultVehicleId() {
    return _sharedPreferences.getString('default_vehicle_id');
  }

  Future<void> removeDefaultVehicleId() async {
    await _sharedPreferences.remove('default_vehicle_id');
  }

  // Active trip cache — survives app restarts & network failures
  Future<void> cacheActiveTrip(Map<String, dynamic> tripData) async {
    await _sharedPreferences.setString('cached_active_trip', jsonEncode(tripData));
  }

  Map<String, dynamic>? getCachedActiveTrip() {
    final raw = _sharedPreferences.getString('cached_active_trip');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedActiveTrip() async {
    await _sharedPreferences.remove('cached_active_trip');
  }
}
