import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _DocumentRepository repository;
  late TrainingModuleController controller;

  setUp(() async {
    repository = _DocumentRepository();
    controller = TrainingModuleController(repository, canManageTraining: true);
    await controller.initialize(jobId: 'seat', descriptionId: 'description');
  });
  tearDown(() => controller.dispose());

  test('an unloaded SOP remains unresolved until the API confirms empty content', () async {
    expect(controller.hasResolvedSelectedModuleDocument, isFalse);
    final loading = controller.loadDocumentForSelectedModule();
    expect(controller.isDocumentLoading, isTrue);
    expect(controller.hasResolvedSelectedModuleDocument, isFalse);
    await controller.loadDocumentForSelectedModule();
    expect(repository.requests, hasLength(1));

    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: '', text: null),
    );
    await loading;
    expect(controller.isDocumentLoading, isFalse);
    expect(controller.hasResolvedSelectedModuleDocument, isTrue);
    expect(controller.selectedModuleDocument!.text, isNull);

    await controller.loadDocumentForSelectedModule();
    expect(repository.requests, hasLength(1));
  });

  test('a completed request publishes SOP content and its editor text', () async {
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'document', text: '<p>Follow the procedure.</p>'),
    );
    await loading;
    expect(controller.hasResolvedSelectedModuleDocument, isTrue);
    expect(controller.isDocumentLoading, isFalse);
    expect(controller.documentController.text, 'Follow the procedure.');
  });

  test('an API failure resolves to an error and a retry returns to loading', () async {
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.completeError(StateError('Unable to load SOP'));
    await loading;
    expect(controller.hasResolvedSelectedModuleDocument, isTrue);
    expect(controller.documentErrorMessage, contains('Unable to load SOP'));
    expect(controller.isDocumentLoading, isFalse);

    final retry = controller.loadDocumentForSelectedModule();
    expect(controller.documentErrorMessage, isNull);
    expect(controller.hasResolvedSelectedModuleDocument, isFalse);
    expect(controller.isDocumentLoading, isTrue);
    repository.requests.last.complete(const SeatDescriptionTrainingDocument(uuid: '', text: null));
    await retry;
  });

  test('a previous lesson response cannot replace the current SOP or stop its loader', () async {
    final firstLoading = controller.loadDocumentForSelectedModule();
    await controller.selectModule('second');
    expect(controller.hasResolvedSelectedModuleDocument, isFalse);
    final secondLoading = controller.loadDocumentForSelectedModule();
    expect(repository.requests, hasLength(2));

    repository.requests.first.complete(
      const SeatDescriptionTrainingDocument(uuid: 'old', text: '<p>Old lesson</p>'),
    );
    await firstLoading;
    expect(controller.selectedModuleDocument, isNull);
    expect(controller.isDocumentLoading, isTrue);
    expect(controller.hasResolvedSelectedModuleDocument, isFalse);

    repository.requests.last.complete(
      const SeatDescriptionTrainingDocument(uuid: 'current', text: '<p>Current lesson</p>'),
    );
    await secondLoading;
    expect(controller.selectedModuleDocument!.uuid, 'current');
    expect(controller.documentController.text, 'Current lesson');
    expect(controller.isDocumentLoading, isFalse);
  });
  testWidgets('original HTML loads without writes and formatted edits debounce as HTML', (
    tester,
  ) async {
    const original =
        '<h2>Procedure</h2><p>First<br><br>Second</p><p></p>'
        '<ul><li><p><strong>Check</strong></p></li></ul>';
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'document', text: original),
    );
    await loading;
    expect(controller.documentHtml, original);
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.writes, isEmpty);

    const edited =
        '<h2>Procedure</h2><p>First<br><br>Second</p><p></p>'
        '<ul><li><p><strong><em>Check</em></strong></p></li></ul>';
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: controller.documentEditorVersion,
      html: '<p>Intermediate edit</p>',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.writes, isEmpty);
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: controller.documentEditorVersion,
      html: edited,
    );
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.writes.single, {
      'moduleId': 'first',
      'documentId': 'document',
      'text': edited,
    });
    expect(controller.selectedModuleDocument!.text, edited);
  });

  testWidgets('callbacks from a previous editor cannot schedule a write for another lesson', (
    tester,
  ) async {
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'document', text: '<p>First</p>'),
    );
    await loading;
    final previousEditorVersion = controller.documentEditorVersion;
    await controller.selectModule('second');
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: previousEditorVersion,
      html: '<p>Late edit</p>',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.writes, isEmpty);
    expect(controller.documentHtml, isEmpty);
  });

  testWidgets('read-only training rejects HTML updates', (tester) async {
    final readOnlyRepository = _DocumentRepository();
    final readOnlyController = TrainingModuleController(readOnlyRepository);
    addTearDown(readOnlyController.dispose);
    await readOnlyController.initialize(jobId: 'seat', descriptionId: 'description');
    final loading = readOnlyController.loadDocumentForSelectedModule();
    readOnlyRepository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'document', text: '<p>Original</p>'),
    );
    await loading;
    readOnlyController.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: readOnlyController.documentEditorVersion,
      html: '<p>Forbidden edit</p>',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(readOnlyController.documentHtml, '<p>Original</p>');
    expect(readOnlyRepository.writes, isEmpty);
  });

  testWidgets('new typing during a save is saved after the first request finishes', (tester) async {
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'document', text: '<p>Original</p>'),
    );
    await loading;
    final pending = Completer<void>();
    repository.nextSave = pending.future;
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: controller.documentEditorVersion,
      html: '<p>One</p>',
    );
    await tester.pump(const Duration(milliseconds: 350));
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: controller.documentEditorVersion,
      html: '<p>Two</p>',
    );
    expect(repository.writes, hasLength(1));
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.writes.map((write) => write['text']), ['<p>One</p>', '<p>Two</p>']);
  });

  testWidgets('a save response from a previous lesson cannot replace the current document', (
    tester,
  ) async {
    final loading = controller.loadDocumentForSelectedModule();
    repository.requests.single.complete(
      const SeatDescriptionTrainingDocument(uuid: 'first-document', text: '<p>First</p>'),
    );
    await loading;
    final pending = Completer<void>();
    repository.nextSave = pending.future;
    controller.updateDocumentHtml(
      moduleId: 'first',
      editorVersion: controller.documentEditorVersion,
      html: '<p>Edited first</p>',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await controller.selectModule('second');
    final secondLoading = controller.loadDocumentForSelectedModule();
    repository.requests.last.complete(
      const SeatDescriptionTrainingDocument(uuid: 'second-document', text: '<h2>Second</h2>'),
    );
    await secondLoading;
    pending.complete();
    await tester.pump();
    expect(controller.selectedModuleDocument!.uuid, 'second-document');
    expect(controller.documentHtml, '<h2>Second</h2>');
    expect(controller.isSavingDocument, isFalse);
  });
}

class _DocumentRepository extends Fake implements AuditRepository {
  final requests = <Completer<SeatDescriptionTrainingDocument>>[];
  final writes = <Map<String, String>>[];
  Future<void>? nextSave;

  @override
  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  }) async {
    writes.add({'moduleId': moduleId, 'documentId': documentId, 'text': text});
    final pending = nextSave;
    nextSave = null;
    if (pending != null) await pending;
  }

  @override
  Future<SeatDescriptionTrainingDocument> getSeatDescriptionTrainingModuleDocument({
    required String moduleId,
  }) {
    final request = Completer<SeatDescriptionTrainingDocument>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<SeatDescriptionTrainingModule>> getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) async => const [
    SeatDescriptionTrainingModule(
      uuid: 'first',
      actualId: 'first',
      title: 'First lesson',
      thumbnailLink: null,
      isPubliclyAvailable: false,
    ),
    SeatDescriptionTrainingModule(
      uuid: 'second',
      actualId: 'second',
      title: 'Second lesson',
      thumbnailLink: null,
      isPubliclyAvailable: false,
    ),
  ];

  @override
  Future<SeatDescriptionTrainingModuleDetail> getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) async => SeatDescriptionTrainingModuleDetail(
    uuid: moduleId,
    actualId: moduleId,
    title: moduleId,
    thumbnails: const [],
    description: null,
    assignmentTitle: null,
    assignmentInstructions: null,
    questions: const [],
    thumbnailLink: null,
    trainingVideo: null,
    isPubliclyAvailable: false,
    learningTrackCount: 0,
  );
}
