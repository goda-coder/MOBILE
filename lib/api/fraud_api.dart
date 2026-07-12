import 'package:dio/dio.dart';

import '../models/fraud_result.dart';
import '../models/transfer_data.dart';
import 'api_client.dart';

class FraudApi {
  FraudApi(this._c);
  final ApiClient _c;

  Future<FraudCheckResult> checkTransfer(TransferData data) async {
    try {
      final r = await _c.dio.post('/api/v1/fraud/check', data: {
        'recipientIdentifier': data.recipient,
        'amountMinor': data.amountMinor,
        if (data.description != null) 'description': data.description,
      });
      return FraudCheckResult.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }
}
