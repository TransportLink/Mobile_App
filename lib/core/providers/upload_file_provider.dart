import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/features/driver/repository/driver_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'upload_file_provider.g.dart';

@riverpod
class UploadFile extends _$UploadFile {
  late DriverRepository _driverRepository;

  @override
  AsyncValue<String>? build() {
    _driverRepository = ref.watch(driverRepositoryProvider);

    return null;
  }

  Future<void> upload(File file) async {
    state = AsyncValue.loading();

    final res = await _driverRepository.uploadFile(file);

    final val = switch (res) {
      Left(value: final l) => state =
          AsyncValue.error(l.message, StackTrace.current),
      Right(value: final r) => state = AsyncValue.data(r)
    };

    print(val.value);
  }
}
