import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(
            color: AppColors.ink300, fontSize: 13, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
        if (error == null && helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
        ],
      ],
    );
  }
}
