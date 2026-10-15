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
}
