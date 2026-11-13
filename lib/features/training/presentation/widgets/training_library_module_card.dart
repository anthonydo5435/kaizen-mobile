import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_controller.dart';
import '../controllers/training_library_thumbnail_controller.dart';

/// Keeps the thumbnail behind the content while allowing larger text to grow
/// the list card beyond its minimum image height.
class TrainingLibraryModuleCard extends StatelessWidget {
  const TrainingLibraryModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    this.onLongPress,
  }) : sharedTitle = null,
       sharedThumbnailLink = null,
       sharedDuration = 0;

  const TrainingLibraryModuleCard.shared({
    super.key,
    required this.sharedTitle,
    required this.sharedThumbnailLink,
    required this.onTap,
    this.sharedDuration = 0,
  }) : module = null,
       onLongPress = null;

  final TrainingLibraryModule? module;
  final String? sharedTitle;
  final String? sharedThumbnailLink;
  final int sharedDuration;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final module = this.module;
    final resolvedSharedTitle = sharedTitle?.trim() ?? '';
    final title = module == null
        ? (resolvedSharedTitle.isEmpty
              ? AppStrings.sharedLmsUntitledLesson
              : resolvedSharedTitle)
        : TrainingLibraryController.displayModuleTitle(module);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          color: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: _ModuleThumbnail(
                  thumbnailLink: module?.thumbnailLink ?? sharedThumbnailLink,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.4, 1],
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : (constraints.maxWidth / 1.9).clamp(176.0, 280.0) + 24,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (module != null) ...[
                        _ModuleSeatLabel(seatTitle: module.seat.title),
                        const SizedBox(height: 3),
                      ],
                      AppTextView.body1(
                        title,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AppTextView.body2(
                        TrainingLibraryController.displayDuration(
                          module?.totalDuration ?? sharedDuration,
                        ),
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    child: Semantics(
                      button: true,
                      label: title,
                      hint: onLongPress == null
                          ? null
                          : AppStrings.trainingLibraryLessonActionsHint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleSeatLabel extends StatelessWidget {
  const _ModuleSeatLabel({required this.seatTitle});

  final String seatTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppTextView.body(
          AppStrings.trainingLibrarySeatPrefix,
          color: AppColors.secondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        Expanded(
          child: AppTextView.body(
            TrainingLibraryController.displayModuleValue(seatTitle),
            color: AppColors.textPrimary,
            fontSize: 13,
            maxLines: 1,
            fontWeight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ModuleThumbnail extends StatelessWidget {
  const _ModuleThumbnail({required this.thumbnailLink});

  final String? thumbnailLink;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(thumbnailLink);

    return imageUrl == null
        ? const _ImagePlaceholder()
        : Image(
            image: TrainingLibraryThumbnailController.imageProvider(imageUrl),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, _) =>
                frame == null ? const _ImagePlaceholder() : child,
            errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
          );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppStrings.imagePath}fallback.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return const Center(
          child: Icon(
            Icons.video_library_rounded,
            color: AppColors.textSecondary,
            size: 30,
          ),
        );
      },
    );
  }
}
