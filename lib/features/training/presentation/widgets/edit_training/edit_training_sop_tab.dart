part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _SopTabContent extends StatelessWidget {
  const _SopTabContent({
    required this.isLoading,
    required this.canManageGeneration,
    required this.canGenerate,
    required this.isGeneratingSop,
    required this.canEditDocument,
    required this.isSavingDocument,
    required this.documentHtml,
    required this.editorKey,
    required this.editorControllerBuilder,
    required this.onGenerateSopTap,
    required this.onDoneTap,
    this.errorMessage,
  });

  final bool isLoading;
  final bool canManageGeneration;
  final bool canGenerate;
  final bool isGeneratingSop;
  final bool canEditDocument;
  final bool isSavingDocument;
  final String documentHtml;
  final Key editorKey;
  final String? errorMessage;
  final TrainingSopEditorController Function() editorControllerBuilder;
  final VoidCallback onGenerateSopTap;
  final VoidCallback onDoneTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _buildContent();
        if (constraints.hasBoundedHeight) return content;
        return SizedBox(height: MediaQuery.sizeOf(context).height * 0.65, child: content);
      },
    );
  }

  Widget _buildContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 12,
        overflowSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: AppTextView.body1(
                  AppStrings.trainingCreateSop,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isSavingDocument) ...[
                const SizedBox(width: 12),
                const FastCircularProgressIndicator(width: 16, height: 16),
              ],
            ],
          ),
          if (canManageGeneration)
            AppAiGenerateButton(
              label: AppStrings.trainingCreateWithAi,
              isEnabled: canGenerate,
              isLoading: isGeneratingSop,
              onTap: onGenerateSopTap,
              showOutline: true,
              maxLines: null,
            ),
        ],
      ),
      const SizedBox(height: 24),
      Expanded(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: _buildDocument(),
        ),
      ),
    ],
  );

  Widget _buildDocument() {
    if (isLoading) {
      return const Center(child: FastCircularProgressIndicator(color: AppColors.secondaryColor));
    }
    if (errorMessage != null && documentHtml.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppTextView.body1(errorMessage!, color: AppColors.mainBg),
        ),
      );
    }
    if (!canEditDocument) {
      if (documentHtml.isEmpty) {
        return const Center(
          child: AppTextView.body1(AppStrings.trainingNoSopAvailable, color: AppColors.mainBg),
        );
      }
      return TrainingSopReader(html: documentHtml);
    }
    return ChangeNotifierProvider<TrainingSopEditorController>.value(
      key: editorKey,
      value: editorControllerBuilder(),
      child: _TrainingSopEditor(onDoneTap: onDoneTap, errorMessage: errorMessage),
    );
  }
}

class _TrainingSopEditor extends StatelessWidget {
  const _TrainingSopEditor({required this.onDoneTap, this.errorMessage});

  final VoidCallback onDoneTap;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingSopEditorController>();
    final error = errorMessage ?? controller.errorMessage;
    return Column(
      children: [
        Expanded(child: TrainingSopDocumentView(controller: controller)),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppTextView.body1(error, color: AppColors.mainBg),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: _TrainingSopFormattingToolbar(controller: controller, onDoneTap: onDoneTap),
        ),
      ],
    );
  }
}

/// Keeps the existing compact toolbar while routing formatting through Tiptap.
class _TrainingSopFormattingToolbar extends StatelessWidget {
  const _TrainingSopFormattingToolbar({required this.controller, required this.onDoneTap});

  final TrainingSopEditorController controller;
  final VoidCallback onDoneTap;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    descendantsAreFocusable: false,
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.18)),
            ),
            child: StreamBuilder<EditorStatePayload>(
              stream: controller.editor.editorStateStream,
              initialData: controller.editor.editorState,
              builder: (context, snapshot) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buttons(snapshot.data),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 44,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: AppStrings.done,
              onPressed: () {
                if (View.of(context).viewInsets.bottom > 0) {
                  unawaited(controller.dismissKeyboard());
                  onDoneTap();
                }
              },
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 26),
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _buttons(EditorStatePayload? state) =>
      [
        (AppStrings.trainingBoldAction, Icons.format_bold_rounded, EditorCommand.toggleBold),
        (AppStrings.trainingItalicAction, Icons.format_italic_rounded, EditorCommand.toggleItalic),
        (AppStrings.trainingUnderlineAction, Icons.format_underline_rounded, 'toggleUnderline'),
        (
          AppStrings.trainingBulletListAction,
          Icons.format_list_bulleted_rounded,
          EditorCommand.toggleBulletList,
        ),
        (
          AppStrings.trainingNumberedListAction,
          Icons.format_list_numbered_rounded,
          EditorCommand.toggleOrderedList,
        ),
        (
          AppStrings.trainingQuoteAction,
          Icons.format_quote_rounded,
          EditorCommand.toggleBlockquote,
        ),
        (AppStrings.trainingHeadingAction, Icons.title_rounded, EditorCommand.toggleHeading),
      ].map((button) {
        final (tooltip, icon, command) = button;
        return _TrainingFormattingButton(
          tooltip: tooltip,
          icon: icon,
          isCompact: true,
          isActive: state?.commandStates[command]?.isActive ?? false,
          onTap: controller.isReady
              ? () => controller.format(
                  command,
                  command == EditorCommand.toggleHeading ? {'level': 2} : null,
                )
              : null,
        );
      }).toList();
}
