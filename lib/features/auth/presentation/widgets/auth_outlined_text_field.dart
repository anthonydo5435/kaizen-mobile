import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_text_view.dart';

class AuthOutlinedTextField extends StatelessWidget {
  const AuthOutlinedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final resolvedErrorText = errorText?.trim();
    final showError = resolvedErrorText != null && resolvedErrorText.isNotEmpty;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.5), width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            enabled: enabled,
            readOnly: readOnly,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textSecondary),
            cursorColor: AppColors.textPrimary,
            cursorHeight: 18,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: labelText,
              labelStyle: const TextStyle(color: AppColors.fieldBorder),
              filled: true,
              fillColor: Colors.transparent,
              enabledBorder: inputBorder,
              disabledBorder: inputBorder,
              focusedBorder: inputBorder.copyWith(
                borderSide: const BorderSide(color: AppColors.textPrimary, width: 1),
              ),
              border: showError
                  ? inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.red))
                  : inputBorder,
              errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.red)),
              focusedErrorBorder: inputBorder.copyWith(
                borderSide: const BorderSide(color: AppColors.red),
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: showError
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: AppTextView.body4(resolvedErrorText, color: AppColors.red1, fontSize: 10),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
