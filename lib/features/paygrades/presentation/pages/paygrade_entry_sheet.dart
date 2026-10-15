import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/paygrade_detail.dart';

typedef PaygradeEntrySaveCallback =
    Future<void> Function({
      required String title,
      required String description,
      required String promotionRequirement,
      String? payRate,
    });

enum PaygradeEntrySheetMode { create, update }

Future<bool> showPaygradeEntryBottomSheet(
  BuildContext context, {
  PaygradeEntry? entry,
  PaygradeEntrySheetMode mode = PaygradeEntrySheetMode.update,
  required PaygradeEntrySaveCallback onSave,
}) async {
  final didSave = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _PaygradeEntryBottomSheet(entry: entry, mode: mode, onSave: onSave),
  );

  return didSave == true;
}

class _PaygradeEntryBottomSheet extends StatefulWidget {
  const _PaygradeEntryBottomSheet({
    this.entry,
    required this.mode,
    required this.onSave,
  });

  final PaygradeEntry? entry;
  final PaygradeEntrySheetMode mode;
  final PaygradeEntrySaveCallback onSave;

  @override
  State<_PaygradeEntryBottomSheet> createState() =>
      _PaygradeEntryBottomSheetState();
}

class _PaygradeEntryBottomSheetState extends State<_PaygradeEntryBottomSheet> {
  late final _PaygradeEntrySheetController _controller;

  bool get _isCreateMode => widget.mode == PaygradeEntrySheetMode.create;

  @override
  void initState() {
    super.initState();
    _controller = _PaygradeEntrySheetController(
      entry: widget.entry,
      mode: widget.mode,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final didSave = await _controller.submit(widget.onSave);
    if (!mounted || !didSave) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return PopScope<Object?>(
          canPop: !_controller.isSaving,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: FractionallySizedBox(
              heightFactor: 0.86,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.fieldBorder.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextView.body1(
                              _isCreateMode
                                  ? AppStrings.paygradesCreateSheetTitle
                                  : AppStrings.paygradesEditSheetTitle,
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _PaygradeSheetCloseButton(
                            onTap: _controller.isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: AppDotDivider(),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
                      child: Center(
                        child: AppTextView.body(
                          _isCreateMode
                              ? AppStrings.paygradesCreateSheetDescription
                              : AppStrings.paygradesEditSheetDescription,
                          color: AppColors.lightPurple1,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppTextView.body2(
                              AppStrings.paygradesNameLabel,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _PaygradeSheetTextField(
                              controller: _controller.titleController,
                              hintText: AppStrings.paygradesNameHint,
                              enabled: !_controller.isSaving,
                            ),
                            const SizedBox(height: 18),
                            const AppTextView.body2(
                              AppStrings.paygradesRate,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _PaygradeSheetTextField(
                              controller: _controller.payRateController,
                              hintText: AppStrings.paygradesPayRateInputLabel,
                              enabled: !_controller.isSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            const AppTextView.body2(
                              AppStrings.paygradesDescription,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _PaygradeSheetTextField(
                              controller: _controller.descriptionController,
                              hintText: AppStrings.paygradesDescriptionHint,
                              enabled: !_controller.isSaving,
                              maxLines: 5,
                              fontSize: 15,
                              hintFontSize: 15,
                            ),
                            const SizedBox(height: 18),
                            const AppTextView.body2(
                              AppStrings.paygradesPromotionRequirement,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _PaygradeSheetTextField(
                              controller:
                                  _controller.promotionRequirementController,
                              hintText:
                                  AppStrings.paygradesPromotionRequirementHint,
                              enabled: !_controller.isSaving,
                              maxLines: 5,
                              fontSize: 15,
                              hintFontSize: 15,
                            ),
                            if (_controller.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _PaygradeSheetErrorCard(
                                message: _controller.errorMessage!,
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: _isCreateMode
                                    ? AppStrings.seatProfileCreateAction
                                    : AppStrings.seatProfileSaveAction,
                                onPressed: _controller.canSave ? _submit : null,
                                isLoading: _controller.isSaving,
                                borderRadius: 14,
                                minimumHeight: 50,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaygradeEntrySheetController extends ChangeNotifier {
  _PaygradeEntrySheetController({required this.mode, PaygradeEntry? entry})
    : _initialPayRate = entry?.payRate.trim() ?? '',
      titleController = TextEditingController(text: entry?.title ?? ''),
      payRateController = TextEditingController(text: entry?.payRate ?? ''),
      descriptionController = TextEditingController(
        text: entry?.description ?? '',
      ),
      promotionRequirementController = TextEditingController(
        text: entry?.promotionRequirement ?? '',
      ) {
    titleController.addListener(_handleChanged);
    payRateController.addListener(_handleChanged);
    descriptionController.addListener(_handleChanged);
    promotionRequirementController.addListener(_handleChanged);
  }

  final PaygradeEntrySheetMode mode;
  final String _initialPayRate;
  final TextEditingController titleController;
  final TextEditingController payRateController;
  final TextEditingController descriptionController;
  final TextEditingController promotionRequirementController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  bool get canSave =>
      !_isSaving &&
      (mode == PaygradeEntrySheetMode.update ||
          titleController.text.trim().isNotEmpty);
  String? get errorMessage => _errorMessage;

  String? get _payRateToSave {
    final rate = payRateController.text.trim();
    if (mode == PaygradeEntrySheetMode.create) {
      return rate.isEmpty ? null : rate;
    }
    return rate != _initialPayRate ? rate : null;
  }

  Future<bool> submit(PaygradeEntrySaveCallback onSave) async {
    final validationMessage = _validate();
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await onSave(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        promotionRequirement: promotionRequirementController.text.trim(),
        payRate: _payRateToSave,
      );
      return true;
    } catch (error) {
      _errorMessage = _payRateToSave != null
          ? AppStrings.paygradesPayRateSaveFailed
          : error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String? _validate() {
    if (mode == PaygradeEntrySheetMode.create &&
        titleController.text.trim().isEmpty) {
      return AppStrings.paygradesNameRequired;
    }

    final rate = _payRateToSave;
    if (rate != null && !PaygradeEntry.isValidPayRate(rate)) {
      return AppStrings.paygradesPayRateInvalid;
    }

    return null;
  }

  void _handleChanged() {
    if (_errorMessage != null) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    titleController
      ..removeListener(_handleChanged)
      ..dispose();
    payRateController
      ..removeListener(_handleChanged)
      ..dispose();
    descriptionController
      ..removeListener(_handleChanged)
      ..dispose();
    promotionRequirementController
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }
}

class _PaygradeSheetTextField extends StatelessWidget {
  const _PaygradeSheetTextField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.maxLines = 1,
    this.fontSize = 16,
    this.hintFontSize = 16,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final int maxLines;
  final double fontSize;
  final double hintFontSize;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        cursorColor: AppColors.textPrimary,
        cursorHeight: 15,
        style: TextStyle(color: AppColors.textPrimary, fontSize: fontSize),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.grey1,
            fontSize: hintFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PaygradeSheetErrorCard extends StatelessWidget {
  const _PaygradeSheetErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red1.withValues(alpha: 0.24)),
      ),
      child: AppTextView.body3(
        message,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _PaygradeSheetCloseButton extends StatelessWidget {
  const _PaygradeSheetCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}
