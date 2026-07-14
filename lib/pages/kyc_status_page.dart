import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

final _statusProvider = FutureProvider.autoDispose(
  (ref) => ref.read(kycApiProvider).myStatus(),
);

class KycStatusPage extends ConsumerWidget {
  const KycStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_statusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity status'),
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorCard(message: e.toString()),
          ),
          data: (s) {
            if (s.status == 'None') {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Verify once. Unlocks higher limits, payment top-ups, and merchant features.",
                        style: TextStyle(color: AppColors.ink400),
                      ),
                      const SizedBox(height: 16),
                      Card(
                          child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  "You haven't started verification yet.",
                                  style: TextStyle(color: AppColors.ink300)),
                              const SizedBox(height: 16),
                              AppButton(
                                  label: 'Start verification',
                                  onPressed: () => context.push('/kyc/submit')),
                            ]),
                      )),
                    ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('Your latest submission',
                          style: TextStyle(color: AppColors.ink400))),
                  StatusPill(s.status, tone: kycTone(s.status)),
                ]),
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    _Row('Verified', s.isVerified ? 'Yes' : 'No'),
                    if (s.submittedAt != null)
                      _Row('Submitted', formatDateTime(s.submittedAt!)),
                    if (s.decidedAt != null)
                      _Row('Decided', formatDateTime(s.decidedAt!)),
                    if (s.decisionReason != null)
                      _Row('Reason', s.decisionReason!, multiline: true),
                  ]),
                )),
                if (s.status == 'Pending') ...[
                  const SizedBox(height: 16),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pending review',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text(
                              'Your submission has been sent to the admin for manual review. Please check back later for approval.',
                              style: TextStyle(color: AppColors.ink400)),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Refresh status',
                            onPressed: () => ref.invalidate(_statusProvider),
                            variant: AppButtonVariant.ghost,
                          ),
                        ]),
                  )),
                ],
                if (s.warnings != null && s.warnings!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warnings',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          for (final w in s.warnings!) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  ',
                                        style:
                                            TextStyle(color: AppColors.ink400)),
                                    Expanded(
                                        child: Text(w,
                                            style: const TextStyle(
                                                color: AppColors.ink300,
                                                fontSize: 13))),
                                  ]),
                            ),
                          ],
                        ]),
                  )),
                ],
                const SizedBox(height: 16),
                Wrap(spacing: 8, children: [
                  if (!s.isVerified)
                    AppButton(
                        label: 'Resubmit',
                        onPressed: () => context.push('/kyc/submit')),
                  AppButton(
                      label: 'Active liveness',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.push('/kyc/liveness')),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.multiline = false});
  final String label, value;
  final bool multiline;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.ink400,
                      letterSpacing: 1.5,
                      fontSize: 11))),
          Expanded(
              child: Text(value,
                  maxLines: multiline ? null : 1,
                  overflow:
                      multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink100))),
        ],
      ),
    );
  }
}
