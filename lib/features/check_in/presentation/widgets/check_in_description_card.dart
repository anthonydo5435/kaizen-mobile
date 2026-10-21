import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/quarterly_audit.dart';
import '../providers/check_in_controller.dart';
import '../providers/check_in_description_card_controller.dart';
import 'description_media_comment_bottom_sheet.dart';
import 'description_text_comment_dialog.dart';

class CheckInDescriptionCard extends StatefulWidget {
  const CheckInDescriptionCard({
    super.key,
    required this.audit,
    required this.description,
    required this.date,
    required this.isOwner,
    required this.onOpenDetails,
    required this.isSelfAudit,
  });

  final QuarterlyAudit audit;
  final QuarterlyAuditDescription description;
  final String date;
  final bool isOwner;
  final ValueChanged<Map<String, int>> onOpenDetails;
  final bool isSelfAudit;

  @override
  State<CheckInDescriptionCard> createState() => _CheckInDescriptionCardState();
}

class _CheckInDescriptionCardState extends State<CheckInDescriptionCard> {
  late final CheckInDescriptionCardController _controller;
  final _isMediaCommentCreatedNotifier = ValueNotifier<bool>(false);
  Timer? _mediaCommentSuccessTimer;

  @override
  void initState() {
    super.initState();
    _controller = CheckInDescriptionCardController(
      checkInController: context.read<CheckInController>(),
      audit: widget.audit,
      description: widget.description,
      date: widget.date,
      isOwner: widget.isOwner,
      isSelfAudit: widget.isSelfAudit,
    )..addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CheckInDescriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.update(
      audit: widget.audit,
      description: widget.description,
      date: widget.date,
      isOwner: widget.isOwner,
      isSelfAudit: widget.isSelfAudit,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _mediaCommentSuccessTimer?.cancel();
    _isMediaCommentCreatedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ValueListenableBuilder<bool>(
        valueListenable: _isMediaCommentCreatedNotifier,
        builder: (context, isMediaCommentCreated, _) => _DescriptionCardContent(
          controller: _controller,
          isMediaCommentCreated: isMediaCommentCreated,
          onOpenDetails: _openDetails,
          onCreateComment: _openCreateCommentDialog,
        ),
      ),
    );
  }

  void _handleControllerChanged() {
    final error = _controller.takeErrorMessage();
    if (mounted && error != null) _showSnackBar(error);
  }

  Future<void> _openDetails() async {
    final counts = await _controller.prepareForDetails();
    if (mounted && counts != null) widget.onOpenDetails(counts);
  }

  Future<void> _openCreateCommentDialog() async {
    try {
      await _controller.resolveAuditUuid();
      if (!mounted) {
        return;
      }

      final didCreateMediaComment = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return _DescriptionMediaTypeSelectionBottomSheet(
            onTypeSelected: (selectedType) =>
                _openSelectedMediaCommentDialog(selectedType),
            onCommentOnlySelected: _openTextOnlyCommentDialog,
          );
        },
      );
      if (didCreateMediaComment == true && mounted) {
        _animateMediaCommentCreated();
      }
    } catch (error) {
      debugPrint('Unable to resolve audit uuid for media comment: $error');
      if (!mounted) {
        return;
      }

      _showSnackBar(AppStrings.auditUnableToLoadDescriptionDetails);
    }
  }

  Future<bool> _openTextOnlyCommentDialog() async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DescriptionTextCommentDialog(onSave: _controller.saveTextComment),
    );

    return didSave == true && mounted;
  }

  Future<bool> _openSelectedMediaCommentDialog(
    DescriptionMediaCommentContentType selectedType,
  ) async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DescriptionMediaCommentBottomSheet(
          contentType: selectedType,
          onSave: _controller.saveMediaComment,
        );
      },
    );

    if (didSave != true || !mounted) {
      return false;
    }

    return true;
  }

  void _animateMediaCommentCreated() {
    _mediaCommentSuccessTimer?.cancel();
    _isMediaCommentCreatedNotifier.value = true;
    _mediaCommentSuccessTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _isMediaCommentCreatedNotifier.value = false;
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DescriptionCardContent extends StatelessWidget {
  const _DescriptionCardContent({
    required this.controller,
    required this.isMediaCommentCreated,
    required this.onOpenDetails,
    required this.onCreateComment,
  });

  final CheckInDescriptionCardController controller;
  final bool isMediaCommentCreated;
  final VoidCallback onOpenDetails;
  final VoidCallback onCreateComment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpenDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DescriptionCardHeading(controller: controller),
            const SizedBox(height: 18),
            _DescriptionCardRatingSection(
              controller: controller,
              isMediaCommentCreated: isMediaCommentCreated,
              onCreateComment: onCreateComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionCardHeading extends StatelessWidget {
  const _DescriptionCardHeading({required this.controller});

  final CheckInDescriptionCardController controller;

  @override
  Widget build(BuildContext context) {
    final milestoneLabel = controller.milestoneLabel;
    return Row(
      children: [
        Expanded(
          child: AppTextView.body1(
            controller.descriptionText,
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: _DescriptionAuditTypePill(text: controller.auditTypeLabel),
        ),
        if (milestoneLabel != null) ...[
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: _DescriptionMilestonePill(text: milestoneLabel),
          ),
        ],
      ],
    );
  }
}

class _DescriptionCardRatingSection extends StatelessWidget {
  const _DescriptionCardRatingSection({
    required this.controller,
    required this.isMediaCommentCreated,
    required this.onCreateComment,
  });

  final CheckInDescriptionCardController controller;
  final bool isMediaCommentCreated;
  final VoidCallback onCreateComment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: controller.canCreateComments ? 78 : 42,
      ),
      child: Stack(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              _DescriptionRatingCounters(controller: controller),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          Positioned.fill(
            child: _DescriptionCardActions(
              controller: controller,
              isMediaCommentCreated: isMediaCommentCreated,
              onCreateComment: onCreateComment,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionRatingCounters extends StatelessWidget {
  const _DescriptionRatingCounters({required this.controller});

  final CheckInDescriptionCardController controller;

  @override
  Widget build(BuildContext context) {
    final canEdit = controller.canEditRatings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AuditRating.values
          .map((rating) {
            final color = switch (rating) {
              AuditRating.great => AppColors.green1,
              AuditRating.almostThere => AppColors.orange1,
              AuditRating.needsImprovement => AppColors.red1,
            };
            return Padding(
              padding: EdgeInsets.only(
                left: rating == AuditRating.great ? 0 : 8,
              ),
              child: _SelectionCounter(
                color: canEdit ? color : color.withValues(alpha: 0.5),
                count: controller.countFor(rating),
                showDecrementControl: controller.showDecrementControl,
                onTapCount: canEdit
                    ? () => controller.incrementRating(rating)
                    : null,
                onTapArrow: canEdit
                    ? () => controller.decrementRating(rating)
                    : null,
                canEditBlocks: canEdit,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _DescriptionCardActions extends StatelessWidget {
  const _DescriptionCardActions({
    required this.controller,
    required this.isMediaCommentCreated,
    required this.onCreateComment,
  });

  final CheckInDescriptionCardController controller;
  final bool isMediaCommentCreated;
  final VoidCallback onCreateComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isMediaCommentCreated
                ? AppColors.green1
                : AppColors.secondaryColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: controller.isOpeningDetails
              ? Padding(
                  padding: const EdgeInsets.all(7),
                  child: FastCircularProgressIndicator(),
                )
              : Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isMediaCommentCreated
                      ? Colors.white
                      : AppColors.secondaryColor,
                  size: 16,
                ),
        ),
        if (controller.canCreateComments)
          _CommentIconButton(
            isEnabled: true,
            icon: Icons.camera_alt_outlined,
            onTap: onCreateComment,
          ),
      ],
    );
  }
}

class _DescriptionAuditTypePill extends StatelessWidget {
  const _DescriptionAuditTypePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orange1,
        borderRadius: BorderRadius.circular(50),
      ),
      child: AppTextView.body2(
        text,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 9,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DescriptionMilestonePill extends StatelessWidget {
  const _DescriptionMilestonePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.hexe8f2ff,
        border: Border.all(color: AppColors.purple1),
        borderRadius: BorderRadius.circular(50),
      ),
      child: AppTextView.body2(
        text,
        color: AppColors.purple1,
        fontWeight: FontWeight.w600,
        fontSize: 9,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SelectionCounter extends StatelessWidget {
  const _SelectionCounter({
    required this.color,
    required this.count,
    this.onTapCount,
    this.onTapArrow,
    required this.canEditBlocks,
    required this.showDecrementControl,
  });

  final Color color;
  final int count;
  final VoidCallback? onTapCount;
  final VoidCallback? onTapArrow;
  final bool canEditBlocks;
  final bool showDecrementControl;

  @override
  Widget build(BuildContext context) {
    final hasReachedLimit = !AuditRating.canIncrementCount(count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasReachedLimit ? null : onTapCount,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasReachedLimit ? color.withValues(alpha: 0.5) : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppTextView.body2(
              '$count',
              color: hasReachedLimit ? Colors.white60 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        if (showDecrementControl) ...[
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapArrow,
            child: Container(
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: canEditBlocks
                    ? AppColors.grey1
                    : AppColors.grey1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                canEditBlocks
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.lock_rounded,
                color: Colors.white,
                size: canEditBlocks ? 24 : 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentIconButton extends StatelessWidget {
  const _CommentIconButton({
    required this.isEnabled,
    required this.icon,
    this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? AppColors.secondaryColor : AppColors.grey1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _DescriptionMediaTypeSelectionBottomSheet extends StatefulWidget {
  const _DescriptionMediaTypeSelectionBottomSheet({
    required this.onTypeSelected,
    required this.onCommentOnlySelected,
  });

  final Future<bool> Function(DescriptionMediaCommentContentType selectedType)
  onTypeSelected;
  final Future<bool> Function() onCommentOnlySelected;

  @override
  State<_DescriptionMediaTypeSelectionBottomSheet> createState() =>
      _DescriptionMediaTypeSelectionBottomSheetState();
}

class _DescriptionMediaTypeSelectionBottomSheetState
    extends State<_DescriptionMediaTypeSelectionBottomSheet> {
  static const _availableTypes = <DescriptionMediaCommentContentType>[
    DescriptionMediaCommentContentType.photo,
    DescriptionMediaCommentContentType.video,
    DescriptionMediaCommentContentType.upload,
  ];

  late final ValueNotifier<bool> _isOpeningChildSheetNotifier =
      ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isOpeningChildSheetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: _isOpeningChildSheetNotifier,
      builder: (context, isOpeningChildSheet, _) {
        return SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding + 24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const AppTextView.body1(
                    AppStrings.auditSelectMediaType,
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 14),
                  _MediaTypeOption(
                    title: AppStrings.auditCommentOnly,
                    onTap: isOpeningChildSheet
                        ? null
                        : () => _openChildSheet(widget.onCommentOnlySelected),
                  ),
                  ..._availableTypes.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _MediaTypeOption(
                        title: _mediaTypeTitle(type),
                        onTap: isOpeningChildSheet
                            ? null
                            : () => _openChildSheet(
                                () => widget.onTypeSelected(type),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    text: AppStrings.done,
                    onPressed: isOpeningChildSheet
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _mediaTypeTitle(DescriptionMediaCommentContentType type) {
    return switch (type) {
      DescriptionMediaCommentContentType.photo => AppStrings.auditPhoto,
      DescriptionMediaCommentContentType.video => AppStrings.auditVideo,
      DescriptionMediaCommentContentType.upload => AppStrings.auditUpload,
      DescriptionMediaCommentContentType.screenRecording =>
        AppStrings.auditScreenRecording,
    };
  }

  Future<void> _openChildSheet(Future<bool> Function() openSheet) async {
    if (_isOpeningChildSheetNotifier.value) {
      return;
    }

    _isOpeningChildSheetNotifier.value = true;
    try {
      final didSave = await openSheet();
      if (didSave && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        _isOpeningChildSheetNotifier.value = false;
      }
    }
  }
}

class _MediaTypeOption extends StatelessWidget {
  const _MediaTypeOption({required this.title, required this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTextView.body2(
                  title,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
