import '../../domain/entities/seat_description_training.dart';
import '../../domain/entities/training_library_page.dart';
import '../../domain/entities/lms_public_link.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../datasources/training_library_remote_data_source.dart';

class TrainingLibraryRepositoryImpl implements TrainingLibraryRepository {
  const TrainingLibraryRepositoryImpl(this._remoteDataSource);

  final TrainingLibraryRemoteDataSource _remoteDataSource;

  @override
  Future<LmsPublicLink?> getLmsPublicLink(String descriptionId) =>
      _remoteDataSource.getLmsPublicLink(descriptionId);

  @override
  Future<void> deleteLmsPublicLink(String descriptionId) =>
      _remoteDataSource.deleteLmsPublicLink(descriptionId);

  @override
  Future<LmsPublicLink> createLmsPublicLink({
    required String descriptionId,
    required List<String> trainingModuleUuids,
  }) => _remoteDataSource.createLmsPublicLink(
    descriptionId: descriptionId,
    trainingModuleUuids: trainingModuleUuids,
  );

  @override
  Future<TrainingLibraryPage> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getTrainingLibraryModules(
      view: view,
      page: page,
      pageSize: pageSize,
      searchType: searchType,
      searchText: searchText,
      departmentId: departmentId,
      jobId: jobId,
      jobCategoryId: jobCategoryId,
      jobCategoryDescriptionId: jobCategoryDescriptionId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getSeatDescriptionTrainingModules(
      descriptionId: descriptionId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  }) {
    return _remoteDataSource.createSeatDescriptionTrainingModule(
      jobId: jobId,
      descriptionId: descriptionId,
      title: title,
    );
  }

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleDetail(
      moduleId: moduleId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleDocument(
      moduleId: moduleId,
    );
  }

  @override
  Future<String> getTrainingDocumentPdfUrl({required String documentId}) {
    return _remoteDataSource.getTrainingDocumentPdfUrl(documentId: documentId);
  }

  @override
  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
    );
  }

  @override
  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleQuestions(
      moduleId: moduleId,
    );
  }

  @override
  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  }) {
    return _remoteDataSource.addSeatDescriptionTrainingQuestion(
      moduleId: moduleId,
      questionText: questionText,
      options: options,
      correctOptionUuid: correctOptionUuid,
      imageId: imageId,
    );
  }

  @override
  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadTrainingQuestionImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleQuiz(
      moduleId: moduleId,
      numQuestions: numQuestions,
      optionsPerQuestion: optionsPerQuestion,
      difficultyLevel: difficultyLevel,
      replaceExistingQuestions: replaceExistingQuestions,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleSop(
      moduleId: moduleId,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
    );
  }

  @override
  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleSummary(
      moduleId: moduleId,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModule(
      moduleId: moduleId,
      title: title,
      description: description,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleSummary(
      moduleId: moduleId,
      description: description,
      isPubliclyAvailable: isPubliclyAvailable,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleVisibility(
      moduleId: moduleId,
      isPubliclyAvailable: isPubliclyAvailable,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleDocument(
      moduleId: moduleId,
      documentId: documentId,
      text: text,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
      assignmentId: assignmentId,
      title: title,
      instructions: instructions,
    );
  }

  @override
  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  }) {
    return _remoteDataSource
        .generateSeatDescriptionTrainingModuleVideoUploadUrl(
          fileName: fileName,
        );
  }

  @override
  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadSeatDescriptionTrainingModuleVideoFile(
      uploadUrl: uploadUrl,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  }) {
    return _remoteDataSource.addSeatDescriptionTrainingModuleVideo(
      moduleId: moduleId,
      videoUuid: videoUuid,
      title: title,
      videoUrl: videoUrl,
      duration: duration,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  }) {
    return _remoteDataSource.deleteSeatDescriptionTrainingModuleVideo(
      videoId: videoId,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleThumbnail(
      moduleId: moduleId,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId}) {
    return _remoteDataSource.deleteSeatDescriptionTrainingModule(
      moduleId: moduleId,
    );
  }

  @override
  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingQuestion(
      questionId: questionId,
      questionText: questionText,
      options: options,
      correctOptionUuid: correctOptionUuid,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
  }) {
    return _remoteDataSource.deleteSeatDescriptionTrainingQuestion(
      questionId: questionId,
    );
  }
}

TrainingLibraryRepositoryImpl createTrainingLibraryRepository(
  TrainingLibraryRemoteDataSource remoteDataSource,
) {
  return TrainingLibraryRepositoryImpl(remoteDataSource);
}
