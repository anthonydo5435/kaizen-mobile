import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/paygrade_detail.dart';
import '../providers/paygrade_detail_controller.dart';
import '../providers/paygrade_pay_rate_controller.dart';

Future<void> showPaygradePayRateDialog(
  BuildContext context, {
  required PaygradeDetailController controller,
  required PaygradeEntry entry,
  required String title,
}) async {
  if (!controller.canEditPayRate(entry)) return;
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider(
      create: (_) =>
          PaygradePayRateController(entry: entry, detailController: controller),
      child: _PaygradePayRateDialog(title: title),
    ),
  );
}

class _PaygradePayRateDialog extends StatelessWidget {
  const _PaygradePayRateDialog({required this.title});

  final String title;

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final saved = await context.read<PaygradePayRateController>().save();
    if (context.mounted && saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PaygradePayRateController>();
    return PopScope<Object?>(
      canPop: !controller.isSaving,
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cardBg, AppColors.hex111317],
              ),
              borderRadius: BorderRadius.circular(20),
              border: AppDialogStyle.border,
            ),
            child: _PayRateDialogContent(
              title: title,
              controller: controller,
              onSave: () => _save(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayRateDialogContent extends StatelessWidget {
  const _PayRateDialogContent({
    required this.title,
    required this.controller,
    required this.onSave,
  });

  final String title;
  final PaygradePayRateController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextView.title1(
                  title,
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              AppOverlayCloseButton(
                onTap: controller.isSaving
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const AppDotDivider(opacity: 0.4, dotSize: 5),
          const SizedBox(height: 24),
          _PayRateInput(controller: controller, onSave: onSave),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            AppTextView.body2(controller.errorMessage!, color: AppColors.red1),
          ],
          const SizedBox(height: 24),
          Center(
            child: _PayRateSaveButton(
              isSaving: controller.isSaving,
              onSave: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayRateInput extends StatelessWidget {
  const _PayRateInput({required this.controller, required this.onSave});

  final PaygradePayRateController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTextView.body1(
          AppStrings.paygradesPayRateInputLabel,
          color: AppColors.lightPurple2,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller.rateController,
          enabled: !controller.isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSave(),
          cursorColor: AppColors.textPrimary,
          cursorHeight: 15,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceDark3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayRateSaveButton extends StatelessWidget {
  const _PayRateSaveButton({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondaryColor, AppColors.purple1],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondaryColor),
        ),
        child: TextButton(
          onPressed: isSaving ? null : onSave,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: !isSaving,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: const AppTextView.body(
                  AppStrings.seatProfileSaveAction,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSaving)
                const Positioned.fill(
                  child: Center(
                    child: FastCircularProgressIndicator(width: 18, height: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
