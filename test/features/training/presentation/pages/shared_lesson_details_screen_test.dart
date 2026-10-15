import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/entities/shared_lesson_content.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/shared_lms_repository.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  testWidgets('shared lesson shows all four read-only tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      Provider<TrainingSopEditorFactory>.value(
        value: TiptapSopFixture().create,
        child: MaterialApp(
          home: SharedLessonDetailsScreen(
            sharedContentId: 'shared-list',
            publicId: 'lesson-public-id',
            sharedLmsRepository: _SharedLessonRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shared lesson'), findsWidgets);
    expect(find.text(AppStrings.trainingNoVideoAvailable), findsOneWidget);
    final videoBounds = tester.getRect(find.byType(TrainingReadOnlyVideoTab));
    expect(videoBounds.left, 0);
    expect(videoBounds.right, 390);
    final titleBounds = tester.getRect(find.byType(TrainingLessonTitleField));
    expect(titleBounds.left, 8);
    expect(titleBounds.right, 390 - 8);
    final navigationBounds = tester.getRect(find.byType(TrainingTabs));
    expect(navigationBounds.left, 12);
    expect(navigationBounds.right, 390 - 12);
    expect(tester.takeException(), isNull);

    void expectNavigationSelection(String label) {
      final navigation = find.byType(TrainingTabs);
      final highlight = find.descendant(
        of: navigation,
        matching: find.byType(FractionallySizedBox),
      );
      final selectedLabel = find.descendant(
        of: navigation,
        matching: find.text(label),
      );
      expect(
        tester.getCenter(highlight).dx,
        closeTo(tester.getCenter(selectedLabel).dx, 0.1),
      );
    }

    expectNavigationSelection(AppStrings.trainingVideoTab);

    await tester.tap(find.text(AppStrings.trainingSopTab).last);
    await tester.pumpAndSettle();

    expect(find.text('Shared SOP'), findsOneWidget);
    final sopBounds = tester.getRect(find.byType(TrainingReadOnlySopTab));
    expect(sopBounds.left, 8);
    expect(sopBounds.right, 390 - 8);
    expectNavigationSelection(AppStrings.trainingSopTab);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(AppStrings.trainingQuizTab).last);
    await tester.pumpAndSettle();

    expect(find.text('Shared question?'), findsOneWidget);
    expectNavigationSelection(AppStrings.trainingQuizTab);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(AppStrings.trainingAssignmentTab).last);
    await tester.pumpAndSettle();

    expect(find.text('Shared assignment'), findsOneWidget);
    expectNavigationSelection(AppStrings.trainingAssignmentTab);
    expect(tester.getRect(find.byType(TrainingTabs)).bottom, 844 - 14);

    await tester.fling(find.byType(PageView), const Offset(320, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Shared question?'), findsOneWidget);
    expectNavigationSelection(AppStrings.trainingQuizTab);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing shared list ID shows an error without a request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SharedLessonDetailsScreen(
          sharedContentId: '',
          publicId: 'lesson-public-id',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.trainingSharedLessonUnavailable),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _SharedLessonRepository extends Fake implements SharedLmsRepository {
  @override
  Future<SharedLessonContent> getSharedLesson(
    String sharedContentId,
    String publicId,
  ) async {
    assert(sharedContentId == 'shared-list');
    assert(publicId == 'lesson-public-id');
    return const SharedLessonContent(
      module: SeatDescriptionTrainingModuleDetail(
        uuid: 'lesson-public-id',
        actualId: '',
        title: 'Shared lesson',
        thumbnails: <String>[],
        description: 'Summary',
        assignmentTitle: 'Shared assignment',
        assignmentInstructions: '<p>Assignment instructions</p>',
        questions: <SeatDescriptionTrainingQuestion>[
          SeatDescriptionTrainingQuestion(
            uuid: 'question-1',
            question: 'Shared question?',
            options: <SeatDescriptionTrainingQuestionOption>[
              SeatDescriptionTrainingQuestionOption(
                uuid: 'option-1',
                text: 'Answer',
              ),
            ],
            selectedOptionUuid: null,
            imageUrl: null,
          ),
        ],
        thumbnailLink: null,
        trainingVideo: null,
        isPubliclyAvailable: true,
        learningTrackCount: 0,
      ),
      document: SeatDescriptionTrainingDocument(
        uuid: '',
        text: '<p>Shared SOP</p>',
      ),
      assignment: SeatDescriptionTrainingAssignment(
        uuid: '',
        title: 'Shared assignment',
        instructions: '<p>Assignment instructions</p>',
      ),
    );
  }
}
