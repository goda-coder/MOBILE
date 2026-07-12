import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/transfer_data.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';

class RecipientConfirmationPage extends StatelessWidget {
  const RecipientConfirmationPage({super.key, required this.data});
  final TransferData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm recipient'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recipient',
                          style: TextStyle(
                              color: AppColors.ink400, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: AppColors.brandPrimary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(data.recipient,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _row('Amount', data.amountFormatted,
                          AppColors.brandPrimary, Icons.monetization_on_outlined),
                      if (data.description != null &&
                          data.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _row('Description', data.description!,
                            AppColors.ink300, Icons.notes_rounded),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Confirm Transaction',
                  icon: Icons.check_circle_outline,
                  onPressed: () =>
                      context.push('/pin-code', extra: data),
                  expand: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color iconColor, IconData icon) {
    return Row(children: [
      Icon(icon, color: iconColor, size: 20),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(color: AppColors.ink400, fontSize: 13)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500)),
    ]);
  }
}
