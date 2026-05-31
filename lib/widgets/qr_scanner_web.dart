import 'package:flutter/material.dart';

/// Web shim for QR scanning: allow manual paste of payload.
class AppQrScanner extends StatefulWidget {
  const AppQrScanner({super.key, required this.onScan});
  final void Function(String payload) onScan;
  @override
  State<AppQrScanner> createState() => _AppQrScannerState();
}

class _AppQrScannerState extends State<AppQrScanner> {
  final _controller = TextEditingController();

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AspectRatio(aspectRatio: 1, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black12), child: Center(child: Text('QR scanner not available on web', style: TextStyle(color: Colors.white70))))),
      const SizedBox(height: 8),
      TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Paste QR payload')),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: () { final v = _controller.text.trim(); if (v.isNotEmpty) widget.onScan(v); }, child: const Text('Submit')),
    ]);
  }
}
