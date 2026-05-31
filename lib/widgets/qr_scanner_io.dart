import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/colors.dart';

/// Continuously scans for QR codes. Calls [onScan] exactly once with the first
/// decoded payload, then stops. Renders a tinted viewfinder with brand-coloured
/// corner brackets for affordance.
class AppQrScanner extends StatefulWidget {
  const AppQrScanner({super.key, required this.onScan});
  final void Function(String payload) onScan;

  @override
  State<AppQrScanner> createState() => _AppQrScannerState();
}

class _AppQrScannerState extends State<AppQrScanner> {
  late final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _fired = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_fired) return;
    final v = cap.barcodes.firstOrNull?.rawValue;
    if (v == null || v.isEmpty) return;
    _fired = true;
    _ctrl.stop();
    widget.onScan(v);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          IgnorePointer(child: CustomPaint(painter: _ViewfinderPainter())),
        ]),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.18;
    final r = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    final paint = Paint()
      ..color = AppColors.brandAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const cornerLen = 24.0;
    // TL
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(cornerLen, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, cornerLen), paint);
    // TR
    canvas.drawLine(r.topRight, r.topRight - const Offset(cornerLen, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, cornerLen), paint);
    // BL
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(cornerLen, 0), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft - const Offset(0, cornerLen), paint);
    // BR
    canvas.drawLine(r.bottomRight, r.bottomRight - const Offset(cornerLen, 0), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight - const Offset(0, cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
