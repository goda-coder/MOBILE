import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/api_models.dart';
import 'api_client.dart';
import '../models/image_data.dart';

class KycApi {
  KycApi(this._c);
  final ApiClient _c;

  Future<KycStatusResponse> myStatus() async {
    try {
      final r = await _c.dio.get('/api/v1/kyc/status');
      return KycStatusResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  /// Submit a KYC packet. [idBackPath] may be null for passport submissions.
  Future<KycSubmitResponse> submit({
    required String documentType,        // 'national_id' | 'passport'
    required ImageData idFront,
    ImageData? idBack,
    required ImageData selfie,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('documentType', documentType));
    form.files.add(MapEntry('idFront', await idFront.toMultipart('id_front.jpg')));
    if (idBack != null) form.files.add(MapEntry('idBack', await idBack.toMultipart('id_back.jpg')));
    form.files.add(MapEntry('selfie', await selfie.toMultipart('selfie.jpg')));
    try {
      final r = await _c.dio.post('/api/v1/kyc/submit', data: form,
          options: Options(contentType: 'multipart/form-data'));
      return KycSubmitResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  Future<LivenessChallenge> issueChallenge() async {
    try {
      final r = await _c.dio.post('/api/v1/kyc/liveness/challenge');
      return LivenessChallenge.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  Future<LivenessVerifyResponse> verifyLiveness({
    required String challengeId,
    required String action,
    required List<String> base64Frames,
  }) async {
    try {
      final r = await _c.dio.post('/api/v1/kyc/liveness/verify', data: {
        'challengeId': challengeId,
        'action': action,
        'frames': base64Frames,
      });
      return LivenessVerifyResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }
}
