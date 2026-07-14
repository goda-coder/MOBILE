import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

final _reportProvider = FutureProvider.autoDispose(
  (ref) => ref.read(walletApiProvider).report(),
);

class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(_reportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account report')),
      body: SafeArea(
        child: report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: ErrorCard(message: e.toString())),
          data: (data) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wallet summary',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _ReportRow('Wallet ID', data.wallet.walletId),
                        _ReportRow('Balance',
                            '${formatAmount(data.wallet.balanceMinor)} ${data.wallet.currency}'),
                        _ReportRow('KYC status', data.wallet.kycStatus),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Recent account operations',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...data.operations.map((op) => Card(
                      margin: const EdgeInsets.only(bottom: 13.0),
                      child: ListTile(
                        title: Text(op.description),
                        subtitle: Text(op.kind.name
                            .replaceAll('transferIn', 'Transfer in')
                            .replaceAll('transferOut', 'Transfer out')
                            .replaceAll('topup', 'Top up')
                            .replaceAll('refund', 'Refund')),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatAmount(op.amountMinor),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            StatusPill(op.status,
                                tone: op.status == 'Completed'
                                    ? PillTone.ok
                                    : PillTone.neutral),
                          ],
                        ),
                      ),
                    )),
                if (data.operations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'No account operations found. Use the wallet to start sending or topping up.'),
                  ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Refresh report',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(_reportProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text('$label:',
                  style:
                      const TextStyle(color: AppColors.ink400, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
