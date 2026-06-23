import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

class BiometricPaymentService {
  final String _backendBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;

  final StreamController<bool> _connectionStream =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStream.stream;

  VoidCallback? onDisconnected;

  BiometricPaymentService({
    required String backendBaseUrl,
  }) : _backendBaseUrl = backendBaseUrl;

  bool get isConnected => _isConnected;

  Future<void> connect(String host, {int port = 8765}) async {
    if (_isConnected) return;

    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);

    try {
      await _channel!.ready.timeout(const Duration(seconds: 5));
    } catch (_) {
      _channel = null;
      rethrow;
    }

    _isConnected = true;
    _connectionStream.add(true);

    _subscription = _channel!.stream.listen(
      (message) {
        debugPrint('Merchant system message: $message');
      },
      onDone: () {
        _isConnected = false;
        _channel = null;
        _connectionStream.add(false);
        onDisconnected?.call();
      },
      onError: (_) {
        _isConnected = false;
        _channel = null;
        _connectionStream.add(false);
        onDisconnected?.call();
      },
    );
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectionStream.add(false);

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    if (_channel != null) {
      try {
        await _channel!.sink
            .close(ws_status.normalClosure)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      _channel = null;
    }
  }

  bool triggerMerchantDevice({
    required String phoneNumber,
    required String transactionId,
    required int amountMinor,
    required String merchantPhone,
  }) {
    if (!_isConnected || _channel == null) return false;

    final payload = {
      "action": "request_payment",
      "user_id": phoneNumber,
      "transaction_id": transactionId,
      "amount": amountMinor,
      "merchant_id": merchantPhone,
    };

    _channel!.sink.add(jsonEncode(payload));
    return true;
  }

  Future<String> monitorTransactionStatus(
    String transactionId, {
    int maxAttempts = 30,
    required String accessToken,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
      try {
        final response = await http.get(
          Uri.parse("$_backendBaseUrl/transaction-status/$transactionId"),
          headers: {
            "Authorization": "Bearer $accessToken",
          },
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
    _subscription?.cancel();
    _channel?.sink.close();
    _connectionStream.close();
    _isConnected = false;
  }
}
