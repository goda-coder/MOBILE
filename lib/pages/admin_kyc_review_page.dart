import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

final _pendingProvider = FutureProvider.autoDispose(
  (ref) => ref.read(adminApiProvider).pendingKyc(skip: 0, take: 50),
);

class AdminKycReviewPage extends ConsumerStatefulWidget {
  const AdminKycReviewPage({super.key});
  @override
  ConsumerState<AdminKycReviewPage> createState() => _AdminKycReviewPageState();
}

class _AdminKycReviewPageState extends ConsumerState<AdminKycReviewPage> {
  String? _selectedId;
  final _reason = TextEditingController(text: 'Manually verified.');
  String? _err;
  bool _busy = false;

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  Future<void> _act(bool approve) async {
    if (_selectedId == null || _reason.text.trim().isEmpty) return;
    setState(() { _busy = true; _err = null; });
    try {
      final api = ref.read(adminApiProvider);
      if (approve) {
        await api.approve(_selectedId!, _reason.text.trim());
      } else {
        await api.reject(_selectedId!, _reason.text.trim());
      }
      ref.invalidate(_pendingProvider);
      setState(() { _selectedId = null; _reason.text = 'Manually verified.'; });
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } catch (_) {
      setState(() => _err = approve ? 'Approval failed.' : 'Rejection failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(_pendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('KYC review queue')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_pendingProvider);
            await Future.delayed(const Duration(milliseconds: 250));
          },
          child: pending.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [ErrorCard(message: e.toString())],
            ),
            data: (list) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_err != null) ...[ErrorCard(message: _err!), const SizedBox(height: 12)],
                if (list.isEmpty)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(child: Text('Nothing in the queue. Take a coffee break ☕',
                        style: TextStyle(color: AppColors.ink400))),
                  ))
                else
                  Card(child: Column(
                    children: [
                      for (int i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(list[i].fullName ?? 'Unknown name',
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(list[i].id.substring(0, 8).padRight(8, '0') + '…',
                                      style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
                                ],
                              )),
                              if (list[i].warnings.isEmpty)
                                const StatusPill('clean', tone: PillTone.ok)
                              else
                                StatusPill('${list[i].warnings.length} warning(s)', tone: PillTone.warn),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              _MetaCol(label: 'Match', value: '${list[i].matchPercentage.round()}%'),
                              const SizedBox(width: 16),
                              _MetaCol(label: 'Submitted', value: formatRelative(list[i].submittedAt)),
                              const Spacer(),
                              AppButton(
                                label: _selectedId == list[i].id ? 'Cancel' : 'Review',
                                variant: _selectedId == list[i].id
                                    ? AppButtonVariant.primary
                                    : AppButtonVariant.ghost,
                                onPressed: () => setState(() {
                                  _selectedId = _selectedId == list[i].id ? null : list[i].id;
                                }),
                              ),
                            ]),
                          ]),
                        ),
                      ],
                    ],
                  )),

                if (_selectedId != null) ...[
                  const SizedBox(height: 14),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Reviewing ${_selectedId!.substring(0, 12)}…',
                          style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
                      const SizedBox(height: 10),
                      AppInput(
                        controller: _reason, label: 'Reason',
                        helper: 'Recorded in the audit trail.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, children: [
                        AppButton(label: 'Approve', onPressed: () => _act(true), loading: _busy),
                        AppButton(label: 'Reject', variant: AppButtonVariant.danger,
                            onPressed: () => _act(false), loading: _busy),
                      ]),
                    ]),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
        style: const TextStyle(color: AppColors.ink400, fontSize: 10, letterSpacing: 1.5)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 13)),
    ]);
  }
}
