import 'package:dio/dio.dart';

import '../models/fraud_result.dart';
import '../models/transfer_data.dart';
import 'api_client.dart';

class FraudApi {
  FraudApi(this._c);
  final ApiClient _c;

  Future<FraudCheckResult> checkTransfer(TransferData data) async {
    try {
      // Transform TransferData to the Transaction model expected by the Python API
      final transactionRequest = {
        'step': 1, // Fixed starting step as per fraud_api.py
        'type': 'TRANSFER', // All transfers are of type 'TRANSFER'
        'amount': data.amountMinor / 100, // Convert from minor to EGP
        // Note: oldbalanceOrg, newbalanceOrig require sender wallet balance
        // For now, using 0 as placeholder - in a real implementation,
        // we would fetch the sender's current balance
        'oldbalanceOrg': 0.0,
        'newbalanceOrig': 0.0,
        'oldbalanceDest': data.amountMinor == 0 ? 0.0 : data.amountMinor / 100,
        'newbalanceDest': data.amountMinor / 100,
        if (data.description != null && data.description!.isNotEmpty)
          'description': data.description,
      };

      // Call the Python fraud API directly
      final r = await _c.dio
          .post('http://10.0.2.2:8000/predict', data: transactionRequest);

      // Convert Python response field names (snake_case) to Dart model fields (camelCase)
      final pythonResponse = r.data as Map<String, dynamic>;
      final mappedResponse = {
        'isFraud': pythonResponse['is_fraud'] ?? false,
        'riskLevel': pythonResponse['risk_level'] ?? 'LOW',
        'probability': pythonResponse['probability'] ?? 0,
        'reasons': pythonResponse['reasons'] ?? [],
      };

      return FraudCheckResult.fromJson(mappedResponse);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }
}
