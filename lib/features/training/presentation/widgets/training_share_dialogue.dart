import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_gradient_action_button.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../core/widgets/share_dialogue.dart';
import '../../domain/entities/seat_description_training.dart';
import '../controllers/training_share_controller.dart';

Future<void> showTrainingShareDialogue(
  BuildContext context, {
  required TrainingShareController controller,
  required List<SeatDescriptionTrainingModule> lessons,
}) {
  controller.prepareLessons(lessons);
  if (!controller.hasLoaded &&
      !controller.isLoading &&
      controller.errorMessage == null) {
    unawaited(controller.loadLink());
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider.value(
      value: controller,
      child: const TrainingShareDialogue(),
    ),
  );
}

class TrainingShareDialogue extends StatelessWidget {
  const TrainingShareDialogue({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingShareController>();
    return ListenableBuilder(
      listenable: AppManager.instance,
      builder: (context, _) {
        if (controller.link != null ||
            !controller.hasLoaded ||
            controller.isLoading) {
          return PopScope(
            canPop: !controller.isWorking,
            child: ShareDialogue(
              contentLabel: AppStrings.shareLessonsContent,
              link: controller.link,
              isLoading: controller.isLoading,
              isWorking: controller.isWorking,
              errorMessage: controller.errorMessage,
              onRevokeLink: controller.canRevoke ? controller.revokeLink : null,
              onClose: () => Navigator.of(context).pop(),
              onRetry:
                  !controller.hasLoaded &&
                      !controller.isLoading &&
                      controller.canManage
                  ? controller.loadLink
                  : null,
              onCopyLink: controller.canManage
                  ? () async {
                      final copied = await controller.copyLink();
                      if (!copied || !context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.shareLinkCopied),
                        ),
                      );
                    }
                  : null,
            ),
          );
        }
        return PopScope(
          canPop: !controller.isWorking,
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 600,
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.cardBg, AppColors.hex111317],
                ),
                borderRadius: BorderRadius.circular(16),
                border: AppDialogStyle.border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShareHeader(
                    onClose: controller.isWorking
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: AppDotDivider(opacity: 0.4, dotSize: 4),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: _LessonSelection(controller: controller),
                    ),
                  ),
                  if (controller.link == null) ...[
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      AppTextView.body2(
                        controller.errorMessage!,
                        color: AppColors.red1,
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppGradientActionButton(
                      label: AppStrings.shareCreateLinkAction,
                      icon: Icons.link_rounded,
                      onTap: controller.canCreate
                          ? controller.createLink
                          : null,
                      isLoading: controller.isWorking,
                      borderRadius: 12,
                      minHeight: 44,
                      textSize: 14,
                      boxShadows: const [],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShareHeader extends StatelessWidget {
  const _ShareHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: AppTextView.title1(
          AppStrings.shareLessonsTitle,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(width: 12),
      AppOverlayCloseButton(onTap: onClose),
    ],
  );
}

class _LessonSelection extends StatelessWidget {
  const _LessonSelection({required this.controller});

  final TrainingShareController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppTextView.body(
        AppStrings.shareLessonsDescription,
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      const SizedBox(height: 12),
      _SelectAllRow(controller: controller),
      const SizedBox(height: 12),
      ListView.separated(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: controller.lessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lesson = controller.lessons[index];
          return _LessonRow(
            lesson: lesson,
            selected: controller.isSelected(lesson.uuid),
            onChanged: controller.canSelect
                ? (selected) => controller.selectLesson(lesson.uuid, selected)
                : null,
          );
        },
      ),
      if (controller.selectedCount == 0) ...[
        const SizedBox(height: 12),
        const AppTextView.body2(
          AppStrings.shareLessonsSelectAtLeastOne,
          color: AppColors.textSecondary,
        ),
      ],
    ],
  );
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({required this.controller});

  final TrainingShareController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _LessonCheckbox(
        selected: controller.allSelected
            ? true
            : controller.selectedCount == 0
            ? false
            : null,
        onChanged: controller.canSelect
            ? (_) => controller.selectAll(!controller.allSelected)
            : null,
      ),
      Expanded(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            const AppTextView.body(
              AppStrings.shareLessonsSelectAll,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            AppTextView.body2(
              AppStrings.shareLessonsSelectedCount(
                controller.selectedCount,
                controller.lessons.length,
              ),
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ],
  );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.selected,
    required this.onChanged,
  });

  final SeatDescriptionTrainingModule lesson;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.18)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
        child: Row(
          children: [
            _LessonCheckbox(selected: selected, onChanged: onChanged),
            _LessonThumbnail(thumbnailLink: lesson.thumbnailLink),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextView.body(
                lesson.title.trim().isEmpty
                    ? AppStrings.sharedLmsUntitledLesson
                    : lesson.title,
                fontSize: 14,
                color: AppColors.textPrimary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LessonCheckbox extends StatelessWidget {
  const _LessonCheckbox({required this.selected, required this.onChanged});

  final bool? selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Checkbox(
    value: selected,
    tristate: true,
    activeColor: AppColors.lightGreen1,
    checkColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.textPrimary, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    onChanged: onChanged == null ? null : (value) => onChanged!(value ?? false),
  );
}

class _LessonThumbnail extends StatelessWidget {
  const _LessonThumbnail({required this.thumbnailLink});

  final String? thumbnailLink;

  @override
  Widget build(BuildContext context) {
    final url = CustomFunctions.resolveImageUrl(thumbnailLink);
    const fallback = Center(
      child: Icon(
        Icons.school_outlined,
        size: 24,
        color: AppColors.textPrimary,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 44,
        child: ColoredBox(
          color: AppColors.grey2,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: FastCircularProgressIndicator(width: 18, height: 18),
                  ),
                  errorWidget: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}
