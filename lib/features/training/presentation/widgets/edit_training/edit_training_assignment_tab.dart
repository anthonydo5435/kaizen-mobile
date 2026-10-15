part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _AssignmentTabContent extends StatelessWidget {
  const _AssignmentTabContent({
    required this.isLoading,
    required this.canManageGeneration,
    required this.canGenerate,
    required this.isGenerating,
    required this.canEditAssignment,
    required this.isSavingAssignment,
    required this.titleController,
    required this.descriptionController,
    required this.instructions,
    required this.errorMessage,
    required this.onGenerateTap,
    required this.onDoneTap,
    this.onBoldTap,
    this.onItalicTap,
    this.onUnderlineTap,
    this.onBulletListTap,
    this.onNumberedListTap,
    this.onQuoteTap,
    this.onHeadingTap,
  });

  final bool isLoading;
  final bool canManageGeneration;
  final bool canGenerate;
  final bool isGenerating;
  final bool canEditAssignment;
  final bool isSavingAssignment;
  final TextEditingController titleController;
  final TrainingRichTextEditingController descriptionController;
  final String? instructions;
  final String? errorMessage;
  final VoidCallback onGenerateTap;
  final VoidCallback onDoneTap;
  final VoidCallback? onBoldTap;
  final VoidCallback? onItalicTap;
  final VoidCallback? onUnderlineTap;
  final VoidCallback? onBulletListTap;
  final VoidCallback? onNumberedListTap;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onHeadingTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 2,
          overflowSpacing: 2,
          children: [
            const AppTextView.body1(
              AppStrings.trainingAssignmentTab,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            if (canManageGeneration)
              AppAiGenerateButton(
                label: AppStrings.trainingGenerateAssignment,
                isEnabled: canGenerate,
                isLoading: isGenerating,
                onTap: onGenerateTap,
                showOutline: true,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _AssignmentInstructionsPanel(
            instructions: instructions,
            isLoading: isLoading,
            errorMessage: errorMessage,
            canEdit: canEditAssignment,
            isSaving: isSavingAssignment,
            titleController: titleController,
            descriptionController: descriptionController,
            onDoneTap: onDoneTap,
            onBoldTap: onBoldTap,
            onItalicTap: onItalicTap,
            onUnderlineTap: onUnderlineTap,
            onBulletListTap: onBulletListTap,
            onNumberedListTap: onNumberedListTap,
            onQuoteTap: onQuoteTap,
            onHeadingTap: onHeadingTap,
          ),
        ),
      ],
    );
  }
}

class _AssignmentInstructionsPanel extends StatelessWidget {
  const _AssignmentInstructionsPanel({
    required this.instructions,
    required this.isLoading,
    required this.errorMessage,
    required this.canEdit,
    required this.isSaving,
    required this.titleController,
    required this.descriptionController,
    required this.onDoneTap,
    this.onBoldTap,
    this.onItalicTap,
    this.onUnderlineTap,
    this.onBulletListTap,
    this.onNumberedListTap,
    this.onQuoteTap,
    this.onHeadingTap,
  });

  final String? instructions;
  final bool isLoading;
  final String? errorMessage;
  final bool canEdit;
  final bool isSaving;
  final TextEditingController titleController;
  final TrainingRichTextEditingController descriptionController;
  final VoidCallback onDoneTap;
  final VoidCallback? onBoldTap;
  final VoidCallback? onItalicTap;
  final VoidCallback? onUnderlineTap;
  final VoidCallback? onBulletListTap;
  final VoidCallback? onNumberedListTap;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onHeadingTap;

  @override
  Widget build(BuildContext context) {
    final html = instructions?.trim();
    final message = errorMessage?.trim();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: isLoading
          ? const Center(
              child: FastCircularProgressIndicator(
                color: AppColors.secondaryColor,
              ),
            )
          : canEdit
          ? Column(
              children: [
                if (message != null && message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: AppTextView.body3(
                      message,
                      color: AppColors.red1,
                      height: 1.4,
                    ),
                  ),
                Expanded(
                  child: _TrainingEditableTextCard(
                    controller: descriptionController,
                    hintText: AppStrings.trainingAssignmentDescriptionHint,
                    minLines: 10,
                    maxLines: 18,
                    expands: true,
                    wrapWithCard: false,
                    textColor: AppColors.mainBg,
                    hintColor: AppColors.trainingUploadMuted,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: TextFieldTapRegion(
                    child: _TrainingFormattingToolbar(
                      controller: descriptionController,
                      isSaving: isSaving,
                      onDoneTap: onDoneTap,
                      onBoldTap: onBoldTap,
                      onItalicTap: onItalicTap,
                      onUnderlineTap: onUnderlineTap,
                      onBulletListTap: onBulletListTap,
                      onNumberedListTap: onNumberedListTap,
                      onQuoteTap: onQuoteTap,
                      onHeadingTap: onHeadingTap,
                    ),
                  ),
                ),
              ],
            )
          : message != null && message.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextView.body3(
                  message,
                  color: AppColors.mainBg,
                  textAlign: TextAlign.center,
                  height: 1.55,
                ),
              ),
            )
          : html == null || html.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppTextView.body3(
                  AppStrings.trainingNoAssignmentAvailable,
                  color: AppColors.mainBg,
                  textAlign: TextAlign.center,
                  height: 1.55,
                ),
              ),
            )
          : SingleChildScrollView(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titleController.text.trim().isNotEmpty) ...[
                    AppTextView.body1(
                      titleController.text.trim(),
                      color: AppColors.mainBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Html(
                    data: html,
                    shrinkWrap: true,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        color: AppColors.mainBg,
                        fontSize: FontSize(13),
                        fontWeight: FontWeight.w400,
                        lineHeight: const LineHeight(1.65),
                      ),
                      'p': Style(
                        margin: Margins.only(bottom: 12),
                        lineHeight: const LineHeight(1.65),
                      ),
                      'ul': Style(margin: Margins.only(bottom: 12)),
                      'ol': Style(margin: Margins.only(bottom: 12)),
                      'li': Style(margin: Margins.only(bottom: 6)),
                      'h1': _assignmentHeadingStyle(20),
                      'h2': _assignmentHeadingStyle(18),
                      'h3': _assignmentHeadingStyle(16),
                      'h4': _assignmentHeadingStyle(15),
                      'h5': _assignmentHeadingStyle(14),
                      'h6': _assignmentHeadingStyle(14),
                      'a': Style(color: AppColors.purple1),
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Style _assignmentHeadingStyle(double fontSize) => Style(
    margin: Margins.only(bottom: 10),
    color: AppColors.mainBg,
    fontSize: FontSize(fontSize),
    fontWeight: FontWeight.w700,
    lineHeight: const LineHeight(1.35),
  );
}
