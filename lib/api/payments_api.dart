import 'package:dio/dio.dart';
import '../models/api_models.dart';
import 'api_client.dart';

class PaymentsApi {
  PaymentsApi(this._c);
  final ApiClient _c;

  Future<CheckoutResponse> checkout({
    required int amountMinor,
    required String method, // 'card' | 'wallet' | 'fingerprint'
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    String currency = 'EGP',
    String? walletPhoneNumber,
  }) async {
    try {
      final r = await _c.dio.post('/api/v1/payments/checkout', data: {
        'amountMinor': amountMinor,
        'currency': currency,
        'method': method,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
        if (walletPhoneNumber != null) 'walletPhoneNumber': walletPhoneNumber,
      });
      return CheckoutResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<PaymentIntentStatusResponse> paymentIntentStatus(
      String paymentIntentId) async {
    try {
      final r = await _c.dio.get('/api/v1/payments/status/$paymentIntentId');
      return PaymentIntentStatusResponse.fromJson(
          r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<String> initiateBiometricPayment({
    required String merchantId,
    required String targetUserId,
    required int amountMinor,
  }) async {
    try {
      final r = await _c.dio.post('/api/v1/payments/initiate', data: {
        'merchant_id': merchantId,
        'target_user_id': targetUserId,
        'amount': amountMinor,
      });
      return r.data['transaction_id'] as String;
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }
}

class AdminApi {
  AdminApi(this._c);
  final ApiClient _c;

  Future<List<PendingKycSummary>> pendingKyc(
      {int skip = 0, int take = 25}) async {
    try {
      final r = await _c.dio.get(
        '/api/v1/admin/kyc/pending',
        queryParameters: {'skip': skip, 'take': take},
      );
      final list = (r.data as List).cast<Map<String, dynamic>>();
      return list.map(PendingKycSummary.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<void> approve(String id, String reason) async {
    try {
      await _c.dio
          .post('/api/v1/admin/kyc/$id/approve', data: {'reason': reason});
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<void> reject(String id, String reason) async {
    try {
      await _c.dio
          .post('/api/v1/admin/kyc/$id/reject', data: {'reason': reason});
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }
}
