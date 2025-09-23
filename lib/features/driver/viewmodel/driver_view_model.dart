import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/driver/repository/driver_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_view_model.g.dart';

@riverpod
class DriverViewModel extends _$DriverViewModel {
  late DriverRepository _driverRepository;
  late AuthLocalRepository _authLocalRepository;

  @override
  AsyncValue<Map<String, dynamic>>? build() {
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    _driverRepository = ref.watch(driverRepositoryProvider);

    return null;
  }

  Future<void> uploadDocument({
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    String? documentPath,
  }) async {
    state = AsyncValue.loading();

    final accessToken = _authLocalRepository.getToken('access_token');
    final res = await _driverRepository.uploadDocument(
        documentType: documentType,
        documentNumber: documentNumber,
        expiryDate: expiryDate,
        accessToken: accessToken!);

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state = AsyncValue.data(r)
    };

    print(val.value);
  }

  //   Future<void> listDocuments({
  //   required String documentType,
  //   required String documentNumber,
  //   required String expiryDate,
  //   String? documentPath,
  // }) async {
  //   state = AsyncValue.loading();

  //   final accessToken = _authLocalRepository.getToken('access_token');
  //   final res = await _driverRepository.listDocuments();

  //   final val = switch (res) {
  //     Left(value: final l) => state =
  //         AsyncValue.error(l.message, StackTrace.current),
  //     Right(value: final r) => state = AsyncValue.data(r)
  //   };

  //   print(val.value);
  // }
}
