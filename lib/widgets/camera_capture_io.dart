import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/image_data.dart';
import '../theme/colors.dart';
import 'app_button.dart';

class CameraCapture extends StatefulWidget {
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
  State<CameraCapture> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No cameras available on this device.');
        return;
      }
      final cam = _cameras.firstWhere(
        (c) => widget.front
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final ctrl = CameraController(
        cam, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) { await ctrl.dispose(); return; }
      setState(() {
        _controller = ctrl;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = _humanise(e));
    }
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('CameraAccessDenied')) return 'Camera permission was denied. Enable it in system settings.';
    if (s.contains('CameraAccessRestricted')) return 'Camera access is restricted on this device.';
    return 'Camera error: $s';
  }

  Future<void> _snap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final xfile = await c.takePicture();
      widget.onCaptured(ImageData.fromFile(File(xfile.path)));
    } catch (e) {
      if (mounted) setState(() => _error = _humanise(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.ink950),
                if (_controller != null && _controller!.value.isInitialized)
                  // Mirror the front camera preview so it feels like a mirror.
                  Transform(
                    alignment: Alignment.center,
                    transform: widget.front
                        ? (Matrix4.identity()..scale(-1.0, 1.0))
                        : Matrix4.identity(),
                    child: CameraPreview(_controller!),
                  ),
                if (widget.faceGuide && _controller != null && _controller!.value.isInitialized)
                  const _FaceGuideOverlay(),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  )
                else if (_controller == null)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          AppButton(label: 'Capture', icon: Icons.camera_alt, onPressed: _snap, loading: _busy),
        ]),
      ],
    );
  }
}

class _FaceGuideOverlay extends StatefulWidget {
  const _FaceGuideOverlay();

  @override
  State<_FaceGuideOverlay> createState() => _FaceGuideOverlayState();
}

class _FaceGuideOverlayState extends State<_FaceGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + (0.04 * _pulse.value);
        return CustomPaint(
          painter: _FaceGuidePainter(scale: scale),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  _FaceGuidePainter({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalRect = Rect.fromCenter(
      center: center,
      width:  size.width * 0.55 * scale,
      height: size.height * 0.75 * scale,
    );
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addOval(ovalRect);
    final maskPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.brandAccent.withValues(alpha: 0.9),
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'Position your face inside the oval',
        style: TextStyle(color: Color(0xCCF2EEF7), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 24);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 28));
  }

  @override
  bool shouldRepaint(_FaceGuidePainter old) => old.scale != scale;
}
