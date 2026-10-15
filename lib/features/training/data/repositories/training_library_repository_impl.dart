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
}

TrainingLibraryRepositoryImpl createTrainingLibraryRepository(
  TrainingLibraryRemoteDataSource remoteDataSource,
) {
  return TrainingLibraryRepositoryImpl(remoteDataSource);
}
