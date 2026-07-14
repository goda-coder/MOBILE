import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/state/providers.dart';
import 'package:wallet/widgets/status_pill.dart';

import '../api/api_client.dart';
import '../models/fraud_result.dart';
import '../models/transfer_data.dart';
import '../theme/colors.dart';
import '../utils/pin_verification.dart';
import '../widgets/app_button.dart';

class TransferConfirmationPage extends ConsumerStatefulWidget {
  const TransferConfirmationPage({super.key, required this.data});
  final TransferData data;

  @override
  ConsumerState<TransferConfirmationPage> createState() =>
      _TransferConfirmationPageState();
}

class _TransferConfirmationPageState
    extends ConsumerState<TransferConfirmationPage> {
  bool _busy = false;
  String? _recipientName;
  FraudCheckResult? _fraudResult;
  bool _isFraudLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _runFraudCheck();
  }

  Future<void> _loadDetails() async {
    try {
      final name = await ref
          .read(walletApiProvider)
          .validateRecipient(widget.data.recipient);
      if (mounted) {
        setState(() => _recipientName = name);
      }
    } catch (e) {
      setState(() => _error = 'Could not load recipient details.');
    }
  }

  Future<void> _runFraudCheck() async {
    setState(() => _isFraudLoading = true);
    try {
      final result =
          await ref.read(fraudApiProvider).checkTransfer(widget.data);
      if (mounted) {
        setState(() {
          _fraudResult = result;
          _isFraudLoading = false;
        });
      }
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _isFraudLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fraud check failed: $e';
        _isFraudLoading = false;
      });
    }
  }

  String _maskName(String name) {
    if (name.isEmpty) return 'Unknown';
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0] + '*' * (word.length - 1);
    }).join(' ');
  }

  Future<void> _confirm() async {
    final verified = await verifyPinSheet(context, ref);
    if (!verified || !mounted) return;

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      await ref.read(walletApiProvider).transfer(
            recipientIdentifier: widget.data.recipient,
            amountMinor: widget.data.amountMinor,
            reference: widget.data.idempotencyRef,
            description: widget.data.description,
          );
      if (mounted) context.go('/');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm =
        !_isFraudLoading && _fraudResult?.riskLevel == 'LOW';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Transfer'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 12),
              ],
              // Transfer Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recipient',
                          style:
                              TextStyle(color: AppColors.ink400, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: AppColors.brandPrimary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _recipientName == null
                                ? 'Loading...'
                                : _maskName(_recipientName!),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _row(
                          'Amount',
                          widget.data.amountFormatted,
                          AppColors.brandPrimary,
                          Icons.monetization_on_outlined),
                      if (widget.data.description != null &&
                          widget.data.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _row('Description', widget.data.description!,
                            AppColors.ink300, Icons.notes_rounded),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Fraud Detection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: AppColors.brandPrimary, size: 20),
                          SizedBox(width: 8),
                          Text('Security Check',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isFraudLoading) ...[
                        const Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.brandSecondary),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text('Analyzing transaction...',
                                  style: TextStyle(
                                      color: AppColors.ink400, fontSize: 13)),
                            ],
                          ),
                        )
                      ] else if (_fraudResult != null) ...[
                        _buildFraudStatus(),
                      ] else ...[
                        const Text('Security check failed to initialize.'),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Confirm Transfer',
                  icon: Icons.check_circle_outline,
                  onPressed: canConfirm ? _confirm : null,
                  loading: _busy,
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

  Widget _buildFraudStatus() {
    final level = _fraudResult?.riskLevel ?? 'UNKNOWN';
    final prob = _fraudResult?.probability ?? 0;
    final reasons = _fraudResult?.reasons ?? [];

    Color statusColor = AppColors.success;
    String statusText = 'Safe';
    IconData statusIcon = Icons.check_circle_outline;

    if (level == 'MEDIUM' || level == 'HIGH') {
      statusColor = AppColors.warning;
      statusText = 'Risk Detected';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Text(statusText,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${prob.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: AppColors.ink400)),
          ],
        ),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 4, color: AppColors.ink500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.text,
                          style: const TextStyle(
                              color: AppColors.ink400, fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
      ],
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    ]);
  }
}
