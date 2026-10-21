import '../entities/seat_description_training.dart';
import '../entities/training_library_page.dart';
import '../entities/lms_public_link.dart';

abstract class TrainingLibraryRepository {
  Future<LmsPublicLink?> getLmsPublicLink(String descriptionId);

  Future<void> deleteLmsPublicLink(String descriptionId);

  Future<LmsPublicLink> createLmsPublicLink({
    required String descriptionId,
    required List<String> trainingModuleUuids,
  });

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
  });
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  });

  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  });

  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  });

  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId});

  Future<String> getTrainingDocumentPdfUrl({required String documentId});

  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId});

  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId});

  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  });

  /// Returns the uploaded image UUID to attach when creating a quiz question.
  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  });

  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  });

  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  });

  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  });

  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  });

  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  });

  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  });

  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  });

  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  });

  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  });

  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  });

  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  });

  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  });

  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId});

  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  });

  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
  });
}
