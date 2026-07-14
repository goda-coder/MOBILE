import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/camera_capture.dart';
import '../widgets/status_pill.dart';
import '../models/image_data.dart';

enum _Step { docType, idFront, idBack, selfie, review, done }

class KycSubmitPage extends ConsumerStatefulWidget {
  const KycSubmitPage({super.key});
  @override
  ConsumerState<KycSubmitPage> createState() => _KycSubmitPageState();
}

class _KycSubmitPageState extends ConsumerState<KycSubmitPage> {
  String _docType = 'national_id';
  ImageData? _idFront;
  ImageData? _idBack;
  ImageData? _selfie;
  _Step _step = _Step.docType;
  String? _error;
  bool _submitting = false;
  String? _resultStatus;
  double? _resultMatch;

  bool get _isPassport => _docType == 'passport';

  List<_Step> get _steps => _isPassport
      ? [_Step.docType, _Step.idFront, _Step.selfie, _Step.review]
      : [
          _Step.docType,
          _Step.idFront,
          _Step.idBack,
          _Step.selfie,
          _Step.review
        ];

  int get _currentIdx => _steps.indexOf(_step).clamp(0, _steps.length - 1);

  void _next() {
    final i = _currentIdx;
    if (i < _steps.length - 1) setState(() => _step = _steps[i + 1]);
  }

  void _back() {
    final i = _currentIdx;
    if (i > 0) setState(() => _step = _steps[i - 1]);
  }

  Future<void> _submit() async {
    if (_idFront == null || _selfie == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final r = await ref.read(kycApiProvider).submit(
            documentType: _docType,
            idFront: _idFront!,
            idBack: _isPassport ? null : _idBack,
            selfie: _selfie!,
          );
      if (r.status == 'AutoVerified') {
        await ref
            .read(authControllerProvider.notifier)
            .updateKycStatus(true);
      }
      setState(() {
        _resultStatus = r.status;
        _resultMatch = r.matchPercentage;
        _step = _Step.done;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Submission failed.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<ImageData?> _pickImageFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final bytes = await file.readAsBytes();
      return ImageData.fromBytes(bytes, name: file.name);
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
      return null;
    }
  }

  Future<void> _uploadFromDevice(ValueChanged<ImageData> onCaptured) async {
    final image = await _pickImageFromDevice();
    if (image != null && mounted) {
      setState(() => onCaptured(image));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify identity')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Progress bar
            Row(children: [
              for (int i = 0; i < _steps.length - 1; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient:
                          i < _currentIdx ? AppColors.brandGradient : null,
                      color: i < _currentIdx
                          ? null
                          : i == _currentIdx
                              ? AppColors.brandAccent.withValues(alpha: 0.5)
                              : AppColors.ink700,
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorCard(message: _error!),
              const SizedBox(height: 12)
            ],

            Card(
                child: Padding(
              padding: const EdgeInsets.all(18),
              child: _buildStep(),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.docType:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Which document?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _DocTile(
              active: _docType == 'national_id',
              onTap: () => setState(() => _docType = 'national_id'),
              title: 'National ID',
              sub: 'Egyptian card (14-digit)',
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _DocTile(
              active: _docType == 'passport',
              onTap: () => setState(() => _docType = 'passport'),
              title: 'Passport',
              sub: 'MRZ-readable photo page',
            )),
          ]),
          const SizedBox(height: 18),
          AppButton(label: 'Continue', onPressed: _next),
        ]);

      case _Step.idFront:
        return _CapStep(
          title: 'Front of your document',
          sub: 'Hold the card flat. Good lighting. No glare on the photo.',
          faceGuide: false,
          front: false,
          existing: _idFront,
          onCaptured: (f) => setState(() => _idFront = f),
          onUpload: () => _uploadFromDevice((f) => _idFront = f),
          onRetake: () => setState(() => _idFront = null),
          onNext: () => _idFront != null ? _next() : null,
          onBack: _back,
        );

      case _Step.idBack:
        return _CapStep(
          title: 'Back of your document',
          sub: 'The side with the QR / barcode.',
          faceGuide: false,
          front: false,
          existing: _idBack,
          onCaptured: (f) => setState(() => _idBack = f),
          onUpload: () => _uploadFromDevice((f) => _idBack = f),
          onRetake: () => setState(() => _idBack = null),
          onNext: () => _idBack != null ? _next() : null,
          onBack: _back,
        );

      case _Step.selfie:
        return _CapStep(
          title: 'Take a selfie',
          sub:
              'Look straight at the camera. Neutral expression. Remove glasses if possible.',
          faceGuide: true,
          front: true,
          existing: _selfie,
          onCaptured: (f) => setState(() => _selfie = f),
          onUpload: () => _uploadFromDevice((f) => _selfie = f),
          onRetake: () => setState(() => _selfie = null),
          onNext: () => _selfie != null ? _next() : null,
          onBack: _back,
        );

      case _Step.review:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Review & submit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Thumb(file: _idFront, label: 'Front')),
            const SizedBox(width: 8),
            if (!_isPassport) ...[
              Expanded(child: _Thumb(file: _idBack, label: 'Back')),
              const SizedBox(width: 8),
            ],
            Expanded(child: _Thumb(file: _selfie, label: 'Selfie')),
          ]),
          const SizedBox(height: 14),
          const Text(
            'By submitting, you consent to AI processing of these images for identity verification. '
            'You can request deletion via support.',
            style: TextStyle(color: AppColors.ink400, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            AppButton(
              label: 'Send to admin for review',
              onPressed: _idFront != null && _selfie != null ? _submit : null,
              loading: _submitting,
            ),
            AppButton(
                label: 'Back',
                variant: AppButtonVariant.ghost,
                onPressed: _back),
          ]),
        ]);

      case _Step.done:
        final verified = _resultStatus == 'AutoVerified';
        return Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(verified ? Icons.check : Icons.hourglass_top,
                color: verified ? AppColors.success : AppColors.warning,
                size: 32),
          ),
          const SizedBox(height: 16),
          Text(verified ? "You're verified." : 'In review.',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            verified
                ? 'Face match: ${(_resultMatch ?? 0).round()}%. Your wallet now has full features and all operations are open.'
                : 'Your KYC has been sent to the admin for review. You can perform transfers and fingerprint payments once it is approved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink400),
          ),
          const SizedBox(height: 18),
          AppButton(label: 'Back to wallet', onPressed: () => context.go('/')),
        ]);
    }
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile(
      {required this.active,
      required this.onTap,
      required this.title,
      required this.sub});
  final bool active;
  final VoidCallback onTap;
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandPrimary.withValues(alpha: 0.1)
              : AppColors.ink950.withValues(alpha: 0.4),
          border: Border.all(
              color: active
                  ? AppColors.brandPrimary.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _CapStep extends StatelessWidget {
  const _CapStep({
    required this.title,
    required this.sub,
    required this.faceGuide,
    required this.front,
    required this.existing,
    required this.onCaptured,
    required this.onUpload,
    required this.onRetake,
    required this.onNext,
    required this.onBack,
  });

  final String title;
  final String sub;
  final bool faceGuide;
  final bool front;
  final ImageData? existing;
  final ValueChanged<ImageData> onCaptured;
  final Future<void> Function()? onUpload;
  final VoidCallback onRetake;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: AppColors.ink400, fontSize: 13)),
      const SizedBox(height: 14),
      if (existing != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: existing != null
                ? FutureBuilder<Uint8List>(
                    future: existing!.getBytes(),
                    builder: (context, snap) {
                      if (!snap.hasData)
                        return const Center(child: CircularProgressIndicator());
                      return Image.memory(snap.data!,
                          fit: BoxFit.cover, width: double.infinity);
                    })
                : Container(color: AppColors.ink950),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          AppButton(label: 'Looks good', onPressed: onNext),
          AppButton(
              label: 'Retake',
              variant: AppButtonVariant.ghost,
              onPressed: onRetake),
          AppButton(
              label: 'Back',
              variant: AppButtonVariant.ghost,
              onPressed: onBack),
        ]),
      ] else ...[
        CameraCapture(
            faceGuide: faceGuide, front: front, onCaptured: onCaptured),
        const SizedBox(height: 8),
        AppButton(
          label: 'Upload from device',
          icon: Icons.upload_file,
          variant: AppButtonVariant.ghost,
          onPressed: onUpload,
        ),
        const SizedBox(height: 8),
        AppButton(
            label: 'Back', variant: AppButtonVariant.ghost, onPressed: onBack),
      ],
    ]);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.label});
  final ImageData? file;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: AppColors.ink950,
            child: file != null
                ? FutureBuilder<Uint8List>(
                    future: file!.getBytes(),
                    builder: (context, snap) {
                      if (!snap.hasData)
                        return const Center(child: CircularProgressIndicator());
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    })
                : const Center(
                    child: Text('missing',
                        style:
                            TextStyle(color: AppColors.ink400, fontSize: 11))),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
    ]);
  }
}
