import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _GenerationRepository repository;

  setUp(() => repository = _GenerationRepository());

  Future<TrainingModuleController> initialize({
    bool canManageTraining = true,
  }) async {
    final controller = TrainingModuleController(
      repository,
      canManageTraining: canManageTraining,
    );
    addTearDown(controller.dispose);
    await controller.initialize(jobId: 'seat', descriptionId: 'description');
    return controller;
  }

  for (final transcript in <String?>[null, '', ' \n\t ']) {
    test(
      'missing or blank transcript blocks both generation API calls: $transcript',
      () async {
        repository.transcript = transcript;
        final controller = await initialize();

        expect(controller.hasSelectedModuleVideo, isTrue);
        expect(controller.canGenerateSopForSelectedModule, isFalse);
        expect(controller.canGenerateQuizForSelectedModule, isFalse);
        expect(await controller.generateSopForSelectedModule(), isFalse);
        expect(await controller.generateQuizForSelectedModule(), isFalse);
        expect(repository.generationRequests, isEmpty);
        expect(controller.isGeneratingSop, isFalse);
        expect(controller.isGeneratingQuiz, isFalse);
        expect(controller.canAddQuestionToSelectedModule, isTrue);
      },
    );
  }

  test(
    'generated summary enables SOP and Quiz while the cached transcript is blank',
    () async {
      final controller = await initialize();
      expect(controller.hasSelectedModuleVideoTranscript, isFalse);
      expect(controller.canGenerateSopForSelectedModule, isFalse);

      controller.applyGeneratedSummaryForModule(
        moduleId: 'module',
        description: '<p>Generated lesson summary</p>',
      );

      expect(controller.hasSelectedModuleSummary, isTrue);
      expect(controller.canGenerateSopForSelectedModule, isTrue);
      expect(controller.canGenerateQuizForSelectedModule, isTrue);
      expect(await controller.generateSopForSelectedModule(), isTrue);
      expect(await controller.generateQuizForSelectedModule(), isTrue);
      expect(repository.generationRequests, ['sop:module', 'quiz:module']);
    },
  );

  test('empty summary markup does not enable AI generation', () async {
    final controller = await initialize();
    controller.applyGeneratedSummaryForModule(
      moduleId: 'module',
      description: '<p><br>&nbsp;</p>',
    );

    expect(controller.hasSelectedModuleSummary, isFalse);
    expect(controller.canGenerateSopForSelectedModule, isFalse);
    expect(controller.canGenerateQuizForSelectedModule, isFalse);
    expect(repository.generationRequests, isEmpty);
  });

  test(
    'a nonblank transcript enables SOP and Quiz generation for the selected lesson',
    () async {
      repository.transcript = ' Follow these steps. ';
      final controller = await initialize();

      expect(controller.canGenerateSopForSelectedModule, isTrue);
      expect(controller.canGenerateQuizForSelectedModule, isTrue);
      expect(await controller.generateSopForSelectedModule(), isTrue);
      expect(await controller.generateQuizForSelectedModule(), isTrue);
      expect(repository.generationRequests, ['sop:module', 'quiz:module']);
    },
  );

  test(
    'a transcript does not grant generation access to a read-only viewer',
    () async {
      repository.transcript = 'Follow these steps.';
      final controller = await initialize(canManageTraining: false);

      expect(controller.canGenerateSopForSelectedModule, isFalse);
      expect(controller.canGenerateQuizForSelectedModule, isFalse);
      expect(await controller.generateSopForSelectedModule(), isFalse);
      expect(await controller.generateQuizForSelectedModule(), isFalse);
      expect(repository.generationRequests, isEmpty);
    },
  );

  test('assignment generation refreshes its instructions', () async {
    final controller = await initialize();

    expect(controller.canGenerateAssignmentForSelectedModule, isTrue);
    expect(await controller.generateAssignmentForSelectedModule(), isTrue);
    expect(repository.generationRequests, ['assignment:module']);
    expect(controller.selectedModuleAssignmentInstructions, '<p>Generated</p>');
    expect(controller.hasSelectedModuleAssignmentInstructions, isTrue);
    expect(controller.isGeneratingAssignment, isFalse);
  });

  test('assignment generation is unavailable to read-only viewers', () async {
    final controller = await initialize(canManageTraining: false);

    expect(controller.canGenerateAssignmentForSelectedModule, isFalse);
    expect(await controller.generateAssignmentForSelectedModule(), isFalse);
    expect(repository.generationRequests, isEmpty);
  });
}

class _GenerationRepository extends Fake implements AuditRepository {
  String? transcript;
  final generationRequests = <String>[];

  @override
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) async => const [
    SeatDescriptionTrainingModule(
      uuid: 'module',
      actualId: 'module',
      title: 'Lesson',
      thumbnailLink: null,
      isPubliclyAvailable: false,
    ),
  ];

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) async =>
      SeatDescriptionTrainingModuleDetail(
        uuid: moduleId,
        actualId: moduleId,
        title: 'Lesson',
        thumbnails: const [],
        description: null,
        assignmentTitle: null,
        assignmentInstructions: null,
        questions: const [],
        thumbnailLink: null,
        trainingVideo: SeatDescriptionTrainingVideo(
          uuid: 'video',
          title: 'Video',
          url: 'https://example.com/video.mp4',
          duration: 60,
          transcript: transcript,
        ),
        isPubliclyAvailable: false,
        learningTrackCount: 0,
      );

  @override
  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  }) async {
    generationRequests.add('sop:$moduleId');
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) async {
    generationRequests.add('assignment:$moduleId');
  }

  @override
  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) async => SeatDescriptionTrainingAssignment(
    uuid: '',
    title: null,
    instructions: generationRequests.contains('assignment:$moduleId')
        ? '<p>Generated</p>'
        : null,
  );

  @override
  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  }) async {
    generationRequests.add('quiz:$moduleId');
  }

  @override
  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) async =>
      const SeatDescriptionTrainingDocument(
        uuid: 'sop',
        text: '<p>Procedure</p>',
      );

  @override
  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId}) async =>
      const [];
}
