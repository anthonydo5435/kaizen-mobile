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
    required this.isSavingSummary,
    required this.summaryController,
    this.showSummary = true,
    this.showSummaryLoading = false,
    this.summaryProcessingError,
    this.showSummaryRetryProgress = false,
    this.showGenerateSummary = false,
    this.summaryActionLabel = AppStrings.trainingGenerateSummaryAction,
    this.canGenerateSummary = false,
    this.isGeneratingSummary = false,
    this.isWritingSummary = false,
    this.contentHorizontalPadding = 0,
    this.fullscreenInLandscape = false,
    this.onExitLandscapeFullscreen,
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
  final bool isSavingSummary;
  final TextEditingController summaryController;
  final bool showSummary;
  final bool showSummaryLoading;
  final String? summaryProcessingError;
  final bool showSummaryRetryProgress;
  final bool showGenerateSummary;
  final String summaryActionLabel;
  final bool canGenerateSummary;
  final bool isGeneratingSummary;
  final bool isWritingSummary;
  final double contentHorizontalPadding;
  final bool fullscreenInLandscape;
  final VoidCallback? onExitLandscapeFullscreen;
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
    final summaryHorizontalPadding = contentHorizontalPadding / 2;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final canRevealVideo = hasVideo && !isFinalizingVideoSetup;
    final isLandscapeVideo =
        fullscreenInLandscape && MediaQuery.orientationOf(context) == Orientation.landscape;
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
            fullscreenInLandscape: fullscreenInLandscape,
            onExitLandscapeFullscreen: onExitLandscapeFullscreen,
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
        if (canRevealVideo &&
            (showSummary || showSummaryLoading || showSummaryRetryProgress))
          Offstage(
            offstage: isLandscapeVideo,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                summaryHorizontalPadding,
                16,
                summaryHorizontalPadding,
                0,
              ),
              child: showSummaryRetryProgress
                  ? const _TrainingSummaryRetryProgress()
                  : showSummaryLoading
                  ? const _TrainingSummaryCard(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: FastCircularProgressIndicator(
                          key: ValueKey('training-summary-loading'),
                          width: 24,
                          height: 24,
                        ),
                      ),
                    )
                  : _buildSummarySection(summary),
            ),
          ),
      ],
    );
  }

  Widget _buildSummarySection(String? summary) {
    return _TrainingSummarySection(
      summary: summary,
      processingError: summaryProcessingError,
      controller: summaryController,
      canEdit: canEditSummary,
      isSaving: isSavingSummary,
      isGenerating: isGeneratingSummary,
      isWriting: isWritingSummary,
      onEditTap: onEditSummaryTap,
      action: showGenerateSummary
          ? AppAiGenerateButton(
              label: summaryActionLabel,
              isEnabled: canGenerateSummary,
              isLoading: isGeneratingSummary,
              onTap: onGenerateSummaryTap,
              showOutline: true,
              maxLines: null,
            )
          : null,
    );
  }
}

class _TrainingSummarySection extends StatefulWidget {
  const _TrainingSummarySection({
    required this.summary,
    required this.processingError,
    required this.controller,
    required this.canEdit,
    required this.isSaving,
    required this.isGenerating,
    required this.isWriting,
    required this.onEditTap,
    required this.action,
  });

  final String? summary;
  final String? processingError;
  final TextEditingController controller;
  final bool canEdit;
  final bool isSaving;
  final bool isGenerating;
  final bool isWriting;
  final VoidCallback? onEditTap;
  final Widget? action;

  @override
  State<_TrainingSummarySection> createState() => _TrainingSummarySectionState();
}

class _TrainingSummarySectionState extends State<_TrainingSummarySection> {
  final _editorFocus = FocusNode(debugLabel: 'Lesson summary');

  @override
  void dispose() {
    _editorFocus.dispose();
    super.dispose();
  }

  void _focusEditor() {
    widget.onEditTap?.call();
    _editorFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.canEdit;
    final processingError = widget.processingError;
    final summary = widget.summary;
    final card = _TrainingSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrainingSummaryHeader(
            showDescription: canEdit && widget.action != null,
            isSaving: canEdit && widget.isSaving,
            action: widget.action,
          ),
          if (processingError != null) ...[
            const SizedBox(height: 14),
            AppTextView.body3(
              processingError,
              color: AppColors.red1,
              fontSize: 13,
              height: 1.5,
            ),
          ],
          const SizedBox(height: 14),
          canEdit
              ? _TrainingSummaryTextBlock(
                  controller: widget.controller,
                  focusNode: _editorFocus,
                  isGenerating: widget.isGenerating,
                  isWriting: widget.isWriting,
                  maxLength: processingError != null ? 1000 : null,
                  onEditTap: widget.onEditTap,
                )
              : _TrainingDisplayCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: AppTextView.body3(
                    summary != null && summary.isNotEmpty
                        ? CustomFunctions.stripHtmlTags(summary)
                        : AppStrings.trainingNoSummaryAvailable,
                    color: AppColors.textPrimary,
                    height: 1.65,
                  ),
                ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canEdit && !widget.isGenerating ? _focusEditor : null,
      child: card,
    );
  }
}

class _TrainingSummaryHeader extends StatelessWidget {
  const _TrainingSummaryHeader({
    required this.showDescription,
    required this.isSaving,
    required this.action,
  });

  final bool showDescription;
  final bool isSaving;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(
          child: AppTextView.body1(
            AppStrings.trainingSummaryLabel,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isSaving) ...[
          const SizedBox(width: 10),
          const FastCircularProgressIndicator(width: 12, height: 12),
        ],
      ],
    );
    final action = this.action;
    if (action == null) return heading;

    const description = AppTextView.body3(
      AppStrings.trainingSummaryDescription,
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
        if (showDescription && constraints.maxWidth >= 520 * textScale) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 4), description],
                ),
              ),
              const SizedBox(width: 12),
              action,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              overflowSpacing: 4,
              overflowAlignment: OverflowBarAlignment.end,
              children: [heading, action],
            ),
            if (showDescription) ...[const SizedBox(height: 4), description],
          ],
        );
      },
    );
  }
}

class _TrainingSummaryCard extends StatelessWidget {
  const _TrainingSummaryCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  static final outlineColor = AppColors.trainingNavigationInactive.withValues(
    alpha: 0.7,
  );

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('training-summary-card'),
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBg, AppColors.hex111317],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineColor),
      ),
      child: child,
    );
  }
}

class _TrainingSummaryRetryProgress extends StatelessWidget {
  const _TrainingSummaryRetryProgress();

  @override
  Widget build(BuildContext context) {
    return _TrainingSummaryCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Semantics(
        liveRegion: true,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FastCircularProgressIndicator(width: 26, height: 26),
            SizedBox(height: 12),
            AppTextView.body1(
              AppStrings.trainingGeneratingSummary,
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            AppTextView.body3(
              AppStrings.trainingGeneratingSummaryDescription,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the summary field mounted while generation waits and reveals its text.
class _TrainingSummaryTextBlock extends StatelessWidget {
  const _TrainingSummaryTextBlock({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isWriting,
    required this.onEditTap,
    this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool isWriting;
  final int? maxLength;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final isWaiting = isGenerating && !isWriting;
    final limit = maxLength;
    const horizontalPadding = 14.0;
    const verticalPadding = 12.0;
    const counterFontSize = 12.0;
    const counterLineHeight = 1.25;
    final counterSpace = limit == null
        ? 0.0
        : MediaQuery.textScalerOf(context).scale(counterFontSize) *
                  counterLineHeight +
              6;
    final editor = _TrainingOutlinedTextField(
      controller: controller,
      focusNode: focusNode,
      hintText: isGenerating ? '' : AppStrings.trainingSummaryHint,
      readOnly: isGenerating,
      onTap: isGenerating ? null : onEditTap,
      minLines: 4,
      maxLines: 8,
      maxLength: limit,
      counterText: limit == null ? null : '',
      outlineColor: _TrainingSummaryCard.outlineColor,
      textInputAction: TextInputAction.newline,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      textHeight: 1.65,
      hintFontWeight: FontWeight.w400,
      contentPadding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        verticalPadding + counterSpace,
      ),
    );

    return AbsorbPointer(
      absorbing: isGenerating,
      child: Opacity(
        opacity: isWaiting ? 0.4 : 1,
        child: limit == null
            ? editor
            : Stack(
                children: [
                  editor,
                  PositionedDirectional(
                    end: horizontalPadding,
                    bottom: verticalPadding,
                    child: IgnorePointer(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => AppTextView.body3(
                          AppStrings.trainingSummaryCharacterCount(
                            value.text.characters.length,
                            limit,
                          ),
                          color: AppColors.textSecondary,
                          fontSize: counterFontSize,
                          height: counterLineHeight,
                        ),
                      ),
                    ),
                  ),
                ],
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
