import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:mobileapp/core/failure/app_failure.dart';
import 'package:mobileapp/core/model/driver_document.dart';
import 'package:mobileapp/core/providers/dio_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_repository.g.dart';

@riverpod
DriverRepository driverRepository(Ref ref) {
  final dio = ref.watch(dioProvider);

  return DriverRepository(dio);
}

class DriverRepository {
  final Dio _dio;

  DriverRepository(this._dio);

  /// UPLOAD DOCUMENT
  Future<Either<AppFailure, DriverDocument>> uploadDocument({
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
        formData.files.add(
          MapEntry(
            'file',
            await MultipartFile.fromFile(
              documentPath,
              filename: documentPath.split('/').last, // keep original file name
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/documents',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = response.data as Map<String, dynamic>;
        return Right(DriverDocument.fromMap(result));
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
  Future<Either<AppFailure, List<DriverDocument>>> listDocuments() async {
    try {
      final response = await _dio.get('/documents');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final res = response.data as List<dynamic>;
        final driverDocuments = res
            .map((doc) => DriverDocument.fromMap(doc as Map<String, dynamic>))
            .toList();
        print(driverDocuments);

        return Right(driverDocuments);
      } else {
        return Left(AppFailure(
          extractErrorMessage(response.data, response.statusCode ?? 500),
        ));
      }
    } on DioException catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }

  Future<Either<AppFailure, String>> uploadDocumentFile(File file) async {
    try {
      await dotenv.load(fileName: '.env');
      final String cloudinaryUrl = dotenv.env["CLOUDINARY_URL"]!;

      final uri = Uri.parse(cloudinaryUrl);

      const String uploadPreset = 'transport_link';

      final request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final res = jsonDecode(response.body);
        final url = res['secure_url'] as String;
        return Right(url);
      } else {
        return Left(AppFailure(
          "Upload failed: ${response.statusCode} -> ${response.body}",
        ));
      }
    } catch (e) {
      return Left(AppFailure("Unexpected error: $e"));
    }
  }
}
