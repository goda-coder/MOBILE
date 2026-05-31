import 'package:dio/dio.dart';
import '../models/api_models.dart';
import 'api_client.dart';

class WalletApi {
  WalletApi(this._c);
  final ApiClient _c;

  Future<WalletSummary> summary() async {
    try {
      final r = await _c.dio.get('/api/v1/wallet/summary');
      return WalletSummary.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  Future<List<WalletTransaction>> transactions({int skip = 0, int take = 25}) async {
    try {
      final r = await _c.dio.get(
        '/api/v1/wallet/transactions',
        queryParameters: {'skip': skip, 'take': take},
      );
      final list = (r.data as List).cast<Map<String, dynamic>>();
      return list.map(WalletTransaction.fromJson).toList(growable: false);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  Future<TransferResponse> transfer({
    required String recipientIdentifier,
    required int amountMinor,
    required String reference,
    String currency = 'EGP',
    String? description,
  }) async {
    try {
      final r = await _c.dio.post('/api/v1/wallet/transfer', data: {
        'recipientIdentifier': recipientIdentifier,
        'amountMinor': amountMinor,
        'currency': currency,
        'reference': reference,
        if (description != null) 'description': description,
      });
      return TransferResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }

  Future<AccountReport> report() async {
    try {
      final r = await _c.dio.get('/api/v1/wallet/report');
      return AccountReport.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) { throw ApiClient.toApiError(e); }
  }
}
