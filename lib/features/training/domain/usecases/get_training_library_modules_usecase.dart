import '../entities/training_library_page.dart';
import '../repositories/training_library_repository.dart';

class GetTrainingLibraryModulesUseCase {
  const GetTrainingLibraryModulesUseCase(this._repository);

  final TrainingLibraryRepository _repository;

  Future<TrainingLibraryPage> call({
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
    return _repository.getTrainingLibraryModules(
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
}
