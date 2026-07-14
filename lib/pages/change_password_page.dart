import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';

enum _PwStep { currentPassword, newPassword, success }

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  _PwStep _step = _PwStep.currentPassword;
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  void _goBack() {
    setState(() {
      _error = null;
      _step = _PwStep.currentPassword;
      _currentPwController.clear();
      _newPwController.clear();
      _confirmPwController.clear();
    });
  }

  Future<void> _verifyCurrentPassword() async {
    final pw = _currentPwController.text.trim();
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
      if (mounted) setState(() => _step = _PwStep.newPassword);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not verify password. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPw = _newPwController.text.trim();
    final confirmPw = _confirmPwController.text.trim();

    if (newPw.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final currentPw = _currentPwController.text.trim();
      await ref.read(authApiProvider).changePassword(currentPw, newPw);
      if (mounted) {
        setState(() => _step = _PwStep.success);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'Could not update password. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _PwStep.success ? 'Password Updated' : 'Change Password'),
        centerTitle: true,
        forceMaterialTransparency: true,
        leading: _step != _PwStep.success
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_step == _PwStep.newPassword) {
                    setState(() {
                      _error = null;
                      _step = _PwStep.currentPassword;
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
                current: _step == _PwStep.currentPassword
                    ? 0
                    : _step == _PwStep.newPassword
                        ? 1
                        : 2,
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
      case _PwStep.currentPassword:
        return _buildCurrentPasswordStep();
      case _PwStep.newPassword:
        return _buildNewPasswordStep();
      case _PwStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildCurrentPasswordStep() {
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
            'Enter your current password to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink400, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            InlineAlert(message: _error!, type: AlertType.danger),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _currentPwController,
            obscureText: _obscureCurrent,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Current Password',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.ink400),
                onPressed: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Verify Password',
              icon: Icons.check_circle_outline,
              onPressed: _verifyCurrentPassword,
              loading: _busy,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordStep() {
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
            child: const Icon(Icons.lock_reset,
                color: AppColors.brandPrimary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Create New Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Choose a strong password you haven\'t used before.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink400, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            InlineAlert(message: _error!, type: AlertType.danger),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _newPwController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              helperText: 'At least 8 characters',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.ink400),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPwController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.ink400),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Update Password',
              icon: Icons.check_circle_outline,
              onPressed: _updatePassword,
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
            const Text('Password Updated Successfully',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Your password has been changed. You will need to log in again with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Go to Login',
                onPressed: () async {
                  await ref
                      .read(authControllerProvider.notifier)
                      .clearSession();
                  if (context.mounted) context.go('/login');
                },
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
