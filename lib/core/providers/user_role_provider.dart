import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User Role Provider
///
/// Manages user role (driver/passenger) throughout the app lifecycle.
enum UserRole {
  driver,
  passenger,
  unknown,
}

class UserRoleNotifier extends StateNotifier<UserRole> {
  UserRoleNotifier() : super(UserRole.unknown) {
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString('user_role');

    UserRole role;
    if (roleString == 'passenger') {
      role = UserRole.passenger;
    } else if (roleString == 'driver') {
      role = UserRole.driver;
    } else {
      role = UserRole.unknown;
    }

    state = role;
  }

  Future<void> setRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = role == UserRole.passenger ? 'passenger' : 'driver';
    await prefs.setString('user_role', roleString);
    state = role;
  }

  Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    state = UserRole.unknown;
  }

  bool get isDriver => state == UserRole.driver;
  bool get isPassenger => state == UserRole.passenger;
  bool get isUnknown => state == UserRole.unknown;
}

final userRoleProvider =
    StateNotifierProvider<UserRoleNotifier, UserRole>((ref) {
  return UserRoleNotifier();
});
