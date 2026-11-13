import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../models/shared_lms_content_model.dart';
import '../models/shared_lesson_content_model.dart';

class SharedLmsRemoteDataSource {
  SharedLmsRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

  Future<SharedLmsContentModel> getSharedLms(String publicId) {
    return _apiCallExecutor.processApi<SharedLmsContentModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.sharedContent(publicId),
      authToken: '',
      allowAutoRefresh: false,
      decoder: (json) {
        if (json is! Map) {
          throw const ApiError.invalidResponse();
        }
        return SharedLmsContentModel.fromApiJson(
          Map<String, dynamic>.from(json),
        );
      },
    );
  }

  Future<SharedLessonContentModel> getSharedLesson(
    String sharedContentId,
    String publicId,
  ) {
    return _apiCallExecutor.processApi<SharedLessonContentModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.sharedLesson(sharedContentId, publicId),
      authToken: '',
      allowAutoRefresh: false,
      decoder: (json) {
        if (json is! Map) {
          throw const ApiError.invalidResponse();
        }
        return SharedLessonContentModel.fromApiJson(
          Map<String, dynamic>.from(json),
        );
      },
    );
  }
}
