import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallet/theme/colors.dart';
import 'package:wallet/widgets/inline_alert.dart';
import 'package:wallet/widgets/status_pill.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

enum _Method { card, wallet, fingerprint }

class TopUpPage extends ConsumerStatefulWidget {
  const TopUpPage({super.key, this.method});
  final String? method;

  @override
  ConsumerState<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends ConsumerState<TopUpPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Method _method = _Method.card;

  final _amount = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController(text: '+201');
  final _walletPhone = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final method = widget.method?.toLowerCase();
    int initialIndex = 0;
    if (method == 'wallet') {
      _method = _Method.wallet;
      initialIndex = 1;
    } else if (method == 'fingerprint') {
      _method = _Method.fingerprint;
      initialIndex = 2;
    }

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _method = _Method.card;
            break;
          case 1:
            _method = _Method.wallet;
            break;
          case 2:
            _method = _Method.fingerprint;
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _walletPhone.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (minor > 1000000) {
      setState(() => _error = 'Max top-up is 10,000 EGP per transaction.');
      return;
    }

    setState(() => _busy = true);
    try {
      final email = ref.read(authControllerProvider).value?.phoneNumber ?? '';
      final r = await ref.read(paymentsApiProvider).checkout(
            amountMinor: minor,
            method: _method == _Method.card
                ? 'card'
                : _method == _Method.wallet
                    ? 'wallet'
                    : 'fingerprint',
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: email,
            phoneNumber: _phone.text.trim(),
            walletPhoneNumber:
                _method == _Method.wallet ? _walletPhone.text.trim() : null,
          );

      if (_method == _Method.fingerprint) {
        if (mounted) {
          context.go(
            '/fingerprint-auth?paymentIntentId=${Uri.encodeQueryComponent(r.paymentIntentId)}',
          );
        }
        return;
      }

      final url = r.iframeUrl ?? r.walletRedirectUrl;
      if (url == null) {
        setState(() => _error = 'Gateway did not return a checkout URL.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not start checkout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Top up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Add funds to your wallet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Powered by Paymob · Your card details are never stored',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink400,
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 12),
              ],

              // Tabs (method selector)
              Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.darkTheme.colorScheme.surfaceContainerHigh),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.credit_card, size: 20),
                      text: 'Card',
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_wallet, size: 20),
                      text: 'Wallet',
                    ),
                    Tab(
                      icon: Icon(Icons.fingerprint, size: 20),
                      text: 'Fingerprint',
                    ),
                  ],
                  labelColor: AppColors.brandPrimary,
                  unselectedLabelColor: AppColors.ink500,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  indicator: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(6),
                ),
              ),
              const SizedBox(height: 20),

              // Form card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppTheme.darkTheme.colorScheme.outline
                        .withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                color: AppTheme.darkTheme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      if (_method == _Method.fingerprint)
                        const InlineAlert(
                          message:
                              'Fingerprint payments use the ZK9500 device. Live payment is 10 EGP or more.',
                          type: AlertType.warning,
                        ),
                      const SizedBox(height: 20),

                      // Name fields
                      Row(
                        children: [
                          Expanded(
                            child: AppInput(
                              controller: _first,
                              label: 'First name',
                              hint: "eg. Ahmed",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              controller: _last,
                              label: 'Last name',
                              hint: "eg. khalid",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Phone number
                      AppInput(
                        controller: _phone,
                        label: 'Phone',
                        keyboardType: TextInputType.phone,
                        hint: '+201001234567',
                      ),

                      // Wallet phone (conditional)
                      if (_method == _Method.wallet) ...[
                        const SizedBox(height: 20),
                        AppInput(
                          controller: _walletPhone,
                          label: 'Wallet phone (11 digits)',
                          keyboardType: TextInputType.phone,
                          hint: '01001234567',
                          helper:
                              'The phone number linked to your Vodafone/Etisalat/Orange wallet.',
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: _method == _Method.card
                              ? 'Continue to card'
                              : _method == _Method.wallet
                                  ? 'Continue to mobile wallet'
                                  : 'Continue to fingerprint',
                          onPressed: _submit,
                          loading: _busy,
                          expand: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Footer note
                      const InlineAlert(
                        message:
                            'Your wallet will be credited automatically after Paymob confirmation.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
