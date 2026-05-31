import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum PillTone { ok, warn, bad, info, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral});
  final String label;
  final PillTone tone;

  Color get _fg => switch (tone) {
        PillTone.ok      => AppColors.success,
        PillTone.warn    => AppColors.warning,
        PillTone.bad     => AppColors.danger,
        PillTone.info    => AppColors.brandAccent,
        PillTone.neutral => AppColors.ink300,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: _fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: _fg, fontSize: 12, fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}

PillTone kycTone(String s) => switch (s) {
      'AutoVerified' || 'AdminApproved' => PillTone.ok,
      'NeedsReview'  || 'Submitted'     => PillTone.warn,
      'AutoRejected' || 'AdminRejected' => PillTone.bad,
      _ => PillTone.neutral,
    };

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, this.title = 'Something went wrong', required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.w600,
            )),
          ]),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: AppColors.ink200, fontSize: 13)),
        ],
      ),
    );
  }
}
