import '../../../../core/network/api_error.dart';
import '../../domain/entities/seat_description_training.dart';
import '../../domain/entities/shared_lesson_content.dart';

class SharedLessonContentModel extends SharedLessonContent {
  const SharedLessonContentModel({
    required super.module,
    required super.document,
    required super.assignment,
  });

  factory SharedLessonContentModel.fromApiJson(Map<String, dynamic> json) {
    if (json['view_type'] != 'lms' || json['module'] is! Map) {
      throw const ApiError.invalidResponse();
    }

    final module = Map<String, dynamic>.from(json['module'] as Map);
    final publicId = _readString(module['public_id']) ?? '';
    final video = module['video'] is Map
        ? Map<String, dynamic>.from(module['video'] as Map)
        : null;
    final document = module['document'] is Map
        ? Map<String, dynamic>.from(module['document'] as Map)
        : null;
    final assignment = module['assignment'] is Map
        ? Map<String, dynamic>.from(module['assignment'] as Map)
        : null;
    final assignmentTitle =
        _readString(assignment?['title']) ?? _readString(assignment?['name']);
    final assignmentInstructions =
        _readString(assignment?['instructions']) ??
        _readString(assignment?['description']) ??
        _readString(assignment?['text']);
    final questions = module['questions'] is List
        ? (module['questions'] as List)
              .whereType<Map>()
              .toList(growable: false)
              .asMap()
              .entries
              .map(
                (entry) => _questionFromApiJson(
                  Map<String, dynamic>.from(entry.value),
                  publicId: publicId,
                  index: entry.key,
                ),
              )
              .toList(growable: false)
        : const <SeatDescriptionTrainingQuestion>[];

    return SharedLessonContentModel(
      module: SeatDescriptionTrainingModuleDetail(
        uuid: publicId,
        actualId: '',
        title: _readString(module['title']) ?? '',
        thumbnails: const <String>[],
        description: _readString(module['summary']),
        assignmentTitle: assignmentTitle,
        assignmentInstructions: assignmentInstructions,
        questions: questions,
        thumbnailLink: _readString(module['thumbnail_url']),
        trainingVideo: video == null
            ? null
            : SeatDescriptionTrainingVideo(
                uuid: '',
                title: _readString(video['title']) ?? '',
                url: _readString(video['url']),
                duration: 0,
                transcript: null,
              ),
        isPubliclyAvailable: true,
        learningTrackCount: 0,
      ),
      document: SeatDescriptionTrainingDocument(
        uuid: '',
        text: _readString(document?['text']),
      ),
      assignment: SeatDescriptionTrainingAssignment(
        uuid: '',
        title: assignmentTitle,
        instructions: assignmentInstructions,
      ),
    );
  }
}

SeatDescriptionTrainingQuestion _questionFromApiJson(
  Map<String, dynamic> json, {
  required String publicId,
  required int index,
}) {
  final options = json['options'] is List
      ? (json['options'] as List)
            .whereType<Map>()
            .toList(growable: false)
            .asMap()
            .entries
            .map(
              (entry) => SeatDescriptionTrainingQuestionOption(
                uuid: '$publicId-question-$index-option-${entry.key}',
                text: _readString(entry.value['text']) ?? '',
              ),
            )
            .toList(growable: false)
      : const <SeatDescriptionTrainingQuestionOption>[];

  return SeatDescriptionTrainingQuestion(
    uuid: '$publicId-question-$index',
    question: _readString(json['question']) ?? '',
    options: options,
    selectedOptionUuid: null,
    imageUrl: _readString(json['image_url']),
  );
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}
