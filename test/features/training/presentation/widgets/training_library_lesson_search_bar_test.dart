import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_detail_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_search_bar.dart';

void main() {
  testWidgets(
    'typing and clearing keep the search height stable; arrow opens the selector',
    (tester) async {
      final controller = TrainingLibraryDetailController(
        initialModule: const TrainingLibraryModule(
          id: 'module',
          title: 'Training',
          description: '',
          department: TrainingLibraryDepartment(
            id: 'department',
            name: 'Department',
          ),
          totalDuration: 0,
          seat: TrainingLibrarySeat(id: 'seat', title: 'Seat'),
          lessons: [],
          thumbnailLink: null,
          category: TrainingLibraryCategory(id: 'category', title: 'Category'),
        ),
        getTrainingLibraryModules: GetTrainingLibraryModulesUseCase(
          _LibraryRepository(),
        ),
        trainingRepository: _TrainingLibraryRepository(),
        canManageSeatTraining: (_) => false,
        view: 'list',
      );
      addTearDown(controller.dispose);
      var openedSelector = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (_, __) => TrainingLibraryLessonSearchBar(
                controller: controller,
                onSelectLesson: () => openedSelector = true,
              ),
            ),
          ),
        ),
      );

      final field = find.byType(TextField);
      final emptyHeight = tester.getSize(field).height;
      await tester.enterText(field, 'Dental');
      await tester.pump();
      expect(controller.searchQuery, 'Dental');
      expect(tester.getSize(field).height, emptyHeight);

      await tester.enterText(field, '');
      await tester.pump();
      expect(tester.getSize(field).height, emptyHeight);

      await tester.tap(find.byTooltip(AppStrings.trainingLibrarySelectLesson));
      expect(openedSelector, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _LibraryRepository extends Fake implements TrainingLibraryRepository {}

class _TrainingLibraryRepository extends Fake
    implements TrainingLibraryRepository {}
