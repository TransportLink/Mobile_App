import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_local_repository.g.dart';

@Riverpod(keepAlive: true)
AuthLocalRepository authLocalRepository(Ref ref) {
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
}
