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
    final bool isDisabled = onPressed == null || loading;
    final VoidCallback? effectiveOnPressed = isDisabled ? null : onPressed;

    final Color foregroundColor =
        variant == AppButtonVariant.ghost ? AppColors.ink100 : Colors.white;

    // 1. بناء الأيقونة أو مؤشر التحميل بشكل منفصل
    Widget? buttonIcon;
    if (loading) {
      buttonIcon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      buttonIcon = Icon(icon, size: 18);
    }

    // 2. إعدادات الـ Style الموحدة (تم استبدال الـ Rows بـ minimumSize للـ expand)
    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final EdgeInsets geometryPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final TextStyle textStyle =
        const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1);

    // لضمان التمدد الأفقي الكامل إذا كان expand مفعلاً دون التأثير على الارتفاع
    final Size? minSize = expand ? const Size(double.infinity, 0) : null;

    final Widget labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis, // حماية إضافية لو النص طويل جداً
    );

    // 3. بناء الأزرار باستخدام الـ Built-in Constructors الرسمية
    switch (variant) {
      case AppButtonVariant.ghost:
        final ghostStyle = OutlinedButton.styleFrom(
          padding: geometryPadding,
          shape: buttonShape,
          minimumSize: minSize,
          foregroundColor: foregroundColor,
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          textStyle: textStyle,
        );

        return buttonIcon != null
            ? OutlinedButton.icon(
                onPressed: effectiveOnPressed,
                style: ghostStyle,
                icon: buttonIcon,
                label: labelWidget,
              )
            : OutlinedButton(
                onPressed: effectiveOnPressed,
                style: ghostStyle,
                child: labelWidget,
              );

      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        final Color baseColor = variant == AppButtonVariant.primary
            ? AppColors.brandPrimary
            : AppColors.danger;

        final filledStyle = FilledButton.styleFrom(
          padding: geometryPadding,
          shape: buttonShape,
          minimumSize: minSize,
          foregroundColor: foregroundColor,
          backgroundColor: baseColor,
          disabledBackgroundColor: baseColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          textStyle: textStyle,
        );

        return buttonIcon != null
            ? FilledButton.icon(
                onPressed: effectiveOnPressed,
                style: filledStyle,
                icon: buttonIcon,
                label: labelWidget,
              )
            : FilledButton(
                onPressed: effectiveOnPressed,
                style: filledStyle,
                child: labelWidget,
              );
    }
  }
}
