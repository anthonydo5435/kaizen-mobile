part of 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';

class TrainingReadOnlySopTab extends StatelessWidget {
  const TrainingReadOnlySopTab({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.document,
  });

  final bool isLoading;
  final String? errorMessage;
  final SeatDescriptionTrainingDocument? document;

  @override
  Widget build(BuildContext context) {
    final html = document?.text?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTextView.body1(
          AppStrings.trainingSopTab,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _DocumentReadingPanel(
            html: html,
            isSop: true,
            isLoading: isLoading,
            message:
                errorMessage ??
                (html == null || html.isEmpty ? AppStrings.trainingNoSopAvailable : null),
          ),
        ),
      ],
    );
  }
}

class _AssignmentTabContent extends StatelessWidget {
  const _AssignmentTabContent({
    required this.isLoading,
    required this.errorMessage,
    required this.assignment,
  });

  final bool isLoading;
  final String? errorMessage;
  final SeatDescriptionTrainingAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _DocumentReadingPanel(isLoading: true);
    if (errorMessage != null) return _ContentMessage(message: errorMessage!);

    final title = assignment?.title?.trim();
    final instructions = assignment?.instructions?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final hasInstructions = instructions != null && instructions.isNotEmpty;
    if (!hasTitle && !hasInstructions) {
      return const _DocumentReadingPanel(message: AppStrings.trainingNoAssignmentAvailable);
    }

    final titleSection = _AssignmentTitleSection(title: title, showsDescription: hasInstructions);
    if (!hasInstructions) return SingleChildScrollView(child: titleSection);

    return TrainingAssignmentLayout(
      header: titleSection,
      body: _DocumentReadingPanel(html: instructions),
    );
  }
}

class _AssignmentTitleSection extends StatelessWidget {
  const _AssignmentTitleSection({required this.title, required this.showsDescription});

  final String? title;
  final bool showsDescription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title?.isNotEmpty ?? false) ...[
          const _SectionLabel(label: AppStrings.trainingLessonTitle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark2.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.16)),
            ),
            child: AppTextView.body2(
              title!,
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (showsDescription) const SizedBox(height: 18),
        ],
        if (showsDescription) ...[
          const _SectionLabel(label: AppStrings.trainingAssignmentDescriptionLabel),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      AppTextView.body3(label, color: AppColors.textSecondary, fontWeight: FontWeight.w700);
}

/// Keeps the document viewport bounded while its HTML content scrolls independently.
class _DocumentReadingPanel extends StatelessWidget {
  const _DocumentReadingPanel({
    this.html,
    this.isLoading = false,
    this.message,
    this.isSop = false,
  });

  final String? html;
  final bool isLoading;
  final String? message;
  final bool isSop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: isLoading
          ? const Center(child: FastCircularProgressIndicator(color: AppColors.secondaryColor))
          : message != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextView.body3(
                  message!,
                  color: AppColors.mainBg,
                  textAlign: TextAlign.center,
                  height: 1.55,
                ),
              ),
            )
          : isSop
          ? TrainingSopReader(html: html ?? '')
          : SingleChildScrollView(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Html(
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
                  'p': Style(margin: Margins.only(bottom: 12), lineHeight: const LineHeight(1.65)),
                  'ul': Style(margin: Margins.only(bottom: 12)),
                  'ol': Style(margin: Margins.only(bottom: 12)),
                  'li': Style(margin: Margins.only(bottom: 6)),
                  'h1': _headingStyle(20),
                  'h2': _headingStyle(18),
                  'h3': _headingStyle(16),
                  'h4': _headingStyle(15),
                  'h5': _headingStyle(14),
                  'h6': _headingStyle(14),
                  'a': Style(color: AppColors.purple1),
                },
              ),
            ),
    );
  }

  Style _headingStyle(double fontSize) => Style(
    margin: Margins.only(bottom: 10),
    color: AppColors.mainBg,
    fontSize: FontSize(fontSize),
    fontWeight: FontWeight.w700,
    lineHeight: const LineHeight(1.35),
  );
}

class _ContentMessage extends StatelessWidget {
  const _ContentMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.18)),
      ),
      child: AppTextView.body3(
        message,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
        height: 1.55,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: AppTextView.body(message, color: AppColors.textSecondary, textAlign: TextAlign.center),
  );
}
