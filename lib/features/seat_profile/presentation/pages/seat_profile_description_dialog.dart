import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';

Future<bool> showSeatAdditionDialogue(
  BuildContext context, {
  required Future<void> Function(String descriptionName) onSave,
}) async {
  final didSave = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SeatAdditionDialogue(onSave: onSave),
  );

  return didSave == true;
}

class SeatAdditionDialogue extends StatefulWidget {
  const SeatAdditionDialogue({super.key, required this.onSave});

  final Future<void> Function(String descriptionName) onSave;

  @override
  State<SeatAdditionDialogue> createState() => _SeatAdditionDialogueState();
}

class _SeatAdditionDialogueState extends State<SeatAdditionDialogue> {
  late final _SeatAdditionDialogueController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _SeatAdditionDialogueController();
  }

  Future<void> _submit() async {
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
        return PopScope<Object?>(
          canPop: !_controller.isSaving,
          child: Dialog(
            backgroundColor: AppColors.surfaceDark,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: AppDialogStyle.shape(radius: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: AppTextView.body1(
                            AppStrings.seatProfileSeatAdditionDialogTitle,
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _SeatAdditionDialogCloseButton(
                          onTap: _controller.isSaving ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const AppDotDivider(),
                    const SizedBox(height: 22),
                    const Center(
                      child: AppTextView.body(
                        AppStrings.seatProfileSeatAdditionDialogDescription,
                        color: AppColors.lightPurple1,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const AppTextView.body2(
                      AppStrings.seatProfileSeatDescriptionNameLabel,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 10),
                    _SeatAdditionField(controller: _controller),
                    const SizedBox(height: 12),
                    const AppTextView.body3(
                      AppStrings.seatProfileSeatDescriptionValidationNote,
                      color: AppColors.grey1,
                      height: 1.4,
                    ),
                    if (_controller.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _SeatAdditionErrorCard(message: _controller.errorMessage!),
                    ],
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 180,
                        child: AppButton(
                          text: AppStrings.seatProfileSaveAction,
                          onPressed: _controller.canSave ? _submit : null,
                          isLoading: _controller.isSaving,
                          borderRadius: 14,
                          minimumHeight: 48,
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

class _SeatAdditionDialogueController extends ChangeNotifier {
  _SeatAdditionDialogueController() {
    nameController.addListener(_handleNameChanged);
  }

  final TextEditingController nameController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get canSave => !_isSaving && nameController.text.trim().isNotEmpty;

  Future<bool> submit(Future<void> Function(String descriptionName) onSave) async {
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
      await onSave(nameController.text.trim());
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String? _validate() {
    final value = nameController.text.trim();
    if (value.isEmpty) {
      return AppStrings.seatProfileSeatDescriptionNameRequired;
    }

    if (_countWords(value) > 7) {
      return AppStrings.seatProfileSeatDescriptionNameWordLimit;
    }

    return null;
  }

  void _handleNameChanged() {
    if (_errorMessage == null) {
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    super.dispose();
  }
}

class _SeatAdditionField extends StatelessWidget {
  const _SeatAdditionField({required this.controller});

  final _SeatAdditionDialogueController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.28)),
      ),
      child: TextField(
        controller: controller.nameController,
        enabled: !controller.isSaving,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.textPrimary,
        decoration: const InputDecoration(
          hintText: AppStrings.seatProfileSeatDescriptionNameHint,
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _SeatAdditionErrorCard extends StatelessWidget {
  const _SeatAdditionErrorCard({required this.message});

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
      child: AppTextView.body2(message, color: AppColors.textPrimary, height: 1.4),
    );
  }
}

class _SeatAdditionDialogCloseButton extends StatelessWidget {
  const _SeatAdditionDialogCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}

int _countWords(String value) {
  return value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
}
