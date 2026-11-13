import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';

class DescriptionTextCommentDialog extends StatefulWidget {
  const DescriptionTextCommentDialog({super.key, required this.onSave});

  final Future<void> Function(String comment) onSave;

  @override
  State<DescriptionTextCommentDialog> createState() => _DescriptionTextCommentDialogState();
}

class _DescriptionTextCommentDialogState extends State<DescriptionTextCommentDialog> {
  final TextEditingController _controller = TextEditingController();
  late final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isSavingNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _isSavingNotifier]),
      builder: (context, _) {
        final isSaving = _isSavingNotifier.value;
        final canSave = _controller.text.trim().isNotEmpty && !isSaving;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: AppDialogStyle.border,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppTextView.body1(
                        AppStrings.auditAddComment,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppOverlayCloseButton(
                      onTap: isSaving ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextView.body2(
                  AppStrings.comment,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 4,
                  enabled: !isSaving,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppColors.secondaryColor,
                  decoration: InputDecoration(
                    hintText: AppStrings.enterComment,
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.secondaryColor),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.grey1.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: AppStrings.saveComment,
                  onPressed: canSave ? _save : null,
                  isLoading: isSaving,
                  backgroundColor: canSave ? AppColors.secondaryColor : AppColors.grey1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final comment = _controller.text.trim();
    if (comment.isEmpty || _isSavingNotifier.value) {
      return;
    }

    _isSavingNotifier.value = true;
    try {
      await widget.onSave(comment);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('Unable to create text comment: $error');
      if (!mounted) {
        return;
      }
      _isSavingNotifier.value = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppTextView.body(AppStrings.loginSomethingWentWrong)));
    }
  }
}
