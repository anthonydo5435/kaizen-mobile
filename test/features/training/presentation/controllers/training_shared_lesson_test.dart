import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/entities/shared_lesson_content.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared lesson loads its detail directly from the link ID', () async {
    final repository = _SharedLessonRepository();
    final controller = TrainingModuleController(
      repository,
      sharedLessonDetailLoader: repository.getSharedLessonDetail,
    );
    addTearDown(controller.dispose);

    await controller.initializeSharedLesson(' lesson-123 ');

    expect(repository.requestedLessonId, 'lesson-123');
    expect(controller.selectedModuleId, 'lesson-123');
    expect(controller.selectedModuleDetail?.title, 'Shared lesson');
    expect(controller.modules.single.uuid, 'lesson-123');
    expect(controller.canAccessSelectedModuleExtras, isTrue);
    expect(controller.canManageTraining, isFalse);

    await controller.loadDocumentForSelectedModule();
    await controller.loadQuestionsForSelectedModule();
    await controller.loadAssignmentForSelectedModule();
    expect(controller.selectedModuleDocument?.text, '<p>SOP</p>');
    expect(controller.selectedModuleQuestions.single.question, 'Question?');
    expect(controller.selectedModuleAssignment?.title, 'Assignment');
  });

  test(
    'shared lesson shows the fetch error without creating a lesson',
    () async {
      final repository = _SharedLessonRepository(shouldFail: true);
      final controller = TrainingModuleController(
        repository,
        sharedLessonDetailLoader: repository.getSharedLessonDetail,
      );
      addTearDown(controller.dispose);

      await controller.initializeSharedLesson('missing-lesson');

      expect(repository.requestedLessonId, 'missing-lesson');
      expect(controller.modules, isEmpty);
      expect(
        controller.errorMessage,
        AppStrings.trainingSharedLessonUnavailable,
      );
      expect(controller.isLoading, isFalse);
    },
  );

  test('closing the viewer during a shared request is safe', () async {
    final repository = _SharedLessonRepository();
    final pendingDetail = Completer<SharedLessonContent>();
    final controller = TrainingModuleController(
      repository,
      sharedLessonDetailLoader: (_) => pendingDetail.future,
    );

    final initialization = controller.initializeSharedLesson('lesson-123');
    controller.dispose();
    pendingDetail.complete(
      await repository.getSharedLessonDetail('lesson-123'),
    );

    await initialization;
  });
}

class _SharedLessonRepository extends Fake implements AuditRepository {
  _SharedLessonRepository({this.shouldFail = false});

  final bool shouldFail;
  String? requestedLessonId;

  Future<SharedLessonContent> getSharedLessonDetail(String publicId) async {
    requestedLessonId = publicId;
    if (shouldFail) {
      throw StateError('Lesson unavailable');
    }
    return const SharedLessonContent(
      module: SeatDescriptionTrainingModuleDetail(
        uuid: 'lesson-123',
        actualId: '',
        title: 'Shared lesson',
        thumbnails: <String>[],
        description: 'Summary',
        assignmentTitle: 'Assignment',
        assignmentInstructions: null,
        questions: <SeatDescriptionTrainingQuestion>[
          SeatDescriptionTrainingQuestion(
            uuid: 'question-1',
            question: 'Question?',
            options: <SeatDescriptionTrainingQuestionOption>[],
            selectedOptionUuid: null,
            imageUrl: null,
          ),
        ],
        thumbnailLink: null,
        trainingVideo: null,
        isPubliclyAvailable: true,
        learningTrackCount: 0,
      ),
      document: SeatDescriptionTrainingDocument(uuid: '', text: '<p>SOP</p>'),
      assignment: SeatDescriptionTrainingAssignment(
        uuid: '',
        title: 'Assignment',
        instructions: null,
      ),
    );
  }

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) {
    throw StateError('Private lesson endpoint must not be called');
  }

  @override
  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) async {
    throw StateError('Private document endpoint must not be called');
  }
}
