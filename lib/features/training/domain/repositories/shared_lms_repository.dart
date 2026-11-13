import '../entities/shared_lms_content.dart';
import '../entities/shared_lesson_content.dart';

abstract class SharedLmsRepository {
  Future<SharedLmsContent> getSharedLms(String publicId);
  Future<SharedLessonContent> getSharedLesson(
    String sharedContentId,
    String publicId,
  );
}
