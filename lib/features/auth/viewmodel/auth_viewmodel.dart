// ignore_for_file: strict_top_level_inference, non_constant_identifier_names

import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/model/user_model.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/repository/auth_remote_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_viewmodel.g.dart';

@riverpod
class AuthViewmodel extends _$AuthViewmodel {
  late AuthRemoteRepository _authRemoteRepository;
  late AuthLocalRepository _authLocalRepository;
  late CurrentUserNotifier _currentUserNotifier;

  @override
  AsyncValue<UserModel>? build() {
    _authRemoteRepository = ref.watch(authRemoteRepositoryProvider);
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    _currentUserNotifier = ref.watch(currentUserNotifierProvider.notifier);

    return null;
  }

  Future<void> initSharedPreferences() async {
    await _authLocalRepository.init();
  }

  Future<void> registerUser({
    required full_name,
    required email,
    required password,
    required phone_number,
    required date_of_birth,
    required license_number,
    required license_expiry,
    required national_id,
  }) async {
    state = const AsyncValue.loading();

    final res = await _authRemoteRepository.registerUser(
        fullName: full_name,
        email: email,
        phoneNumber: phone_number,
        password: password,
        dob: date_of_birth,
        licenseNumber: license_number,
        licenseExpiry: license_expiry,
        nationalId: national_id);

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state = AsyncValue.data(
          UserModel(
            id: r['driver_id'] ?? '',
            full_name: full_name,
            email: email,
            password_hash: '',
            phone_number: phone_number,
            date_of_birth: date_of_birth,
            license_number: license_number,
            license_expiry: license_expiry,
            national_id: national_id,
          )),
    };

    print(val);
  }

  Future<void> loginUser(
      {required String email, required String password}) async {
    state = AsyncValue.loading();

    final res = await _authRemoteRepository.login(email, password);

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => await _loginUserSuccess(r)
    };

    print(val.value);
  }

  Future<AsyncValue<UserModel>> _loginUserSuccess(
      Map<String, dynamic> token) async {
    _authLocalRepository.setToken("access_token", token["access_token"]);
    _authLocalRepository.setToken("refresh_token", token["refresh_token"]);
    UserModel? user = await getUserData();

    // Infer and persist role from profile if not already set
    if (user != null) {
      final currentRole = ref.read(userRoleProvider);
      if (currentRole == UserRole.unknown) {
        final role = user.isDriver ? UserRole.driver : UserRole.passenger;
        await ref.read(userRoleProvider.notifier).setRole(role);
      }
    }

    return state = AsyncValue.data(user!);
  }

  Future<UserModel?> getUserData() async {
    state = const AsyncValue.loading();
    final token = _authLocalRepository.getToken('access_token');

    if (token == null) {
      return null;
    }

    final res = await _authRemoteRepository.fetchUserProfile();
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => _fetchUserDataSuccess(r)
    };

    print(val.value);
    return val.value;
  }

  Future<UserModel?> updateUserData(String? profilePhotoPath) async {
    state = const AsyncValue.loading();
    final token = _authLocalRepository.getToken('access_token');

    if (token == null) {
      return null;
    }

    final currentUser = ref.read(currentUserNotifierProvider);

    final res = await _authRemoteRepository.updateUserProfile(
        data: currentUser!.toMap(),
        accessToken: token,
        photoPath: profilePhotoPath);
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final _) => await _updateUserDataSuccess()
    };

    print(val.value);
    return val.value;
  }

  Future<AsyncValue<UserModel>> _updateUserDataSuccess() async {
    final currentUser = await getUserData();
    return state = AsyncValue.data(currentUser!);
  }

  AsyncValue<UserModel> _fetchUserDataSuccess(UserModel user) {
    _currentUserNotifier.addCurrentUser(user);
    return state = AsyncValue.data(user);
  }
}
