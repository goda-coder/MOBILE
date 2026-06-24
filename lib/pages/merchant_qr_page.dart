import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';
import '../services/discovery_service.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/inline_alert.dart';
import '../widgets/status_pill.dart';

class MerchantQrPage extends ConsumerStatefulWidget {
  const MerchantQrPage({super.key});
  @override
  ConsumerState<MerchantQrPage> createState() => _MerchantQrPageState();
}

class _MerchantQrPageState extends ConsumerState<MerchantQrPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // -- QR tab fields --
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _payload;
  int? _minorShown;

  // -- Fingerprint tab fields --
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _phoneController = TextEditingController(text: '+20');
  final _fingerAmountController = TextEditingController();
  String? _fingerError;
  bool _fingerBusy = false;
  String? _fingerStatus;
  final _discoveredDevices = <DiscoveredDevice>[];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedHost();
  }

  Future<void> _loadSavedHost() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('merchant_host');
    if (saved != null && saved.isNotEmpty) {
      _hostController.text = saved;
    }
  }

  Future<void> _saveHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('merchant_host', host);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amount.dispose();
    _note.dispose();
    _hostController.dispose();
    _phoneController.dispose();
    _fingerAmountController.dispose();
    super.dispose();
  }

  // -- QR tab logic --

  Future<void> _generate() async {
    final isKycVerified =
        await ref.read(isKycVerifiedProvider.future).catchError((_) => false);
    if (!isKycVerified) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('KYC Verification Required'),
            content: const Text(
                'You must complete your identity verification before you can generate merchant QR codes.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) context.push('/kyc/status');
                },
                child: const Text('Go to KYC'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) return;
    final merchantId =
        ref.read(authControllerProvider).value?.userId ?? 'unknown';
    final uri = Uri(
      scheme: 'wallet-pay',
      host: merchantId,
      queryParameters: {
        'amountMinor': minor.toString(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'v': '1',
      },
    );
    setState(() {
      _payload = uri.toString();
      _minorShown = minor;
    });
  }

  // -- Fingerprint tab logic --

  Future<void> _submitFingerprintPayment() async {
    final phone = _phoneController.text.trim();
    final amountText = _fingerAmountController.text.trim();

    if (phone.isEmpty) {
      setState(() => _fingerError = 'Enter the customer phone number');
      return;
    }
    if (amountText.isEmpty) {
      setState(() => _fingerError = 'Enter the amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _fingerError = 'Enter a valid amount');
      return;
    }

    final auth = ref.read(authControllerProvider).value;
    final merchantId = auth?.phoneNumber;
    if (merchantId == null || merchantId.isEmpty) {
      setState(() => _fingerError = 'Merchant phone not found. Sign in again.');
      return;
    }

    setState(() {
      _fingerError = null;
      _fingerBusy = true;
      _fingerStatus = null;
    });

    final status = await ref
        .read(biometricPaymentServiceProvider.notifier)
        .initiatePayment(
          merchantId: merchantId,
          targetUserId: phone,
          amountEgp: amount,
        );

    if (!mounted) return;

    setState(() {
      _fingerBusy = false;
      _fingerStatus = status;
    });

    if (status == "SUCCESS") {
      context.pushReplacement('/payment-success');
    } else if (status == "FAILED" || status == "TIMEOUT") {
      setState(() => _fingerError = status == "TIMEOUT"
          ? 'Transaction timed out. The customer may not have responded.'
          : 'Transaction failed.');
    }
  }

  Future<void> _scanForServers() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });
    try {
      final devices = await DiscoveryService().discover();
      if (mounted) {
        setState(() => _discoveredDevices.addAll(devices));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fingerError = 'Discovery failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authControllerProvider).value?.role;
    final showFingerprint = role == Role.merchant || role == Role.admin;

    return Scaffold(
      body: SafeArea(
        child: showFingerprint
            ? Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
                      Tab(icon: Icon(Icons.fingerprint), text: 'Fingerprint'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildQrTab(),
                        _buildFingerprintTab(),
                      ],
                    ),
                  ),
                ],
              )
            : _buildQrTab(),
      ),
    );
  }

  Widget _buildQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const InlineAlert(
          message:
              "Show the customer this QR. They scan it from their wallet to pay you.",
        ),
        const SizedBox(height: 16),
        Card(
            child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Amount',
                style: TextStyle(
                    color: AppColors.ink300,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTheme.numTextStyle(fontSize: 26),
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'EGP',
                suffixStyle: AppTheme.numTextStyle(
                    color: AppColors.ink400, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            AppInput(
                controller: _note,
                label: 'Note (optional)',
                hint: "What's this for?"),
            const SizedBox(height: 16),
            AppButton(
                expand: true,
                label: 'Generate QR',
                onPressed: _generate,
                icon: Icons.qr_code),
          ]),
        )),
        if (_payload != null && _minorShown != null) ...[
          const SizedBox(height: 16),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _payload!,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('REQUESTING',
                  style: TextStyle(
                      color: AppColors.ink400, letterSpacing: 2, fontSize: 11)),
              const SizedBox(height: 4),
              Text(formatMoney(_minorShown!),
                  style: AppTheme.numTextStyle(fontSize: 24)),
              if (_note.text.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_note.text.trim(),
                    style:
                        const TextStyle(color: AppColors.ink400, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Text(_payload!,
                  textAlign: TextAlign.center,
                  style: AppTheme.numTextStyle(
                      color: AppColors.ink500, fontSize: 10)),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _buildFingerprintTab() {
    final state = ref.watch(biometricPaymentServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Merchant System Connection',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Merchant System IP',
                          hintText: 'e.g. 192.168.1.100',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (val) => _saveHost(val.trim()),
                      ),
                    ),
                    if (!state.isConnected) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: IconButton.outlined(
                          padding: EdgeInsets.zero,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search, size: 20),
                          onPressed: _isScanning ? null : _scanForServers,
                          tooltip: 'Scan for merchant systems',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Connection',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const Spacer(),
                      StatusPill(
                        state.isConnected ? 'Connected' : 'Disconnected',
                        tone:
                            state.isConnected ? PillTone.ok : PillTone.neutral,
                      ),
                    ],
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  InlineAlert(
                    message: state.errorMessage!,
                    type: AlertType.danger,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: state.isConnected ? "Disconnect" : "Connect",
                    icon: state.isConnected
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    variant: state.isConnected
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    loading: state.isProcessing,
                    onPressed: state.isProcessing
                        ? null
                        : () async {
                            if (state.isConnected) {
                              await ref
                                  .read(
                                      biometricPaymentServiceProvider.notifier)
                                  .disconnectFromMerchant();
                            } else {
                              final host = _hostController.text.trim();
                              if (host.isEmpty) return;
                              await ref
                                  .read(
                                      biometricPaymentServiceProvider.notifier)
                                  .connectToMerchant(host);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_discoveredDevices.isNotEmpty && !state.isConnected) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Discovered Servers',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._discoveredDevices.map(
                    (device) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      leading: const Icon(Icons.computer, size: 20),
                      title: Text(device.name),
                      subtitle: Text('${device.host}:${device.port}'),
                      trailing: const Icon(Icons.link, size: 18),
                      onTap: () {
                        _hostController.text = device.host;
                        _saveHost(device.host);
                        ref
                            .read(biometricPaymentServiceProvider.notifier)
                            .connectToMerchant(device.host, port: device.port);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Payment Request',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                AppInput(
                  controller: _phoneController,
                  label: 'Customer phone number',
                  hint: '+201001234567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _fingerAmountController,
                  label: 'Amount (EGP)',
                  hint: 'e.g. 150.00',
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                ),
                const SizedBox(height: 20),
                if (_fingerError != null) ...[
                  InlineAlert(message: _fingerError!, type: AlertType.danger),
                  const SizedBox(height: 16),
                ],
                if (_fingerStatus == "PENDING") ...[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Waiting for merchant device…'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (!state.isConnected) ...[
                  const InlineAlert(
                    message:
                        'Not connected to merchant system. Connect from the panel above or the profile page first.',
                    type: AlertType.warning,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: _fingerStatus == "PENDING"
                        ? 'Processing…'
                        : 'Send Payment Request',
                    icon: Icons.send,
                    loading: _fingerBusy,
                    onPressed: (_fingerBusy || !state.isConnected)
                        ? null
                        : _submitFingerprintPayment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
