part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _SopTabContent extends StatelessWidget {
  const _SopTabContent({
    required this.isLoading,
    required this.canManageGeneration,
    required this.canGenerate,
    required this.isGeneratingSop,
    required this.canEditDocument,
    required this.isSavingDocument,
    required this.showPdf,
    required this.canViewPdf,
    required this.isOpeningPdf,
    required this.documentHtml,
    required this.editorKey,
    required this.editorControllerBuilder,
    required this.onGenerateSopTap,
    required this.onViewPdfTap,
    required this.onDoneTap,
    this.onExitLandscape,
    this.errorMessage,
  });

  final bool isLoading;
  final bool canManageGeneration;
  final bool canGenerate;
  final bool isGeneratingSop;
  final bool canEditDocument;
  final bool isSavingDocument;
  final bool showPdf;
  final bool canViewPdf;
  final bool isOpeningPdf;
  final String documentHtml;
  final Key editorKey;
  final String? errorMessage;
  final TrainingSopEditorController Function() editorControllerBuilder;
  final VoidCallback onGenerateSopTap;
  final VoidCallback onViewPdfTap;
  final VoidCallback onDoneTap;
  final VoidCallback? onExitLandscape;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _buildContent(
          isLandscape: MediaQuery.orientationOf(context) == Orientation.landscape,
        );
        if (constraints.hasBoundedHeight) return content;
        return SizedBox(height: MediaQuery.sizeOf(context).height * 0.65, child: content);
      },
    );
  }

  Widget _buildContent({required bool isLandscape}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Offstage(
        offstage: isLandscape,
        child: SafeArea(
          top: false,
          bottom: false,
          left: !isLandscape,
          right: !isLandscape,
          minimum: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 0),
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: isLandscape ? 4 : 12,
            overflowSpacing: isLandscape ? 2 : 8,
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
                  minHeight: isLandscape ? 32 : null,
                  outerPadding: EdgeInsets.all(isLandscape ? 2 : 6),
                  contentPadding: isLandscape
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                      : const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                ),
            ],
          ),
        ),
      ),
      SizedBox(height: isLandscape ? 0 : 24),
      Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 0),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildDocument(isLandscape: isLandscape),
                if (isLandscape && onExitLandscape != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      type: MaterialType.transparency,
                      child: IconButton(
                        key: const ValueKey('sop-exit-fullscreen-button'),
                        tooltip: AppStrings.trainingExitFullscreen,
                        onPressed: onExitLandscape,
                        iconSize: 36,
                        padding: const EdgeInsets.all(6),
                        icon: Ink(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildDocument({required bool isLandscape}) {
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
    final pdfButton = showPdf
        ? _SopPdfButton(isEnabled: canViewPdf, isLoading: isOpeningPdf, onTap: onViewPdfTap)
        : null;
    if (!canEditDocument) {
      if (documentHtml.isEmpty) {
        return const Center(
          child: AppTextView.body1(AppStrings.trainingNoSopAvailable, color: AppColors.mainBg),
        );
      }
      return Column(
        children: [
          Expanded(child: TrainingSopReader(html: documentHtml)),
          if (pdfButton != null)
            Offstage(
              offstage: isLandscape,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Align(alignment: Alignment.centerRight, child: pdfButton),
              ),
            ),
        ],
      );
    }
    return ChangeNotifierProvider<TrainingSopEditorController>.value(
      key: editorKey,
      value: editorControllerBuilder(),
      child: _TrainingSopEditor(
        onDoneTap: onDoneTap,
        pdfButton: pdfButton,
        errorMessage: errorMessage,
      ),
    );
  }
}

class _SopPdfButton extends StatelessWidget {
  const _SopPdfButton({required this.isEnabled, required this.isLoading, required this.onTap});

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: Material(
      color: AppColors.lightPurple3.withAlpha(899),
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        key: const ValueKey('sop-view-pdf-button'),
        tooltip: AppStrings.trainingViewSopPdf,
        onPressed: isEnabled ? onTap : null,
        padding: EdgeInsets.zero,
        icon: SizedBox.square(
          dimension: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isLoading ? 0 : 1,
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 28,
                  color: AppColors.purple2,
                ),
              ),
              if (isLoading)
                const FastCircularProgressIndicator(
                  width: 18,
                  height: 18,
                  color: AppColors.purple2,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrainingSopEditor extends StatelessWidget {
  const _TrainingSopEditor({required this.onDoneTap, this.pdfButton, this.errorMessage});

  final VoidCallback onDoneTap;
  final Widget? pdfButton;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingSopEditorController>();
    final error = errorMessage ?? controller.errorMessage;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Column(
      children: [
        Expanded(
          child: TrainingSopDocumentView(controller: controller, preventTapCursor: isLandscape),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppTextView.body1(error, color: AppColors.mainBg),
          ),
        Offstage(
          offstage: isLandscape,
          child: SafeArea(
            top: false,
            bottom: false,
            minimum: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: _TrainingSopFormattingToolbar(
              controller: controller,
              onDoneTap: onDoneTap,
              pdfButton: pdfButton,
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the existing compact toolbar while routing formatting through Tiptap.
class _TrainingSopFormattingToolbar extends StatelessWidget {
  const _TrainingSopFormattingToolbar({
    required this.controller,
    required this.onDoneTap,
    this.pdfButton,
  });

  final TrainingSopEditorController controller;
  final VoidCallback onDoneTap;
  final Widget? pdfButton;

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
        if (pdfButton != null) ...[const SizedBox(width: 8), pdfButton!],
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
