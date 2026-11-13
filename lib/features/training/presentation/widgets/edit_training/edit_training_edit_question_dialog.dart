part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _EditQuestionDialog extends StatefulWidget {
  const _EditQuestionDialog({required this.question, required this.moduleId});

  final SeatDescriptionTrainingQuestion question;
  final String? moduleId;

  @override
  State<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<_EditQuestionDialog> {
  late final TrainingQuizQuestionEditorController _editor;

  @override
  void initState() {
    super.initState();
    _editor = TrainingQuizQuestionEditorController(question: widget.question)
      ..startEditing();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  bool _canEdit(TrainingModuleController controller) =>
      controller.canManageTraining &&
      controller.selectedModuleId == widget.moduleId &&
      controller.selectedModuleQuestions.any(
        (question) => question.uuid == widget.question.uuid,
      );

  Future<void> _submit() async {
    final controller = context.read<TrainingModuleController>();
    if (!_canEdit(controller) ||
        controller.isSavingQuestion(widget.question.uuid) ||
        controller.isDeletingQuestion(widget.question.uuid)) {
      return;
    }

    final validation = _editor.validate(widget.question);
    if (validation != null) {
      _editor.setValidationMessage(validation);
      return;
    }

    final saved = await controller.saveQuestion(
      questionId: widget.question.uuid,
      options: _editor.buildOptions(widget.question),
      correctOptionUuid: _editor.selectedCorrectOptionUuid,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      final error = controller.questionsErrorMessage?.trim();
      if (error != null && error.isNotEmpty)
        _editor.setValidationMessage(error);
    }
  }

  Future<void> _confirmRemoveOption(String optionUuid) async {
    final controller = context.read<TrainingModuleController>();
    if (!_canEdit(controller) ||
        controller.isSavingQuestion(widget.question.uuid) ||
        controller.isDeletingQuestion(widget.question.uuid)) {
      return;
    }

    FocusScope.of(context).unfocus();
    final confirmed = await showTrainingOptionDeleteDialog(context);
    if (!mounted ||
        !confirmed ||
        !_canEdit(controller) ||
        controller.isSavingQuestion(widget.question.uuid) ||
        controller.isDeletingQuestion(widget.question.uuid)) {
      return;
    }

    if (_editor.showsDraftOption && _editor.draftOptionUuid == optionUuid) {
      _editor.removeDraftOption(widget.question);
    } else {
      _editor.removeExistingOption(optionUuid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final isSaving = controller.isSavingQuestion(widget.question.uuid);
    final isBusy =
        isSaving || controller.isDeletingQuestion(widget.question.uuid);
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top -
        16;

    return AnimatedBuilder(
      animation: _editor,
      builder: (context, _) => PopScope(
        canPop: !isBusy,
        child: Padding(
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
                child: _EditQuestionForm(
                  question: widget.question,
                  editor: _editor,
                  isEnabled: _canEdit(controller) && !isBusy,
                  isSaving: isSaving,
                  onSave: _submit,
                  onRemoveOption: _confirmRemoveOption,
                  onClose: isBusy ? null : () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditQuestionForm extends StatelessWidget {
  const _EditQuestionForm({
    required this.question,
    required this.editor,
    required this.isEnabled,
    required this.isSaving,
    required this.onSave,
    required this.onRemoveOption,
    required this.onClose,
  });

  final SeatDescriptionTrainingQuestion question;
  final TrainingQuizQuestionEditorController editor;
  final bool isEnabled;
  final bool isSaving;
  final VoidCallback onSave;
  final ValueChanged<String> onRemoveOption;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionSheetHeader(
          title: AppStrings.trainingEditQuestionTitle,
          onClose: onClose,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuizQuestionPrompt(question: question),
                const SizedBox(height: 16),
                _EditQuestionOptions(
                  question: question,
                  editor: editor,
                  isEnabled: isEnabled,
                  onRemove: onRemoveOption,
                ),
                const SizedBox(height: 16),
                _QuestionCorrectAnswerSelector(
                  label: editor.correctAnswerLabel,
                  onPrevious: isEnabled && editor.canChangeCorrectAnswer
                      ? editor.previousCorrectAnswer
                      : null,
                  onNext: isEnabled && editor.canChangeCorrectAnswer
                      ? editor.nextCorrectAnswer
                      : null,
                ),
                if (editor.validationMessage != null) ...[
                  const SizedBox(height: 12),
                  _DialogErrorMessageCard(message: editor.validationMessage!),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
          child: TextButton(
            onPressed: isEnabled && editor.canSave(question: question)
                ? onSave
                : null,
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

class _EditQuestionOptions extends StatelessWidget {
  const _EditQuestionOptions({
    required this.question,
    required this.editor,
    required this.isEnabled,
    required this.onRemove,
  });

  final SeatDescriptionTrainingQuestion question;
  final TrainingQuizQuestionEditorController editor;
  final bool isEnabled;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final options = editor.visibleExistingOptions(question);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...options.asMap().entries.map((entry) {
          final option = entry.value;
          return Padding(
            key: ValueKey(option.uuid),
            padding: const EdgeInsets.only(bottom: 10),
            child: TrainingSwipeDeleteAction(
              deleteSemanticLabel: AppStrings.trainingDeleteOption,
              onDelete: isEnabled ? () => onRemove(option.uuid) : null,
              child: _QuizOptionTile(
                controller: editor.optionControllerFor(option),
                hintText: AppStrings.trainingQuestionOptionHint(entry.key + 1),
                isSelected: editor.isOptionSelected(option.uuid),
                isEditable: isEnabled,
                onTap: isEnabled
                    ? () => editor.selectCorrectOption(option.uuid)
                    : null,
              ),
            ),
          );
        }),
        if (editor.showsDraftOption)
          Padding(
            key: ValueKey(editor.draftOptionUuid),
            padding: const EdgeInsets.only(bottom: 10),
            child: TrainingSwipeDeleteAction(
              deleteSemanticLabel: AppStrings.trainingDeleteOption,
              onDelete: isEnabled
                  ? () => onRemove(editor.draftOptionUuid)
                  : null,
              child: _DraftQuizOptionTile(
                controller: editor.draftOptionController,
                hintText: AppStrings.trainingQuestionOptionHint(
                  options.length + 1,
                ),
                isSelected: editor.isOptionSelected(editor.draftOptionUuid),
                isEditable: isEnabled,
                onSelect: isEnabled
                    ? () => editor.selectCorrectOption(editor.draftOptionUuid)
                    : null,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: _InlineTextAction(
            label: AppStrings.trainingQuestionAddOption,
            icon: Icons.add_rounded,
            onTap: isEnabled ? () => editor.showDraftOption(question) : null,
          ),
        ),
      ],
    );
  }
}
