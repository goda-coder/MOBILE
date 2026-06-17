import 'package:flutter/material.dart';
import 'package:wallet/theme/colors.dart';

enum AlertType { success, info, warning, danger }

class InlineAlert extends StatelessWidget {
  const InlineAlert({
    super.key,
    required this.message,
    this.title,
    this.type = AlertType.info,
  });

  final String? title;
  final String message;
  final AlertType type;

  Color get _bg => switch (type) {
        AlertType.success => AppColors.successBg,
        AlertType.info => AppColors.infoBg,
        AlertType.warning => AppColors.warningBg,
        AlertType.danger => AppColors.dangerBg,
      };

  Color get _border => switch (type) {
        AlertType.success => AppColors.successBorder,
        AlertType.info => AppColors.infoBorder,
        AlertType.warning => AppColors.warningBorder,
        AlertType.danger => AppColors.dangerBorder,
      };

  Color get _text => switch (type) {
        AlertType.success => AppColors.successText,
        AlertType.info => AppColors.infoText,
        AlertType.warning => AppColors.warningText,
        AlertType.danger => AppColors.dangerText,
      };

  IconData get _icon => switch (type) {
        AlertType.success => Icons.check_circle_outline_rounded,
        AlertType.info => Icons.info_outline_rounded,
        AlertType.warning => Icons.warning_amber_rounded,
        AlertType.danger => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border, width: 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: _text),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: _text.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
