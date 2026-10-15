import 'package:flutter/material.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_search_bar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_detail_controller.dart';
import 'training_library_lesson_grid.dart';

class TrainingLibraryDetailView extends StatelessWidget {
  const TrainingLibraryDetailView({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSelectLesson,
    required this.onLessonTap,
    required this.onLessonActions,
  });

  final VoidCallback onBack;
  final TrainingLibraryDetailController controller;
  final VoidCallback onSelectLesson;
  final Future<void> Function(TrainingLibraryLesson lesson) onLessonTap;
  final Future<void> Function(TrainingLibraryLesson lesson) onLessonActions;

  @override
  Widget build(BuildContext context) {
    final isBusy = controller.isBusy;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBg,
        appBar: AppBar(
          backgroundColor: AppColors.mainBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 40,
          leading: isBusy ? null : AppBackButton(onPressed: onBack),
          title: const AppTextView.title1(
            AppStrings.trainingLibraryTitle,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: isBusy
              ? Center(child: FastCircularProgressIndicator(width: 24, height: 24))
              : _TrainingLibraryLessons(
                  controller: controller,
                  onSelectLesson: onSelectLesson,
                  onLessonTap: onLessonTap,
                  onLessonActions: onLessonActions,
                ),
        ),
      ),
    );
  }
}

class _TrainingLibraryLessons extends StatelessWidget {
  const _TrainingLibraryLessons({
    required this.controller,
    required this.onSelectLesson,
    required this.onLessonTap,
    required this.onLessonActions,
  });

  final TrainingLibraryDetailController controller;
  final VoidCallback onSelectLesson;
  final Future<void> Function(TrainingLibraryLesson lesson) onLessonTap;
  final Future<void> Function(TrainingLibraryLesson lesson) onLessonActions;

  @override
  Widget build(BuildContext context) {
    final lessons = controller.visibleLessons;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Column(
            children: [
              TrainingLibraryLessonSearchBar(controller: controller, onSelectLesson: onSelectLesson),
              const SizedBox(height: 28),
              Expanded(
                child: lessons.isEmpty
                    ? Center(
                        child: AppTextView.body(
                          controller.emptyMessage,
                          color: AppColors.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : TrainingLibraryLessonGrid(
                        lessons: lessons,
                        onLessonTap: onLessonTap,
                        onLessonActions: controller.canManageTraining ? onLessonActions : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
