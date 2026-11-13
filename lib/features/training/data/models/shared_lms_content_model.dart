import '../../../../core/network/api_error.dart';
import '../../domain/entities/shared_lms_content.dart';

class SharedLmsContentModel extends SharedLmsContent {
  const SharedLmsContentModel({
    required super.title,
    required super.categoryTitle,
    required super.description,
    required super.lessons,
  });

  factory SharedLmsContentModel.fromApiJson(Map<String, dynamic> json) {
    if (json['view_type'] != 'lms' || json['content'] is! Map) {
      throw const ApiError.invalidResponse();
    }

    final content = Map<String, dynamic>.from(json['content'] as Map);
    final rawLessons = content['modules'];
    if (rawLessons is! List) {
      throw const ApiError.invalidResponse();
    }

    final lessons = rawLessons
        .whereType<Map>()
        .map(
          (item) =>
              SharedLmsLessonModel.fromApiJson(Map<String, dynamic>.from(item)),
        )
        .where((lesson) => lesson.publicId.isNotEmpty)
        .toList(growable: false);

    return SharedLmsContentModel(
      title: _readString(content['title']),
      categoryTitle: _readString(content['category_title']),
      description: _readString(content['description']),
      lessons: lessons,
    );
  }
}

class SharedLmsLessonModel extends SharedLmsLesson {
  const SharedLmsLessonModel({
    required super.publicId,
    required super.title,
    required super.thumbnailUrl,
    super.duration,
  });

  factory SharedLmsLessonModel.fromApiJson(Map<String, dynamic> json) {
    final thumbnailUrl = _readString(json['thumbnail_url']);
    return SharedLmsLessonModel(
      publicId: _readString(json['public_id']),
      title: _readString(json['title']),
      thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
      duration: _readDuration(json['duration']),
    );
  }
}

String _readString(Object? value) => value?.toString().trim() ?? '';

int _readDuration(Object? value) {
  final seconds = value is num ? value : num.tryParse(_readString(value));
  if (seconds == null || !seconds.isFinite || seconds < 0) return 0;
  return seconds.round();
}
