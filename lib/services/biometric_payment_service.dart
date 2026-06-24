import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

class PaymentResult {
  final String transactionId;
  final String userId;
  final String status;
  final String? message;
  final double? score;
  final String? receipt;

  PaymentResult({
    required this.transactionId,
    required this.userId,
    required this.status,
    this.message,
    this.score,
    this.receipt,
  });
}

class BiometricPaymentService {
  final String _backendBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _healthTimer;

  final StreamController<bool> _connectionStream =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStream.stream;

  final StreamController<PaymentResult> _resultController =
      StreamController<PaymentResult>.broadcast();
  Stream<PaymentResult> get paymentResultStream => _resultController.stream;

  VoidCallback? onDisconnected;

  BiometricPaymentService({
    required String backendBaseUrl,
  }) : _backendBaseUrl = backendBaseUrl;

  bool get isConnected => _isConnected;

  Future<void> connect(String host, {int port = 8765}) async {
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;

    if (_channel != null) {
      await disconnect();
    }

    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);

    try {
      await _channel!.ready.timeout(const Duration(seconds: 5));
    } catch (_) {
      _channel = null;
      _isConnecting = false;
      rethrow;
    }

    _isConnected = true;
    _isConnecting = false;
    _connectionStream.add(true);
    _resetHealthTimer();

    _subscription = _channel!.stream.listen(
      (message) {
        _resetHealthTimer();
        debugPrint('Merchant system message: $message');
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['action'] == 'payment_result') {
            final result = PaymentResult(
              transactionId: data['transaction_id'] as String? ?? '',
              userId: data['user_id'] as String? ?? '',
              status: data['status'] as String? ?? 'failed',
              message: data['message'] as String?,
              score: (data['score'] as num?)?.toDouble(),
              receipt: data['receipt'] as String?,
            );
            _resultController.add(result);
          }
        } catch (_) {}
      },
      onDone: () {
        _healthTimer?.cancel();
        _isConnected = false;
        _channel = null;
        _connectionStream.add(false);
        onDisconnected?.call();
      },
      onError: (_) {
        _healthTimer?.cancel();
        _isConnected = false;
        _channel = null;
        _connectionStream.add(false);
        onDisconnected?.call();
      },
    );
  }

  Future<void> disconnect() async {
    _healthTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
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

  void _resetHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('Connection health check failed — no message for 30s, disconnecting');
      disconnect();
      _connectionStream.add(false);
      onDisconnected?.call();
    });
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
    _healthTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _connectionStream.close();
    _resultController.close();
    _isConnected = false;
    _isConnecting = false;
  }
}
