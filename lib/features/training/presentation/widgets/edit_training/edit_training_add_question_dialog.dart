part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _AddQuestionDialog extends StatefulWidget {
  const _AddQuestionDialog({required this.onPickImage});

  final Future<File?> Function() onPickImage;

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  late final TrainingQuestionFormController _formController;

  @override
  void initState() {
    super.initState();
    _formController = TrainingQuestionFormController(
      minOptionCount: TrainingModuleController.minQuizOptionsPerQuestion,
      maxOptionCount: TrainingModuleController.maxQuizOptionsPerQuestion,
    );
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  void _removeOption(TextEditingController option) {
    final controller = context.read<TrainingModuleController>();
    if (!controller.canAddQuestionToSelectedModule ||
        controller.isAddingQuestion ||
        _formController.isPickingImage) {
      return;
    }

    FocusScope.of(context).unfocus();
    final index = _formController.optionControllers.indexOf(option);
    if (index >= 0) _formController.removeOptionField(index);
  }

  Future<void> _submit() async {
    final trainingController = context.read<TrainingModuleController>();
    if (trainingController.isAddingQuestion || _formController.isPickingImage)
      return;

    final validationMessage = _formController.validate();
    if (validationMessage != null) {
      _formController.setValidationMessage(validationMessage);
      return;
    }

    final didAdd = await trainingController.addQuestionToSelectedModule(
      questionText: _formController.questionController.text.trim(),
      optionTexts: _formController.optionControllers
          .map((controller) => controller.text.trim())
          .toList(growable: false),
      correctOptionIndex: _formController.selectedCorrectOptionIndex,
      questionImage: _formController.questionImage,
    );
    if (!mounted) return;
    if (!didAdd) {
      final errorMessage = trainingController.questionsErrorMessage?.trim();
      if (errorMessage != null && errorMessage.isNotEmpty) {
        _formController.setValidationMessage(errorMessage);
      }
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top -
        16;

    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: AppKeyboardBottomSheetSurface(
          width: double.infinity,
          color: AppColors.trainingLessonActionSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: availableHeight.clamp(
                0.0,
                mediaQuery.size.height * 0.92,
              ),
            ),
            child: SafeArea(
              top: false,
              child: _AddQuestionForm(
                form: _formController,
                isSaving: controller.isAddingQuestion,
                canSubmit: controller.canAddQuestionToSelectedModule,
                onPickImage: () =>
                    _formController.pickQuestionImage(widget.onPickImage),
                onRemoveOption: _removeOption,
                onSubmit: _submit,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddQuestionForm extends StatelessWidget {
  const _AddQuestionForm({
    required this.form,
    required this.isSaving,
    required this.canSubmit,
    required this.onPickImage,
    required this.onRemoveOption,
    required this.onSubmit,
    required this.onClose,
  });

  final TrainingQuestionFormController form;
  final bool isSaving;
  final bool canSubmit;
  final VoidCallback onPickImage;
  final ValueChanged<TextEditingController> onRemoveOption;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isBusy = isSaving || form.isPickingImage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionSheetHeader(
          title: AppStrings.trainingAddNewQuestion,
          onClose: onClose,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionTextField(
                  controller: form.questionController,
                  isEnabled: !isBusy,
                ),
                const SizedBox(height: 16),
                _QuestionPictureField(
                  image: form.questionImage,
                  isPicking: form.isPickingImage,
                  onPick: isBusy ? null : onPickImage,
                  onRemove: isBusy ? null : form.removeQuestionImage,
                ),
                const SizedBox(height: 26),
                _QuestionOptionsList(
                  form: form,
                  isEnabled: !isBusy && canSubmit,
                  onRemove: onRemoveOption,
                ),
                const SizedBox(height: 16),
                _QuestionCorrectAnswerSelector(
                  label: form.correctAnswerLabel,
                  onPrevious: !isBusy && form.canChangeCorrectAnswer
                      ? form.previousCorrectAnswer
                      : null,
                  onNext: !isBusy && form.canChangeCorrectAnswer
                      ? form.nextCorrectAnswer
                      : null,
                ),
                if (form.validationMessage != null) ...[
                  const SizedBox(height: 16),
                  _DialogErrorMessageCard(message: form.validationMessage!),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
          child: TextButton(
            onPressed: !isBusy && canSubmit ? onSubmit : null,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              disabledBackgroundColor: AppColors.secondaryColor.withValues(
                alpha: 0.55,
              ),
              foregroundColor: AppColors.textPrimary,
              disabledForegroundColor: AppColors.textPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSaving
                ? const FastCircularProgressIndicator()
                : const AppTextView.body(
                    AppStrings.trainingSaveAction,
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuestionSheetHeader extends StatelessWidget {
  const _QuestionSheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppTextView.body1(
                  title,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              AppOverlayCloseButton(onTap: onClose),
            ],
          ),
          const SizedBox(height: 18),
          const AppDotDivider(color: AppColors.fieldBorder, opacity: 0.34),
        ],
      ),
    );
  }
}
