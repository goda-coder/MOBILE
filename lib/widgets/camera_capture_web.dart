import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/image_data.dart';
import '../theme/colors.dart';
import 'app_button.dart';

class CameraCapture extends StatelessWidget {
  const CameraCapture({super.key, required this.onCaptured, this.faceGuide = true, this.front = true});
  final void Function(ImageData image) onCaptured;
  final bool faceGuide;
  final bool front;

  Future<void> _pickImage(BuildContext context) async {
    final upload = html.FileUploadInputElement();
    upload.accept = 'image/*';
    upload.click();
    await upload.onChange.first;
    final file = upload.files?.first;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final bytes = reader.result as Uint8List;
    onCaptured(ImageData(bytes, name: file.name));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AspectRatio(aspectRatio: 4/3, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.ink950),
        child: const Center(child: Icon(Icons.camera_alt, color: Colors.white24, size: 56)),
      )),
      const SizedBox(height: 12),
      Row(children: [AppButton(label: 'Pick image', icon: Icons.photo, onPressed: () => _pickImage(context))]),
    ]);
  }
}
