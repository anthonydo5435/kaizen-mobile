import 'package:flutter/material.dart';

import '../../../../core/managers/app_manager.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../domain/entities/training_library_module.dart';
import '../../domain/usecases/get_training_library_modules_usecase.dart';
import '../controllers/training_library_detail_controller.dart';
import '../widgets/training_library_detail_view.dart';
import '../widgets/training_library_lesson_actions.dart';
import '../widgets/training_library_lesson_selection_sheet.dart';
import 'shared_lesson_details_screen.dart';

class TrainingLibraryDetailScreen extends StatefulWidget {
  const TrainingLibraryDetailScreen({super.key, required this.module, required this.view});

  final TrainingLibraryModule module;
  final String view;

  @override
  State<TrainingLibraryDetailScreen> createState() => _TrainingLibraryDetailScreenState();
}

class _TrainingLibraryDetailScreenState extends State<TrainingLibraryDetailScreen> {
  late final TrainingLibraryDetailController _detailController;

  @override
  void initState() {
    super.initState();
    final trainingRepository = TrainingLibraryRepositoryImpl(TrainingLibraryRemoteDataSource());
    _detailController = TrainingLibraryDetailController(
      initialModule: widget.module,
      getTrainingLibraryModules: GetTrainingLibraryModulesUseCase(trainingRepository),
      trainingRepository: trainingRepository,
      canManageSeatTraining: (seatProfileId) => AppManager.instance
          .canCurrentUserManageTrainingForSeatProfile(seatProfileId: seatProfileId),
      view: widget.view,
    );
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _detailController;

    return AnimatedBuilder(
      animation: Listenable.merge([controller, AppManager.instance]),
      builder: (context, _) => TrainingLibraryDetailView(
        controller: controller,
        onBack: () => Navigator.of(context).pop(controller.navigationResult),
        onSelectLesson: () => controller.selectLesson(
          select: (lessons) => showTrainingLibraryLessonSelectionSheet(context, lessons: lessons),
          openViewer: (route) => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TrainingLessonViewerScreen(trainingRoute: route),
            ),
          ),
        ),
        onLessonTap: (lesson) => controller.openLessonViewer(
          lesson,
          openViewer: (route) => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TrainingLessonViewerScreen(trainingRoute: route),
            ),
          ),
        ),
        onLessonActions: (lesson) =>
            showTrainingLibraryLessonActions(context, controller: controller, lesson: lesson),
      ),
    );
  }
}
