import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/model/driver_document.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/driver/repository/driver_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_view_model.g.dart';

@riverpod
Future<List<DriverDocument>> getAllDocuments(Ref ref) async {
  final currentDriver = ref.watch(currentDriverProvider);

  if (currentDriver == null) {
    throw 'No current driver found';
  }

  final res = await ref.watch(driverRepositoryProvider).listDocuments();

  return switch (res) {
    Left(value: final l) => throw l.message,
    Right(value: final r) => r,
  };
}

@riverpod
class DriverViewModel extends _$DriverViewModel {
  late DriverRepository _driverRepository;
  late AuthLocalRepository _authLocalRepository;

  @override
  AsyncValue<DriverDocument>? build() {
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    _driverRepository = ref.watch(driverRepositoryProvider);
    return null;
  }

  /// Upload a document for the current driver
  Future<void> uploadDocument(
      {required String documentType,
      required String documentNumber,
      required String expiryDate,
      File? documentFile}) async {
    state = const AsyncValue.loading();

    final accessToken = _authLocalRepository.getToken('access_token');
    if (accessToken == null) {
      state = AsyncValue.error('Access token not found', StackTrace.current);
      return;
    }

    String? documentFilePath;

    if (documentFile != null) {
      final res = await _driverRepository.uploadFile(documentFile);
      final _ = switch (res) {
        Left(value: final l) => state =
            AsyncValue.error(l.message, StackTrace.current),
        Right(value: final r) => documentFilePath = r
      };
    }

    final res = await _driverRepository.uploadDocument(
      documentType: documentType,
      documentNumber: documentNumber,
      expiryDate: expiryDate,
      documentPath: documentFilePath,
      accessToken: accessToken,
    );

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state = AsyncValue.data(r),
    };

    print('Upload result: $val');
  }
}
