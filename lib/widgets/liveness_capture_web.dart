import 'package:flutter/material.dart';

class LivenessCapture extends StatelessWidget {
  const LivenessCapture({
    super.key,
    required this.action,
    required this.onFrames,
    this.durationMs = 4000,
    this.fps = 6,
  });

  final String action;
  final void Function(List<String> base64Frames) onFrames;
  final int durationMs;
  final int fps;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('LivenessCapture not supported on Web'),
    );
  }
}