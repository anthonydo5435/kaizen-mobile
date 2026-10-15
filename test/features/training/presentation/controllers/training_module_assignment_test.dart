import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AssignmentRepository repository;
  late TrainingModuleController controller;

  setUp(() async {
    repository = _AssignmentRepository();
    controller = TrainingModuleController(repository, canManageTraining: true);
    await controller.initialize(jobId: 'seat', descriptionId: 'description');
    await controller.loadAssignmentForSelectedModule();
  });

  tearDown(() => controller.dispose());

  test(
    'saves an assignment with only a title and restores it after refresh',
    () async {
      controller.assignmentTitleController.text = '  Practice the procedure  ';

      expect(controller.canSaveSelectedModuleAssignment, isTrue);
      expect(await controller.saveAssignmentForSelectedModule(), isTrue);
      expect(
        repository.savedAssignments.single.title,
        'Practice the procedure',
      );
      expect(repository.savedAssignments.single.instructions, isEmpty);
      expect(
        controller.assignmentTitleController.text,
        'Practice the procedure',
      );
      expect(controller.hasPersistedSelectedModuleAssignment, isTrue);
    },
  );

  testWidgets('assignment edits autosave together after the debounce', (
    tester,
  ) async {
    repository.assignment = const SeatDescriptionTrainingAssignment(
      uuid: 'assignment',
      title: 'Practice the procedure',
      instructions: '<p>Original instructions</p>',
    );
    await controller.refreshAssignmentForSelectedModule();
    controller.assignmentDescriptionController.loadFromHtml(
      '<p>Follow the procedure</p>',
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.savedAssignments, isEmpty);
    controller.assignmentDescriptionController.text = 'Latest instructions';
    await tester.pump(const Duration(milliseconds: 399));
    expect(repository.savedAssignments, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.savedAssignments, hasLength(1));
    expect(repository.savedAssignments.single.title, 'Practice the procedure');
    expect(
      repository.savedAssignments.single.instructions,
      contains('Latest instructions'),
    );
    expect(repository.updatedAssignmentIds, <String?>['assignment']);
  });

  testWidgets(
    'moving the cursor does not postpone a pending PATCH or move it after saving',
    (tester) async {
      repository.assignment = const SeatDescriptionTrainingAssignment(
        uuid: 'assignment',
        title: 'Practice',
        instructions: '<p>Original instructions</p>',
      );
      await controller.refreshAssignmentForSelectedModule();
      controller.assignmentDescriptionController.text = 'Updated instructions';
      await tester.pump(const Duration(milliseconds: 300));
      const selection = TextSelection.collapsed(offset: 3);
      controller.assignmentDescriptionController.selection = selection;
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.updatedAssignmentIds, ['assignment']);
      expect(controller.assignmentDescriptionController.selection, selection);
      expect(controller.hasAssignmentChanges, isFalse);
    },
  );

  testWidgets(
    'edits during a PATCH are saved next without overwriting the draft',
    (tester) async {
      repository.assignment = const SeatDescriptionTrainingAssignment(
        uuid: 'assignment',
        title: 'Practice',
        instructions: '<p>Original instructions</p>',
      );
      await controller.refreshAssignmentForSelectedModule();
      final pendingSave = Completer<void>();
      repository.pendingSave = pendingSave;
      controller.assignmentDescriptionController.text = 'First edit';
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isSavingAssignment, isTrue);

      controller.assignmentDescriptionController.text = 'Latest edit';
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.savedAssignments, hasLength(1));
      pendingSave.complete();
      await tester.pump();
      expect(controller.assignmentDescriptionController.text, 'Latest edit');
      expect(controller.hasAssignmentChanges, isTrue);
      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.updatedAssignmentIds, ['assignment', 'assignment']);
      expect(
        repository.savedAssignments.last.instructions,
        contains('Latest edit'),
      );
      expect(controller.hasAssignmentChanges, isFalse);
    },
  );

  testWidgets('an in-flight PATCH may finish after the editor is disposed', (
    tester,
  ) async {
    final editor = TrainingModuleController(
      repository,
      canManageTraining: true,
    );
    await editor.initialize(jobId: 'seat', descriptionId: 'description');
    repository.assignment = const SeatDescriptionTrainingAssignment(
      uuid: 'assignment',
      title: 'Practice',
      instructions: '<p>Original instructions</p>',
    );
    await editor.loadAssignmentForSelectedModule();
    final pendingSave = Completer<void>();
    repository.pendingSave = pendingSave;
    editor.assignmentDescriptionController.text = 'Updated instructions';
    final saving = editor.saveAssignmentForSelectedModule();
    editor.dispose();
    pendingSave.complete();

    expect(await saving, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(repository.savedAssignments, hasLength(1));
  });

  test('instructions cannot be saved until a title is provided', () async {
    controller.assignmentDescriptionController.loadFromHtml(
      '<p><strong>Follow the procedure</strong></p>',
    );

    expect(controller.canSaveSelectedModuleAssignment, isFalse);
    expect(await controller.saveAssignmentForSelectedModule(), isFalse);
    expect(repository.savedAssignments, isEmpty);
    expect(
      controller.summarySnackBarMessage,
      AppStrings.trainingAssignmentTitleRequired,
    );
    expect(
      controller.assignmentDescriptionController.text,
      'Follow the procedure',
    );

    controller.assignmentTitleController.text = '  Practice the procedure  ';
    expect(controller.canSaveSelectedModuleAssignment, isTrue);
    expect(await controller.saveAssignmentForSelectedModule(), isTrue);
    expect(repository.savedAssignments.single.title, 'Practice the procedure');
    expect(
      repository.savedAssignments.single.instructions,
      contains('<strong>Follow the procedure</strong>'),
    );
    expect(
      controller.assignmentDescriptionController.text,
      'Follow the procedure',
    );
  });

  test('a whitespace-only title cannot save populated instructions', () async {
    controller.assignmentTitleController.text = '  \n ';
    controller.assignmentDescriptionController.text = 'Follow the procedure';

    expect(controller.canSaveSelectedModuleAssignment, isFalse);
    expect(await controller.saveAssignmentForSelectedModule(), isFalse);
    expect(repository.savedAssignments, isEmpty);
    expect(
      controller.summarySnackBarMessage,
      AppStrings.trainingAssignmentTitleRequired,
    );
  });

  test(
    'empty or whitespace-only fields never write to the repository',
    () async {
      controller.assignmentTitleController.text = '  ';
      controller.assignmentDescriptionController.text = '\n ';

      expect(controller.canSaveSelectedModuleAssignment, isFalse);
      expect(await controller.saveAssignmentForSelectedModule(), isFalse);
      expect(repository.savedAssignments, isEmpty);
    },
  );

  test(
    'save availability follows the title even when instructions are populated',
    () {
      final availability = <bool>[];
      controller.addListener(() {
        availability.add(controller.canSaveSelectedModuleAssignment);
      });

      controller.assignmentTitleController.text = 'Title';
      controller.assignmentTitleController.text = 'Updated title';
      controller.assignmentDescriptionController.text = 'Instructions';
      controller.assignmentTitleController.clear();
      expect(controller.canSaveSelectedModuleAssignment, isFalse);
      controller.assignmentDescriptionController.clear();

      expect(availability, <bool>[true, false]);
    },
  );

  test(
    'clearing a saved assignment title cannot update the existing assignment',
    () async {
      repository.assignment = const SeatDescriptionTrainingAssignment(
        uuid: 'assignment',
        title: 'Practice',
        instructions: '<p>Follow the procedure</p>',
      );
      await controller.refreshAssignmentForSelectedModule();
      final fetchCount = repository.assignmentFetchCount;
      controller.assignmentTitleController.clear();

      expect(controller.canSaveSelectedModuleAssignment, isFalse);
      expect(await controller.saveAssignmentForSelectedModule(), isFalse);
      expect(repository.savedAssignments, isEmpty);
      expect(repository.assignmentFetchCount, fetchCount);
      expect(repository.assignment.title, 'Practice');
      expect(
        controller.summarySnackBarMessage,
        AppStrings.trainingAssignmentTitleRequired,
      );
    },
  );

  test(
    'unchanged loaded content does not save or refresh the assignment',
    () async {
      repository.assignment = const SeatDescriptionTrainingAssignment(
        uuid: 'assignment',
        title: 'Practice',
        instructions: '<p><b>Follow the procedure</b></p>',
      );
      await controller.refreshAssignmentForSelectedModule();
      final fetchCount = repository.assignmentFetchCount;

      expect(controller.hasAssignmentChanges, isFalse);
      expect(await controller.saveAssignmentForSelectedModule(), isTrue);
      expect(repository.savedAssignments, isEmpty);
      expect(repository.assignmentFetchCount, fetchCount);
    },
  );

  test(
    'editing and restoring the original content does not save again',
    () async {
      controller.assignmentTitleController.text = 'Practice';
      controller.assignmentDescriptionController.text = 'Follow the procedure';
      await controller.saveAssignmentForSelectedModule();
      final fetchCount = repository.assignmentFetchCount;

      controller.assignmentTitleController.text = 'Changed';
      controller.assignmentDescriptionController.text = 'Changed instructions';
      expect(controller.hasAssignmentChanges, isTrue);
      controller.assignmentTitleController.text = '  Practice  ';
      controller.assignmentDescriptionController.text = 'Follow the procedure';

      expect(controller.hasAssignmentChanges, isFalse);
      expect(await controller.saveAssignmentForSelectedModule(), isTrue);
      expect(repository.savedAssignments, hasLength(1));
      expect(repository.assignmentFetchCount, fetchCount);
    },
  );

  test(
    'formatting-only edits save once and become the unchanged baseline',
    () async {
      repository.assignment = const SeatDescriptionTrainingAssignment(
        uuid: 'assignment',
        title: 'Practice',
        instructions: '<p>Follow the procedure</p>',
      );
      await controller.refreshAssignmentForSelectedModule();
      controller.assignmentDescriptionController.loadFromHtml(
        '<p><strong>Follow the procedure</strong></p>',
      );

      expect(controller.hasAssignmentChanges, isTrue);
      expect(await controller.saveAssignmentForSelectedModule(), isTrue);
      expect(
        repository.savedAssignments.single.instructions,
        contains('<strong>Follow the procedure</strong>'),
      );
      expect(controller.hasAssignmentChanges, isFalse);
      expect(await controller.saveAssignmentForSelectedModule(), isTrue);
      expect(repository.savedAssignments, hasLength(1));
    },
  );

  test('view-only access cannot save even when a field has content', () async {
    final viewer = TrainingModuleController(
      repository,
      canViewQuizAndAssignment: true,
    );
    addTearDown(viewer.dispose);
    await viewer.initialize(jobId: 'seat', descriptionId: 'description');
    await viewer.loadAssignmentForSelectedModule();
    viewer.assignmentTitleController.text = 'Title';

    expect(viewer.maxAccessibleTabIndex, 3);
    expect(viewer.canManageTraining, isFalse);
    expect(viewer.canEditSelectedModuleTitle, isFalse);
    expect(viewer.canEditSelectedModuleDocument, isFalse);
    expect(viewer.canSaveSelectedModuleAssignment, isFalse);
    expect(await viewer.saveAssignmentForSelectedModule(), isFalse);
    expect(repository.savedAssignments, isEmpty);
  });
}

class _AssignmentRepository extends Fake implements AuditRepository {
  final savedAssignments = <SeatDescriptionTrainingAssignment>[];
  final updatedAssignmentIds = <String?>[];
  int assignmentFetchCount = 0;
  Completer<void>? pendingSave;
  SeatDescriptionTrainingAssignment assignment =
      const SeatDescriptionTrainingAssignment(
        uuid: '',
        title: null,
        instructions: null,
      );

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
      const SeatDescriptionTrainingModuleDetail(
        uuid: 'module',
        actualId: 'module',
        title: 'Lesson',
        thumbnails: [],
        description: null,
        assignmentTitle: null,
        assignmentInstructions: null,
        questions: [],
        thumbnailLink: null,
        trainingVideo: null,
        isPubliclyAvailable: false,
        learningTrackCount: 0,
      );

  @override
  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId}) async {
    assignmentFetchCount += 1;
    return assignment;
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  }) async {
    updatedAssignmentIds.add(assignmentId);
    final updatedAssignment = SeatDescriptionTrainingAssignment(
      uuid: assignmentId ?? 'assignment',
      title: title ?? assignment.title,
      instructions: instructions,
    );
    savedAssignments.add(updatedAssignment);
    final pending = pendingSave;
    pendingSave = null;
    if (pending != null) await pending.future;
    assignment = updatedAssignment;
  }
}
