import 'package:flutter/material.dart';

class AppQrScanner extends StatelessWidget {
  const AppQrScanner({
    super.key,
    required this.onScan,
  });

  final void Function(String payload) onScan;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'QR Scanner is not supported on Web.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}