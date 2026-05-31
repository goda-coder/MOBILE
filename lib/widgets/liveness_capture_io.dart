import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'app_button.dart';
import '../models/image_data.dart';
import 'package:image/image.dart' as img_pkg;

class LivenessCapture extends StatefulWidget {
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
  State<LivenessCapture> createState() => _LivenessCaptureState();
}

class _LivenessCaptureState extends State<LivenessCapture> {
  CameraController? _ctrl;
  String? _error;
  bool _recording = false;
  double _progress = 0;

  static const _actionText = <String, String>{
    'blink':      'Blink slowly, twice',
    'turn_left':  'Turn your head to your LEFT',
    'turn_right': 'Turn your head to your RIGHT',
    'nod':        'Nod your head up and down',
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(cam, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      setState(() => _ctrl = c);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _record() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _recording) return;
    setState(() { _recording = true; _progress = 0; });

    final frames = <String>[];
    final t0 = DateTime.now();
    final endAt = t0.add(Duration(milliseconds: widget.durationMs));
    final frameInterval = Duration(milliseconds: (1000 / widget.fps).round());

    try {
      while (DateTime.now().isBefore(endAt) && mounted) {
        final xfile = await c.takePicture();
        final bytes = await File(xfile.path).readAsBytes();

        // Optionally re-encode to smaller JPEG
        try {
          final im = img_pkg.decodeImage(bytes);
          if (im != null) {
            final jpg = img_pkg.encodeJpg(im, quality: 75);
            frames.add(base64Encode(jpg));
          } else {
            frames.add(base64Encode(bytes));
          }
        } catch (_) {
          frames.add(base64Encode(bytes));
        }

        await File(xfile.path).delete().catchError((_) => File(''));

        final elapsedMs = DateTime.now().difference(t0).inMilliseconds;
        if (mounted) {
          setState(() => _progress = (elapsedMs / widget.durationMs).clamp(0, 1));
        }
        final nextMs = ((frames.length) * frameInterval.inMilliseconds);
        final waitMs = nextMs - elapsedMs;
        if (waitMs > 0) await Future.delayed(Duration(milliseconds: waitMs));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _recording = false; _progress = 1; });
    }

    if (mounted) widget.onFrames(frames);
  }

  @override
  Widget build(BuildContext context) {
    final actionTitle = _actionText[widget.action] ?? widget.action;

    return Column(
      children: [
        Text(
          'LIVENESS CHALLENGE',
          style: TextStyle(
            color: AppColors.ink400, fontSize: 11,
            letterSpacing: 2, fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(actionTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: AppColors.ink950),
              if (_ctrl?.value.isInitialized == true)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(-1.0, 1.0),
                  child: CameraPreview(_ctrl!),
                ),
              if (_recording)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.ink800,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brandAccent),
                    ),
                  ),
                ),
              if (_error != null)
                Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger)),
                )),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: _recording
              ? 'Recording… ${(_progress * 100).round()}%'
              : 'Record 4s clip',
          icon: Icons.fiber_manual_record,
          onPressed: _ctrl?.value.isInitialized == true ? _record : null,
          loading: _recording,
        ),
      ],
    );
  }
}
