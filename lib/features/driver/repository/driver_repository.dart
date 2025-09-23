import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_repository.g.dart';

@riverpod
DriverRepository driverRepository(Ref ref) {
  return DriverRepository();
}

class DriverRepository {
  final String baseUrl = ServerConstants.baseUrl;
  late Dio _dio;

  DriverRepository() {
    _dio = Dio();
    _dio.options.baseUrl = baseUrl;
  }

  /// UPLOAD DOCUMENT
  Future<Either<AppFailure, Map<String, dynamic>>> uploadDocument({
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    String? documentPath,
    required String accessToken,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'document_type': documentType,
        'document_number': documentNumber,
        'expiry_date': expiryDate,
      });
      if (documentPath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(documentPath, filename: 'document.jpg'),
        ));
      }

      final response = await _dio.post(
        '/documents',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = response.data as Map<String, dynamic>;
        return Right(result);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  /// LIST DOCUMENTS
  Future<Either<AppFailure, List<dynamic>>> listDocuments() async {
    try {
      final response = await _dio.get('/documents');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data as List<dynamic>);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }
}
