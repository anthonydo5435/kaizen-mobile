import '../../domain/entities/shared_lms_content.dart';
import '../../domain/entities/shared_lesson_content.dart';
import '../../domain/repositories/shared_lms_repository.dart';
import '../datasources/shared_lms_remote_data_source.dart';

class SharedLmsRepositoryImpl implements SharedLmsRepository {
  const SharedLmsRepositoryImpl(this._remoteDataSource);

  final SharedLmsRemoteDataSource _remoteDataSource;

  @override
  Future<SharedLmsContent> getSharedLms(String publicId) {
    return _remoteDataSource.getSharedLms(publicId);
  }

  @override
  Future<SharedLessonContent> getSharedLesson(
    String sharedContentId,
    String publicId,
  ) {
    return _remoteDataSource.getSharedLesson(sharedContentId, publicId);
  }
}
