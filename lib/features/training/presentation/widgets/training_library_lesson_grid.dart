import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_detail_controller.dart';

class TrainingLibraryLessonGrid extends StatelessWidget {
  const TrainingLibraryLessonGrid({
    super.key,
    required this.lessons,
    required this.onLessonTap,
    required this.onLessonActions,
  });

  final List<TrainingLibraryLesson> lessons;
  final Future<void> Function(TrainingLibraryLesson) onLessonTap;
  final Future<void> Function(TrainingLibraryLesson)? onLessonActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final sizingWidth = ((constraints.maxWidth - gap) / 2).clamp(0.0, 220.0);
        final textScaler = MediaQuery.textScalerOf(context);
        final extraTextHeight =
            (textScaler.scale(16) - 16).clamp(0.0, double.infinity) * 2.4 +
            (textScaler.scale(13) - 13).clamp(0.0, double.infinity) * 3.75;

        // Each group keeps the next pair aligned while alternating tall/short cards.
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: (lessons.length + 3) ~/ 4,
          separatorBuilder: (_, __) => const SizedBox(height: gap),
          itemBuilder: (context, group) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      children: [
                        for (var row = 0; row < 2; row++)
                          if (group * 4 + row * 2 + column < lessons.length) ...[
                            if (row > 0) const SizedBox(height: gap),
                            _TrainingLibraryLessonCard(
                              key: ValueKey(lessons[group * 4 + row * 2 + column].id),
                              lesson: lessons[group * 4 + row * 2 + column],
                              height: sizingWidth * (row == column ? 1.85 : 1.27) + extraTextHeight,
                              summaryLines: row == column ? 3 : 2,
                              sortOrder: (group * 4 + row * 2 + column).toDouble(),
                              onTap: onLessonTap,
                              onActions: onLessonActions,
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _TrainingLibraryLessonCard extends StatefulWidget {
  const _TrainingLibraryLessonCard({
    super.key,
    required this.lesson,
    required this.height,
    required this.summaryLines,
    required this.sortOrder,
    required this.onTap,
    required this.onActions,
  });

  final TrainingLibraryLesson lesson;
  final double height;
  final int summaryLines;
  final double sortOrder;
  final Future<void> Function(TrainingLibraryLesson) onTap;
  final Future<void> Function(TrainingLibraryLesson)? onActions;

  @override
  State<_TrainingLibraryLessonCard> createState() => _TrainingLibraryLessonCardState();
}

class _TrainingLibraryLessonCardState extends State<_TrainingLibraryLessonCard> {
  final WidgetStatesController _interactionStates = WidgetStatesController();
  final ValueNotifier<bool> _isActionOpen = ValueNotifier(false);

  @override
  void dispose() {
    _interactionStates.dispose();
    _isActionOpen.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function(TrainingLibraryLesson) action) async {
    if (_isActionOpen.value) {
      return;
    }
    _isActionOpen.value = true;
    try {
      await action(widget.lesson);
    } finally {
      if (mounted) {
        _isActionOpen.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_interactionStates, _isActionOpen]),
      builder: (context, _) => _buildCard(
        context,
        isHighlighted:
            _isActionOpen.value || _interactionStates.value.contains(WidgetState.pressed),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required bool isHighlighted}) {
    final lesson = widget.lesson;
    final title = TrainingLibraryDetailController.displayLessonTitle(lesson);
    final onActions = widget.onActions;

    return Semantics(
      sortKey: OrdinalSortKey(widget.sortOrder),
      button: true,
      selected: isHighlighted,
      label: title,
      hint: onActions != null ? AppStrings.trainingLibraryLessonActionsHint : null,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Material(
          color: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LessonThumbnail(thumbnailLink: lesson.thumbnailLink),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isHighlighted
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0, 0.55, 1],
                          colors: [
                            AppColors.bgGlow.withValues(alpha: 0.35),
                            AppColors.trainingLessonPressedPurple.withValues(alpha: 0.75),
                            AppColors.trainingLessonPressedPurple,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.45, 1],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextView.body(
                        title,
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lesson.hasDescription) ...[
                        const SizedBox(height: 3),
                        AppTextView.body(
                          TrainingLibraryDetailController.displayLessonDescription(lesson),
                          color: AppColors.lightGrey2,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                          maxLines: widget.summaryLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  statesController: _interactionStates,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                  onTap: () => _runAction(widget.onTap),
                  onLongPress: onActions != null ? () => _runAction(onActions) : null,
                ),
              ),
              if (isHighlighted)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightPurple1, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonThumbnail extends StatelessWidget {
  const _LessonThumbnail({required this.thumbnailLink});

  final String? thumbnailLink;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(thumbnailLink);
    return imageUrl == null
        ? const _LessonImagePlaceholder()
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const _LessonImagePlaceholder(),
            errorWidget: (_, __, ___) => const _LessonImagePlaceholder(),
          );
  }
}

class _LessonImagePlaceholder extends StatelessWidget {
  const _LessonImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppStrings.imagePath}fallback.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.play_circle_outline_rounded, color: AppColors.textSecondary, size: 28),
      ),
    );
  }
}
