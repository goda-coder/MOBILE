import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WSConnectionState {
  connected,
  connecting,
  closing,
  disconnected,
}

class BiometricSystemService {
  final Uri wsURL;

  WebSocketChannel? channel;
  StreamSubscription? _subscription;

  VoidCallback? onDisconnected;

  BiometricSystemService({
    required this.wsURL,
  });

  Future<void> connect() async {
    if (channel != null) return;

    channel = WebSocketChannel.connect(wsURL);

    try {
      await channel!.ready.timeout(const Duration(seconds: 5));
    } catch (_) {
      channel = null;
      rethrow;
    }

    _subscription = channel!.stream.listen(
      (message) {
        debugPrint(message);
      },
      onDone: () {
        debugPrint("Socket closed");

        channel = null;
        onDisconnected?.call();
      },
      onError: (_) {
        channel = null;
        onDisconnected?.call();
      },
    );
  }

  Future<void> dispose() async {
    final current = channel;

    channel = null;

    try {
      await _subscription?.cancel();
    } catch (_) {}

    _subscription = null;

    if (current == null) return;

    try {
      await current.sink
          .close(status.normalClosure)
          .timeout(const Duration(seconds: 3));
    } catch (e, s) {
      debugPrint("Close error: $e");
      debugPrintStack(stackTrace: s);
    }
  }

  void send(String message) {
    channel?.sink.add(message);
  }
}
