import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../models/training_library_lesson_action.dart';

export '../models/training_library_lesson_action.dart';

Future<TrainingLibraryLessonAction?> showTrainingLibraryLessonActionsSheet(
  BuildContext context, {
  required bool canEdit,
  required bool isPubliclyAvailable,
  bool showVisibility = true,
}) async {
  if (!canEdit) {
    return null;
  }
  return showModalBottomSheet<TrainingLibraryLessonAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TrainingLibraryLessonActionsSheet(
      canEdit: canEdit,
      isPubliclyAvailable: isPubliclyAvailable,
      showVisibility: showVisibility,
      onSelected: (action) => Navigator.of(context).pop(action),
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

class TrainingLibraryLessonActionsSheet extends StatelessWidget {
  const TrainingLibraryLessonActionsSheet({
    super.key,
    required this.canEdit,
    required this.isPubliclyAvailable,
    this.showVisibility = true,
    required this.onSelected,
    required this.onClose,
  });

  final bool canEdit;
  final bool isPubliclyAvailable;
  final bool showVisibility;
  final ValueChanged<TrainingLibraryLessonAction> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.mainBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 28),
                    const Expanded(
                      child: AppTextView.body1(
                        AppStrings.trainingLibraryLessonActions,
                        color: AppColors.secondaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    AppOverlayCloseButton(onTap: onClose, size: 28),
                  ],
                ),
                const SizedBox(height: 28),
                const AppDotDivider(),
                const SizedBox(height: 28),
                if (showVisibility) ...[
                  _LessonActionTile(
                    title: AppStrings.visibilityLabel,
                    icon: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                    iconBackground: AppColors.secondaryColor,
                    onTap: () =>
                        onSelected(TrainingLibraryLessonAction.visibility),
                    showArrow: true,
                    subtitle: Text.rich(
                      TextSpan(
                        text: AppStrings.trainingLibraryVisibilityPrefix,
                        children: [
                          TextSpan(
                            text: isPubliclyAvailable
                                ? AppStrings.trainingLibraryAllVisibility
                                : AppStrings
                                      .trainingLibraryRestrictedVisibility,
                            style: const TextStyle(
                              color: AppColors.secondaryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canEdit) ...[
                  _LessonActionTile(
                    title: AppStrings.trainingDeleteModuleAction,
                    icon: SvgPicture.asset(
                      '${AppStrings.imagePath}delete.svg',
                      width: 28,
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        AppColors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    iconBackground: AppColors.red1,
                    subtitle: const AppTextView.body(
                      AppStrings.trainingLibraryDeleteLessonDescription,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      height: 1.25,
                    ),
                    onTap: () => onSelected(TrainingLibraryLessonAction.delete),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonActionTile extends StatelessWidget {
  const _LessonActionTile({
    required this.title,
    required this.icon,
    required this.iconBackground,
    required this.subtitle,
    required this.onTap,
    this.showArrow = false,
  });

  final String title;
  final Widget icon;
  final Color iconBackground;
  final Widget subtitle;
  final VoidCallback? onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.trainingLessonActionSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 55,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextView.body1(
                        title,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      const SizedBox(height: 8),
                      subtitle,
                    ],
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.north_east,
                    color: AppColors.secondaryColor,
                    size: 30,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
