import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';

enum _PinStep { currentPassword, newPin, success }

class ResetPinPage extends ConsumerStatefulWidget {
  const ResetPinPage({super.key});
  @override
  ConsumerState<ResetPinPage> createState() => _ResetPinPageState();
}

class _ResetPinPageState extends ConsumerState<ResetPinPage> {
  _PinStep _step = _PinStep.currentPassword;
  final _passwordController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscurePin = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _goBack() {
    setState(() {
      _error = null;
      _step = _PinStep.currentPassword;
      _passwordController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
    });
  }

  Future<void> _verifyPassword() async {
    final pw = _passwordController.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = 'Please enter your current password.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(authApiProvider).verifyPassword(pw);
      if (mounted) setState(() => _step = _PinStep.newPin);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not verify password. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePin() async {
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
      setState(() => _error = 'PIN must be exactly 6 digits.');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final pw = _passwordController.text.trim();
      await ref.read(authApiProvider).resetPin(pw, newPin);
      await ref.read(authControllerProvider.notifier).setPinCreated();
      if (mounted) setState(() => _step = _PinStep.success);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not update PIN. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _PinStep.success ? 'PIN Updated' : 'Reset Security PIN'),
        centerTitle: true,
        forceMaterialTransparency: true,
        leading: _step != _PinStep.success
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_step == _PinStep.newPin) {
                    setState(() {
                      _error = null;
                      _step = _PinStep.currentPassword;
                    });
                  } else {
                    context.pop();
                  }
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _StepIndicator(
                steps: 3,
                current: _step == _PinStep.currentPassword
                    ? 0
                    : _step == _PinStep.newPin ? 1 : 2,
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildStepContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _PinStep.currentPassword:
        return _buildPasswordStep();
      case _PinStep.newPin:
        return _buildNewPinStep();
      case _PinStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                color: AppColors.brandPrimary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Verify Your Identity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Enter your current password to reset the Security PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink400, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            InlineAlert(message: _error!, type: AlertType.danger),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Current Password',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.ink400),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Verify Password',
              icon: Icons.check_circle_outline,
              onPressed: _verifyPassword,
              loading: _busy,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPinStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pin,
                color: AppColors.brandPrimary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Create New Security PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Enter a new 6-digit PIN. Avoid common patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink400, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            InlineAlert(message: _error!, type: AlertType.danger),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _newPinController,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                color: AppColors.ink100),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                  fontSize: 28,
                  letterSpacing: 8,
                  color: AppColors.ink500),
              labelText: 'New PIN',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPinController,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                color: AppColors.ink100),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                  fontSize: 28,
                  letterSpacing: 8,
                  color: AppColors.ink500),
              labelText: 'Confirm PIN',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _obscurePin = !_obscurePin),
              icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.ink400),
              label: Text(
                  _obscurePin ? 'Show PIN' : 'Hide PIN',
                  style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Update PIN',
              icon: Icons.check_circle_outline,
              onPressed: _updatePin,
              loading: _busy,
              expand: true,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _goBack,
            child: const Text('Go back',
                style: TextStyle(color: AppColors.ink400)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('PIN Updated Successfully',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Your Security PIN has been changed. The new PIN is now active for all payment confirmations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Return to Profile',
                onPressed: () => context.go('/profile'),
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});
  final int steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(
            width: 32,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i ~/ 2 < current
                  ? AppColors.brandPrimary
                  : AppColors.ink500,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx <= current;
        final isDone = idx < current;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.brandPrimary
                : isActive
                    ? AppColors.brandPrimary.withValues(alpha: 0.2)
                    : AppColors.ink700,
            border: isActive && !isDone
                ? Border.all(color: AppColors.brandPrimary, width: 2)
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${idx + 1}',
                    style: TextStyle(
                      color: isActive ? AppColors.brandPrimary : AppColors.ink400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
          ),
        );
      }),
    );
  }
}
