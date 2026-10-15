import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _QuestionRepository repository;
  late TrainingModuleController controller;

  setUp(() async {
    repository = _QuestionRepository();
    controller = TrainingModuleController(repository, canManageTraining: true);
    await controller.initialize(jobId: 'seat', descriptionId: 'description');
  });
  tearDown(() => controller.dispose());

  Future<File> imageFile() async {
    final directory = await Directory.systemTemp.createTemp('quiz-question-');
    addTearDown(() => directory.delete(recursive: true));
    return File('${directory.path}/picture.jpg').writeAsBytes([255, 216, 255]);
  }

  test('picture is uploaded before the question and the selected answer is retained', () async {
    expect(
      await controller.addQuestionToSelectedModule(
        questionText: ' How should the tool be used? ',
        optionTexts: [' Light pressure ', ' Heavy pressure '],
        correctOptionIndex: 1,
        questionImage: await imageFile(),
      ),
      isTrue,
    );

    expect(repository.calls, ['upload', 'create']);
    expect(repository.savedImageId, _QuestionRepository.imageId);
    final question = controller.selectedModuleQuestions.single;
    expect(question.imageUrl, _QuestionRepository.imageUrl);
    expect(question.question, 'How should the tool be used?');
    expect(question.options.map((option) => option.text), ['Light pressure', 'Heavy pressure']);
    expect(question.selectedOptionUuid, question.options[1].uuid);
    expect(controller.isAddingQuestion, isFalse);
  });

  test('question without a picture does not upload an image', () async {
    expect(
      await controller.addQuestionToSelectedModule(
        questionText: 'Question',
        optionTexts: ['A', 'B'],
        correctOptionIndex: 0,
      ),
      isTrue,
    );
    expect(repository.calls, ['create']);
    expect(repository.savedImageId, isNull);
    expect(controller.selectedModuleQuestions.single.imageUrl, isNull);
  });

  test('failed image upload does not create a partial question and allows retry', () async {
    repository.failUpload = true;
    final image = await imageFile();
    Future<bool> submit() => controller.addQuestionToSelectedModule(
      questionText: 'Question',
      optionTexts: ['A', 'B'],
      correctOptionIndex: 0,
      questionImage: image,
    );

    expect(await submit(), isFalse);
    expect(repository.calls, ['upload']);
    expect(controller.selectedModuleQuestions, isEmpty);
    expect(controller.questionsErrorMessage, isNotEmpty);
    expect(controller.isAddingQuestion, isFalse);

    repository.failUpload = false;
    expect(await submit(), isTrue);
    expect(controller.selectedModuleQuestions, hasLength(1));
  });
}

class _QuestionRepository extends Fake implements AuditRepository {
  static const imageId = 'f2a25f92-c7a0-4f0d-8e48-d97b3ee83c20';
  static const imageUrl = 'https://example.com/picture.jpg';
  final calls = <String>[];
  String? savedImageId;
  bool failUpload = false;

  @override
  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    calls.add('upload');
    expect(fileName, 'picture.jpg');
    expect(fileBytes, [255, 216, 255]);
    expect(contentType, 'image/jpeg');
    if (failUpload) throw StateError('Image upload failed');
    return imageId;
  }

  @override
  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  }) async {
    calls.add('create');
    savedImageId = imageId;
    expect(moduleId, 'module');
    return SeatDescriptionTrainingQuestion(
      uuid: 'question',
      question: questionText,
      options: options,
      selectedOptionUuid: correctOptionUuid,
      imageUrl: imageId == null ? null : imageUrl,
    );
  }

  @override
  Future<List<SeatDescriptionTrainingModule>> getSeatDescriptionTrainingModules({
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
  Future<SeatDescriptionTrainingModuleDetail> getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) async => const SeatDescriptionTrainingModuleDetail(
    uuid: 'module',
    actualId: 'module',
    title: 'Lesson',
    thumbnails: [],
    description: null,
    assignmentTitle: null,
    assignmentInstructions: null,
    questions: [],
    thumbnailLink: null,
    trainingVideo: SeatDescriptionTrainingVideo(
      uuid: 'video',
      title: 'Video',
      url: 'https://example.com/video.mp4',
      duration: 60,
      transcript: null,
    ),
    isPubliclyAvailable: false,
    learningTrackCount: 0,
  );
}
