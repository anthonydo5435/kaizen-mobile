import 'package:flutter/material.dart';

import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_detail_controller.dart';
import '../pages/edit_training_screen.dart';
import 'training_library_lesson_actions_sheet.dart';
import 'training_library_lesson_delete_dialog.dart';
import 'training_library_lesson_visibility_sheet.dart';

Future<void> showTrainingLibraryLessonActions(
  BuildContext context, {
  required TrainingLibraryDetailController controller,
  required TrainingLibraryLesson lesson,
}) => controller.showLessonActions(
  lesson,
  selectAction: (canEdit, isPubliclyAvailable) =>
      showTrainingLibraryLessonActionsSheet(
        context,
        canEdit: canEdit,
        showVisibility: !controller.module.isGeneral,
        isPubliclyAvailable: isPubliclyAvailable,
      ),
  openEditor: (route, lessonId, canManageTraining) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditTrainingScreen(
          trainingRoute: route,
          initialModuleId: lessonId,
          canManageTraining: canManageTraining,
          useNonBlockingVideoUpload: true,
        ),
      ),
    );
  },
  showVisibility: (selectedLesson) async {
    if (!context.mounted) return;
    await showTrainingLibraryLessonVisibilitySheet(
      context,
      lesson: selectedLesson,
      controller: controller.visibilityController,
      onApply: (value) =>
          controller.updateLessonVisibility(lesson: selectedLesson, isPubliclyAvailable: value),
    );
  },
  confirmDelete: (selectedLesson) async {
    if (!context.mounted) return null;
    return showTrainingLibraryLessonDeleteDialog(
      context,
      lesson: selectedLesson,
      controller: controller,
    );
  },
  showMessage: (message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  },
);
