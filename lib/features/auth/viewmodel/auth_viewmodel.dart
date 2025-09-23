// ignore_for_file: strict_top_level_inference, non_constant_identifier_names

import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/model/driver_model.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/auth/repository/auth_remote_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_viewmodel.g.dart';

@riverpod
class AuthViewmodel extends _$AuthViewmodel {
  late AuthRemoteRepository _authRemoteRepository;
  late AuthLocalRepository _authLocalRepository;
  late CurrentDriverNotifier _currentDriverNotifier;

  @override
  AsyncValue<DriverModel>? build() {
    _authRemoteRepository = ref.watch(authRemoteRepositoryProvider);
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    _currentDriverNotifier = ref.watch(currentDriverProvider.notifier);

    return null;
  }

  Future<void> initSharedPreferences() async {
    await _authLocalRepository.init();
  }

  Future<void> registerDriver({
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

    final res = await _authRemoteRepository.registerDriver(
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
      Right(value: final _) => state
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
      Right(value: final r) => await _loginDriverSuccess(r)
    };

    print(val.value);
  }

  Future<AsyncValue<DriverModel>> _loginDriverSuccess(
      Map<String, dynamic> token) async {
    _authLocalRepository.setToken("access_token", token["access_token"]);
    _authLocalRepository.setToken("refresh_token", token["refresh_token"]);
    DriverModel? driverModel = await getDriverData();
    
    return state = AsyncValue.data(driverModel!);
  }

  Future<DriverModel?> getDriverData() async {
    state = const AsyncValue.loading();
    final token = _authLocalRepository.getToken('access_token');

    if (token == null) {
      return null;
    }

    final res = await _authRemoteRepository.fetchDriverProfile();
    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => _fetchDriverDataSuccess(r)
    };

    print(val.value);
    return val.value;
  }

  AsyncValue<DriverModel> _fetchDriverDataSuccess(DriverModel driver) {
    _currentDriverNotifier.addCurrentDriver(driver);
    return state = AsyncValue.data(driver);
  }
}
