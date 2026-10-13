part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _VideoTabContent extends StatelessWidget {
  const _VideoTabContent({
    required this.detail,
    required this.localVideoPath,
    required this.isReadOnly,
    required this.isUploadEnabled,
    required this.isPickingVideo,
    required this.isFinalizingVideoSetup,
    required this.isUploadingVideo,
    required this.isDeletingVideo,
    required this.isUploadingThumbnail,
    required this.canEditSummary,
    required this.isEditingSummary,
    required this.isSavingSummary,
    required this.summaryController,
    this.canGenerateSummary = false,
    this.isGeneratingSummary = false,
    this.isWritingSummary = false,
    this.contentHorizontalPadding = 0,
    this.onUploadVideoTap,
    this.onReUploadVideoTap,
    this.onUpdateThumbnailTap,
    this.onEditSummaryTap,
    this.onCancelSummaryTap,
    this.onSaveSummaryTap,
    this.onGenerateSummaryTap,
  });

  final SeatDescriptionTrainingModuleDetail? detail;
  final String? localVideoPath;
  final bool isReadOnly;
  final bool isUploadEnabled;
  final bool isPickingVideo;
  final bool isFinalizingVideoSetup;
  final bool isUploadingVideo;
  final bool isDeletingVideo;
  final bool isUploadingThumbnail;
  final bool canEditSummary;
  final bool isEditingSummary;
  final bool isSavingSummary;
  final TextEditingController summaryController;
  final bool canGenerateSummary;
  final bool isGeneratingSummary;
  final bool isWritingSummary;
  final double contentHorizontalPadding;
  final VoidCallback? onUploadVideoTap;
  final VoidCallback? onReUploadVideoTap;
  final VoidCallback? onUpdateThumbnailTap;
  final VoidCallback? onEditSummaryTap;
  final VoidCallback? onCancelSummaryTap;
  final Future<bool> Function()? onSaveSummaryTap;
  final VoidCallback? onGenerateSummaryTap;

  @override
  Widget build(BuildContext context) {
    final video = detail?.trainingVideo;
    final videoUrl = video?.url?.trim();
    final summary = detail?.description?.trim();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final canRevealVideo = hasVideo && !isFinalizingVideoSetup;
    final canUseVideoActions =
        isUploadEnabled &&
        !isPickingVideo &&
        !isFinalizingVideoSetup &&
        !isUploadingVideo &&
        !isDeletingVideo &&
        !isUploadingThumbnail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canRevealVideo)
          ComplianceVideoTranscriptPanel(
            videoId: (detail?.uuid, video?.uuid),
            transcript: video?.transcript,
            videoUrl: videoUrl,
            localVideoPath: localVideoPath,
            title: detail?.title ?? '',
            thumbnailLink: detail?.previewThumbnailLink,
            activeCaptionMaxLines: 1,
            topRightActions: !isReadOnly
                ? [
                    _TrainingVideoActionButton(
                      icon: Icons.photo_library_outlined,
                      tooltip: AppStrings.trainingThumbnailAction,
                      isLoading: isUploadingThumbnail,
                      onTap: canUseVideoActions ? onUpdateThumbnailTap : null,
                    ),
                    _TrainingVideoActionButton(
                      icon: Icons.sync_rounded,
                      tooltip: AppStrings.trainingReUploadVideoAction,
                      label: AppStrings.trainingReUploadVideoAction,
                      isLoading: isDeletingVideo || isPickingVideo || isUploadingVideo,
                      onTap: canUseVideoActions ? onReUploadVideoTap : null,
                    ),
                  ]
                : const <Widget>[],
          )
        else if (isReadOnly)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: contentHorizontalPadding),
            child: const _ContentMessage(message: AppStrings.trainingNoVideoAvailable),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: contentHorizontalPadding),
            child: _TrainingVideoEmptyState(
              isEnabled: isUploadEnabled && !isFinalizingVideoSetup,
              isPickingVideo: isPickingVideo || isFinalizingVideoSetup,
              isUploading: isUploadingVideo,
              isFinalizingSetup: isFinalizingVideoSetup,
              isLoading:
                  isUploadingVideo || isDeletingVideo || isPickingVideo || isFinalizingVideoSetup,
              onTap: onUploadVideoTap,
            ),
          ),
        if (canRevealVideo)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: contentHorizontalPadding),
            child: _buildSummarySection(summary),
          ),
      ],
    );
  }

  Widget _buildSummarySection(String? summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
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
                  child: _TrainingSectionHeader(title: AppStrings.trainingSummaryLabel),
                ),
                if (canEditSummary && isSavingSummary) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: FastCircularProgressIndicator(width: 12, height: 12),
                  ),
                ],
              ],
            ),
            if (canEditSummary && !isReadOnly)
              AppAiGenerateButton(
                label: AppStrings.trainingGenerateSummaryAction,
                isEnabled: canGenerateSummary,
                isLoading: isGeneratingSummary,
                onTap: onGenerateSummaryTap,
                showOutline: true,
                maxLines: null,
              ),
          ],
        ),
        const SizedBox(height: 10),
        canEditSummary
            ? _TrainingSummaryTextBlock(
                controller: summaryController,
                isEditing: isEditingSummary,
                isGenerating: isGeneratingSummary,
                isWriting: isWritingSummary,
                onEditTap: onEditSummaryTap,
              )
            : _TrainingDisplayCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: AppTextView.body3(
                  summary != null && summary.isNotEmpty
                      ? CustomFunctions.stripHtmlTags(summary)
                      : AppStrings.trainingNoSummaryAvailable,
                  color: AppColors.textPrimary,
                  height: 1.65,
                ),
              ),
      ],
    );
  }
}

/// Keeps the summary field mounted while generation waits and reveals its text.
class _TrainingSummaryTextBlock extends StatelessWidget {
  const _TrainingSummaryTextBlock({
    required this.controller,
    required this.isEditing,
    required this.isGenerating,
    required this.isWriting,
    required this.onEditTap,
  });

  final TextEditingController controller;
  final bool isEditing;
  final bool isGenerating;
  final bool isWriting;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final isWaiting = isGenerating && !isWriting;

    return AbsorbPointer(
      absorbing: isGenerating,
      child: Opacity(
        opacity: isWaiting ? 0.4 : 1,
        child: _TrainingOutlinedTextField(
          controller: controller,
          hintText: isGenerating ? '' : AppStrings.trainingSummaryHint,
          readOnly: !isEditing || isGenerating,
          showCursor: isEditing && !isGenerating,
          onTap: isGenerating ? null : onEditTap,
          minLines: 4,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          textHeight: 1.65,
          hintFontWeight: FontWeight.w400,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _NewLessonTitleField extends StatelessWidget {
  const _NewLessonTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppTextView.body3(
          AppStrings.trainingLessonTitle,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  enabled: !isSubmitting,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (canSubmit) {
                      onSubmit();
                    }
                  },
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: AppStrings.trainingLessonTitleHint,
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: canSubmit ? onSubmit : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: canSubmit
                        ? AppColors.secondaryColor
                        : AppColors.fieldBorder.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isSubmitting
                        ? FastCircularProgressIndicator(width: 14, height: 14)
                        : Icon(
                            Icons.check_rounded,
                            color: canSubmit ? AppColors.textPrimary : AppColors.textSecondary,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainingVideoActionButton extends StatelessWidget {
  const _TrainingVideoActionButton({
    required this.icon,
    required this.tooltip,
    required this.isLoading,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: Material(
          color: AppColors.surfaceDark2,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: borderRadius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 34,
                minHeight: 34,
                maxWidth: label == null ? 34 : 132,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 10, vertical: 7),
                child: Opacity(
                  opacity: onTap != null || isLoading ? 1 : 0.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Center(
                            child: FastCircularProgressIndicator(width: 14, height: 14),
                          ),
                        )
                      else
                        Icon(icon, color: AppColors.textPrimary, size: 18),
                      if (label != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: AppTextView.body2(
                            label!,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w400,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingVideoEmptyState extends StatelessWidget {
  const _TrainingVideoEmptyState({
    required this.isEnabled,
    required this.isPickingVideo,
    required this.isUploading,
    required this.isFinalizingSetup,
    required this.isLoading,
    this.onTap,
  });

  final bool isEnabled;
  final bool isPickingVideo;
  final bool isUploading;
  final bool isFinalizingSetup;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = isFinalizingSetup
        ? AppStrings.trainingFinishingVideoSetup
        : isUploading
        ? AppStrings.trainingUploadingVideo
        : isPickingVideo
        ? AppStrings.trainingPreparingVideoUpload
        : AppStrings.trainingVideoUploadPrompt;

    return Material(
      color: AppColors.mainBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isEnabled && !isLoading ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          foregroundPainter: _DottedRoundedBorderPainter(
            color: AppColors.fieldBorder.withValues(alpha: 0.7),
            radius: 16,
            strokeWidth: 0.8,
            dashLength: 2.5,
            gapLength: 2.5,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: (constraints.maxWidth * 1.22).clamp(320.0, 520.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Center(
                  child: _TrainingVideoUploadContent(
                    label: label,
                    isBusy: isLoading,
                    showProgress: isUploading || isFinalizingSetup,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingVideoUploadContent extends StatelessWidget {
  const _TrainingVideoUploadContent({
    required this.label,
    required this.isBusy,
    required this.showProgress,
  });

  final String label;
  final bool isBusy;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrainingVideoUploadIcon(isBusy: isBusy),
        const SizedBox(height: 24),
        AppTextView.body(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.center,
          height: 1.25,
        ),
        if (!isBusy) ...[
          const SizedBox(height: 12),
          const AppTextView.body3(
            AppStrings.trainingVideoFileFormat,
            color: AppColors.textPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const AppTextView.body3(
            AppStrings.trainingVideoMaxFileSize,
            color: AppColors.textPrimary,
            textAlign: TextAlign.center,
          ),
        ],
        if (showProgress) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrainingVideoUploadIcon extends StatelessWidget {
  const _TrainingVideoUploadIcon({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(color: AppColors.secondaryColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: isBusy
          ? FastCircularProgressIndicator(width: 20, height: 20)
          : SvgPicture.asset(
              AppAssets.upload,
              width: 18,
              height: 18,
              excludeFromSemantics: true,
              colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
            ),
    );
  }
}
