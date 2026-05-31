import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Web shim: pick a single image and send repeated frames (placeholder).
class LivenessCapture extends StatelessWidget {
  const LivenessCapture({super.key, required this.action, required this.onFrames, this.durationMs = 4000, this.fps = 6});
  final String action;
  final void Function(List<String> base64Frames) onFrames;
  final int durationMs;
  final int fps;

  Future<void> _pickAndSend() async {
    final upload = html.FileUploadInputElement()..accept = 'image/*';
    upload.click();
    await upload.onChange.first;
    final file = upload.files?.first;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final bytes = reader.result as Uint8List;
    final base64 = base64Encode(bytes);
    final frameCount = (fps * (durationMs / 1000)).round().clamp(1, 60);
    final frames = List<String>.filled(frameCount, base64);
    onFrames(frames);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('LIVENESS CHALLENGE', style: TextStyle(color: AppColors.ink400, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text(action, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      AspectRatio(aspectRatio: 4/3, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.ink950), child: const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 40)))),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _pickAndSend, child: const Text('Pick image and simulate liveness')),
    ]);
  }
}
