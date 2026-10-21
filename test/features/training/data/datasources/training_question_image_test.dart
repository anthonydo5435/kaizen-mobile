import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/file_uploader.dart';
import 'package:sparrowkaizen/features/training/data/datasources/training_library_remote_data_source.dart';
import 'package:sparrowkaizen/features/training/data/repositories/training_library_repository_impl.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';

const _imageId = 'f2a25f92-c7a0-4f0d-8e48-d97b3ee83c20';
const _imageUrl = 'https://example.com/picture.jpg';
const _options = [
  SeatDescriptionTrainingQuestionOption(uuid: 'option-a', text: 'First'),
  SeatDescriptionTrainingQuestionOption(uuid: 'option-b', text: 'Second'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _QuestionApi api;
  late TrainingLibraryRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    api = _QuestionApi();
    repository = TrainingLibraryRepositoryImpl(
      TrainingLibraryRemoteDataSource(apiCallExecutor: api, fileUploader: _ImageUploader()),
    );
  });

  test('uses the upload response UUID in the question image payload', () async {
    final imageId = await repository.uploadTrainingQuestionImage(
      fileName: 'picture.jpg',
      fileBytes: [255, 216, 255],
      contentType: 'image/jpeg',
    );
    expect(imageId, _imageId);

    final question = await repository.addSeatDescriptionTrainingQuestion(
      moduleId: 'module',
      questionText: 'Question',
      options: _options,
      correctOptionUuid: 'option-b',
      imageId: imageId,
    );

    expect(api.parameters?['image'], _imageId);
    expect(api.parameters, isNot(contains('image_url')));
    expect(question.imageUrl, _imageUrl);
  });

  test('trims the image ID before sending it', () async {
    await repository.addSeatDescriptionTrainingQuestion(
      moduleId: 'module',
      questionText: 'Question',
      options: _options,
      correctOptionUuid: 'option-b',
      imageId: ' $_imageId ',
    );
    expect(api.parameters?['image'], _imageId);
  });

  for (final imageId in <String?>[null, ' ']) {
    test('omits image fields when the image ID is ${imageId == null ? 'null' : 'blank'}', () async {
      await repository.addSeatDescriptionTrainingQuestion(
        moduleId: 'module',
        questionText: 'Question',
        options: _options,
        correctOptionUuid: 'option-b',
        imageId: imageId,
      );
      expect(api.parameters, isNot(contains('image')));
      expect(api.parameters, isNot(contains('image_url')));
    });
  }
}

class _ImageUploader extends FileUploader {
  @override
  Future<UploadedImagePayload> uploadOnboardingImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
    String? authToken,
  }) async {
    expect(fileName, 'picture.jpg');
    expect(fileBytes, [255, 216, 255]);
    return const UploadedImagePayload(uuid: _imageId, image: _imageUrl);
  }
}

class _QuestionApi extends ApiCallExecutor {
  Map<String, dynamic>? parameters;

  @override
  Future<Response> processApi<Response>({
    required ApiCallType apiCallType,
    required String endpoint,
    required Response Function(dynamic json) decoder,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    String? authToken,
    bool allowAutoRefresh = true,
    bool allowConflictRetry = true,
    bool invalidateCacheBeforeRequest = false,
  }) async {
    this.parameters = parameters;
    return decoder({
      'uuid': 'question',
      'question': 'Question',
      'correct_option': 'option-b',
      'options': [
        {'uuid': 'option-a', 'text': 'First'},
        {'uuid': 'option-b', 'text': 'Second'},
      ],
      'image_url': _imageUrl,
    });
  }
}
