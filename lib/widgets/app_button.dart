import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum AppButtonVariant { primary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...const [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink100),
          ),
          SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label, style: const TextStyle(
          fontWeight: FontWeight.w600, letterSpacing: 0.1,
        )),
      ],
    );

    final padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    switch (variant) {
      case AppButtonVariant.primary:
        return Opacity(
          opacity: disabled ? 0.5 : 1,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: disabled ? null : [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                    blurRadius: 18, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: child,
              ),
            ),
          ),
        );

      case AppButtonVariant.ghost:
        return OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            foregroundColor: AppColors.ink100,
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: child,
        );

      case AppButtonVariant.danger:
        return ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: child,
        );
    }
  }
}
