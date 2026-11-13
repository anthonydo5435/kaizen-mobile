import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../providers/paygrade_detail_controller.dart';

Future<bool> showPaygradeGenerateSheet(
  BuildContext context, {
  required PaygradeDetailController controller,
  required bool hasExistingPaygrades,
}) async {
  final didGenerate = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => PaygradeGenerateSheet(
      controller: controller,
      hasExistingPaygrades: hasExistingPaygrades,
    ),
  );

  return didGenerate == true;
}

class PaygradeGenerateSheet extends StatefulWidget {
  const PaygradeGenerateSheet({
    super.key,
    required this.controller,
    required this.hasExistingPaygrades,
  });

  final PaygradeDetailController controller;
  final bool hasExistingPaygrades;

  @override
  State<PaygradeGenerateSheet> createState() => _PaygradeGenerateSheetState();
}

class _PaygradeGenerateSheetState extends State<PaygradeGenerateSheet> {
  late final _PaygradeGenerateSheetController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = _PaygradeGenerateSheetController(
      hasExistingPaygrades: widget.hasExistingPaygrades,
    );
  }

  Future<void> _submit() async {
    final didGenerate = await _sheetController.submit(widget.controller);
    if (!mounted || !didGenerate) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sheetController,
      builder: (context, _) {
        return PopScope<Object?>(
          canPop: !_sheetController.isSubmitting,
          child: SafeArea(
            top: false,
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                  ),
                  child: AppKeyboardBottomSheetSurface(
                    color: AppColors.surfaceDark,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 560;

                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 18 : 24,
                            isCompact ? 18 : 20,
                            isCompact ? 18 : 24,
                            isCompact ? 20 : 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextView.body1(
                                      AppStrings.paygradesGenerateSheetTitle,
                                      color: AppColors.textPrimary,
                                      fontSize: isCompact ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  _SheetCloseButton(
                                    onTap: _sheetController.isSubmitting
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 14 : 18),
                              const AppDotDivider(),
                              SizedBox(height: isCompact ? 18 : 24),
                              Center(
                                child: AppTextView.body(
                                  AppStrings.paygradesGenerateSheetDescription,
                                  color: AppColors.lightPurple1,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: isCompact ? 18 : 24),
                              _GenerateCountCard(
                                isCompact: isCompact,
                                controller: _sheetController,
                              ),
                              SizedBox(height: isCompact ? 18 : 22),
                              if (_sheetController.hasExistingPaygrades)
                                _GenerateDisclaimerCard(
                                  controller: _sheetController,
                                  isCompact: isCompact,
                                ),
                              if (_sheetController.errorMessage != null) ...[
                                const SizedBox(height: 14),
                                _ErrorCard(
                                  message: _sheetController.errorMessage!,
                                ),
                              ],
                              SizedBox(height: isCompact ? 18 : 22),
                              Align(
                                alignment: isCompact
                                    ? Alignment.center
                                    : Alignment.centerRight,
                                child: SizedBox(
                                  width: isCompact ? double.infinity : 220,
                                  child: AppButton(
                                    text: AppStrings.paygradesRegenerateAction,
                                    onPressed: _sheetController.canSubmit
                                        ? _submit
                                        : null,
                                    isLoading: _sheetController.isSubmitting,
                                    borderRadius: 14,
                                    minimumHeight: 48,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaygradeGenerateSheetController extends ChangeNotifier {
  _PaygradeGenerateSheetController({required this.hasExistingPaygrades}) {
    confirmationController.addListener(_handleConfirmationChanged);
  }

  final bool hasExistingPaygrades;
  final TextEditingController confirmationController = TextEditingController();

  int _numPaygrades = 2;
  bool _isSubmitting = false;
  bool _isConfirmationMatched = false;
  String? _errorMessage;

  int get numPaygrades => _numPaygrades;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get canDecrement => !_isSubmitting && _numPaygrades > 1;
  bool get canIncrement => !_isSubmitting && _numPaygrades < 7;
  bool get canSubmit =>
      !_isSubmitting && (!hasExistingPaygrades || _isConfirmationMatched);

  void decrement() {
    if (!canDecrement) {
      return;
    }

    _numPaygrades -= 1;
    _errorMessage = null;
    notifyListeners();
  }

  void increment() {
    if (!canIncrement) {
      return;
    }

    _numPaygrades += 1;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> submit(PaygradeDetailController controller) async {
    if (!canSubmit) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final didGenerate = await controller.generatePaygradesWithAi(
      numPaygrades: _numPaygrades,
    );

    _isSubmitting = false;
    if (!didGenerate) {
      _errorMessage =
          controller.paygradeGenerationErrorMessage ??
          AppStrings.loginSomethingWentWrong;
    }
    notifyListeners();

    return didGenerate;
  }

  void _handleConfirmationChanged() {
    final isMatched =
        confirmationController.text.trim().toUpperCase() ==
        AppStrings.paygradesGenerateDisclaimerKeyword;
    if (_isConfirmationMatched == isMatched) {
      return;
    }

    _isConfirmationMatched = isMatched;
    notifyListeners();
  }

  @override
  void dispose() {
    confirmationController
      ..removeListener(_handleConfirmationChanged)
      ..dispose();
    super.dispose();
  }
}

class _GenerateCountCard extends StatelessWidget {
  const _GenerateCountCard({required this.isCompact, required this.controller});

  final bool isCompact;
  final _PaygradeGenerateSheetController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.lightPurple1.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          const AppTextView.body1(
            AppStrings.paygradesGenerateCountLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CounterActionButton(
                icon: Icons.remove_rounded,
                onTap: controller.canDecrement ? controller.decrement : null,
              ),
              SizedBox(width: isCompact ? 18 : 24),
              SizedBox(
                width: isCompact ? 72 : 84,
                child: AppTextView.body1(
                  controller.numPaygrades.toString(),
                  color: AppColors.textPrimary,
                  textAlign: TextAlign.center,
                  fontSize: isCompact ? 26 : 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: isCompact ? 18 : 24),
              _CounterActionButton(
                icon: Icons.add_rounded,
                onTap: controller.canIncrement ? controller.increment : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextView.body2(
            AppStrings.paygradesGenerateCountNote,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
            height: 1.4,
          ),
        ],
      ),
    );
  }
}

class _CounterActionButton extends StatelessWidget {
  const _CounterActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.mainBg
                : AppColors.mainBg.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isEnabled
                  ? AppColors.secondaryColor.withValues(alpha: 0.42)
                  : AppColors.fieldBorder.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(
            icon,
            color: isEnabled
                ? AppColors.secondaryColor
                : AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _GenerateDisclaimerCard extends StatelessWidget {
  const _GenerateDisclaimerCard({
    required this.controller,
    required this.isCompact,
  });

  final _PaygradeGenerateSheetController controller;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.lightPurple1.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isCompact ? 48 : 54,
                height: isCompact ? 48 : 54,
                decoration: BoxDecoration(
                  color: AppColors.hex543541,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.hexf1cec7,
                  size: isCompact ? 24 : 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body1(
                      AppStrings.paygradesGenerateDisclaimerTitle,
                      color: AppColors.hexf8d4cf,
                      fontSize: isCompact ? 16 : 17,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    AppTextView.body(
                      AppStrings.paygradesGenerateDisclaimerSubtitle,
                      color: AppColors.textPrimary,
                      fontSize: isCompact ? 14 : 15,
                      height: 1.45,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16 : 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 18,
              vertical: isCompact ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: AppColors.hex342833,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.hex5b4151.withValues(alpha: 0.9),
              ),
            ),
            child: AppTextView.body(
              AppStrings.paygradesGenerateDisclaimerDetails,
              color: AppColors.hexf6d3cb,
              fontSize: isCompact ? 14 : 15,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: isCompact ? 16 : 20),
          AppTextView.body(
            AppStrings.paygradesGenerateDisclaimerInstruction,
            color: AppColors.textPrimary,
            fontSize: isCompact ? 14 : 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          const SizedBox(height: 16),
          _ConfirmationField(
            controller: controller.confirmationController,
            isCompact: isCompact,
            enabled: !controller.isSubmitting,
          ),
        ],
      ),
    );
  }
}

class _ConfirmationField extends StatelessWidget {
  const _ConfirmationField({
    required this.controller,
    required this.isCompact,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool isCompact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: isCompact ? 62 : 72),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 18),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightPurple1.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 1,
        textCapitalization: TextCapitalization.characters,
        textAlignVertical: TextAlignVertical.center,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: isCompact ? 16 : 18,
          fontWeight: FontWeight.w500,
          letterSpacing: isCompact ? 2.6 : 3.2,
        ),
        cursorColor: AppColors.textPrimary,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: AppStrings.paygradesGenerateDisclaimerHint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.72),
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w500,
            letterSpacing: isCompact ? 2.6 : 3.2,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red1.withValues(alpha: 0.28)),
      ),
      child: AppTextView.body2(
        message,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}
