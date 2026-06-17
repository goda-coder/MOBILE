import 'package:flutter/material.dart';
import '../models/image_data.dart';

class CameraCapture extends StatelessWidget {
  const CameraCapture({
    super.key,
    required this.onCaptured,
    this.faceGuide = true,
    this.front = true,
  });

  final void Function(ImageData image) onCaptured;
  final bool faceGuide;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('CameraCapture not supported on Web'),
    );
  }
}