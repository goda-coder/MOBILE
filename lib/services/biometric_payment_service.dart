import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class BiometricPaymentService {
  final String _backendBaseUrl;

  final int _wsPort;

  HttpServer? _localServer;
  WebSocket? _merchantSocket;
  bool _isServerRunning = false;

  final StreamController<bool> _connectionStream =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStream.stream;

  BiometricPaymentService({
    required String backendBaseUrl,
    int wsPort = 8765,
  })  : _backendBaseUrl = backendBaseUrl,
        _wsPort = wsPort;

  bool get isServerRunning => _isServerRunning;

  Future<void> startLocalWebSocketServer() async {
    if (_isServerRunning) return;

    try {
      _localServer = await HttpServer.bind(InternetAddress.anyIPv4, _wsPort);
      _isServerRunning = true;

      _localServer!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _merchantSocket = await WebSocketTransformer.upgrade(request);
          _connectionStream.add(true);

          _merchantSocket!.listen(
            (message) {},
            onDone: () {
              _merchantSocket = null;
              _connectionStream.add(false);
            },
            onError: (error) {
              _merchantSocket = null;
              _connectionStream.add(false);
            },
          );
        }
      });
    } catch (_) {
      _isServerRunning = false;
      rethrow;
    }
  }

  Future<void> stopLocalWebSocketServer() async {
    _merchantSocket?.close();
    _merchantSocket = null;
    await _localServer?.close(force: true);
    _localServer = null;
    _isServerRunning = false;
    _connectionStream.add(false);
  }

  Future<String?> initiateBiometricPayment({
    required String merchantId,
    required String targetUserId,
    required int amountMinor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_backendBaseUrl/initiate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "merchant_id": merchantId,
          "target_user_id": targetUserId,
          "amount": amountMinor,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data["transaction_id"] as String?;
      } else {
        return null;
      }
    } catch (_) {
      rethrow;
    }
  }

  bool triggerMerchantDevice({
    required String phoneNumber,
    required String transactionId,
  }) {
    if (_merchantSocket == null) return false;

    final payload = {
      "action": "request_payment",
      "user_id": phoneNumber,
      "transaction_id": transactionId,
    };

    _merchantSocket!.add(jsonEncode(payload));
    return true;
  }

  Future<String> monitorTransactionStatus(
    String transactionId, {
    int maxAttempts = 30,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
      try {
        final response = await http.get(
          Uri.parse("$_backendBaseUrl/transaction-status/$transactionId"),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data["status"] as String? ?? "PENDING";

          if (status == "SUCCESS" || status == "FAILED") {
            return status;
          }
        }
      } catch (_) {}
    }
    return "TIMEOUT";
  }

  void dispose() {
    _localServer?.close(force: true);
    _merchantSocket?.close();
    _connectionStream.close();
    _isServerRunning = false;
  }
}
