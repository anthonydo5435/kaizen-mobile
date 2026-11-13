import '../../domain/entities/seat_description_training.dart';

class SeatDescriptionTrainingModuleModel extends SeatDescriptionTrainingModule {
  const SeatDescriptionTrainingModuleModel({
    required super.uuid,
    required super.actualId,
    required super.title,
    required super.thumbnailLink,
    required super.isPubliclyAvailable,
  });

  factory SeatDescriptionTrainingModuleModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return SeatDescriptionTrainingModuleModel(
      uuid: _readString(json['uuid']) ?? '',
      actualId: _readString(json['actual_id']) ?? '',
      title: _readString(json['title']) ?? '',
      thumbnailLink: _readString(json['thumbnail_link']),
      isPubliclyAvailable: _readBool(json['is_publicly_available']) ?? false,
    );
  }
}

class SeatDescriptionTrainingModuleDetailModel
    extends SeatDescriptionTrainingModuleDetail {
  const SeatDescriptionTrainingModuleDetailModel({
    required super.uuid,
    required super.actualId,
    required super.title,
    required super.thumbnails,
    required super.description,
    required super.assignmentTitle,
    required super.assignmentInstructions,
    required super.questions,
    required super.thumbnailLink,
    required super.trainingVideo,
    required super.isPubliclyAvailable,
    required super.learningTrackCount,
  });

  factory SeatDescriptionTrainingModuleDetailModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    final trainingVideo = _readMap(json['training_video']);
    final assignment = _readMap(json['assignment']);

    return SeatDescriptionTrainingModuleDetailModel(
      uuid: _readString(json['uuid']) ?? '',
      actualId: _readString(json['actual_id']) ?? '',
      title: _readString(json['title']) ?? '',
      thumbnails: _readStringList(json['thumbnails']),
      description: _readString(json['description']),
      assignmentTitle:
          _readFirstString(assignment, const ['title', 'name']) ??
          _readFirstString(json, const ['assignment_title', 'assignment_name']),
      assignmentInstructions:
          _readFirstString(assignment, const [
            'instructions',
            'description',
            'text',
          ]) ??
          _readFirstString(json, const [
            'assignment_instructions',
            'assignment_description',
            'instructions',
          ]),
      questions: _readQuestionList(json['questions']),
      thumbnailLink: _readString(json['thumbnail_link']),
      trainingVideo: trainingVideo == null
          ? null
          : SeatDescriptionTrainingVideoModel.fromApiJson(trainingVideo),
      isPubliclyAvailable: _readBool(json['is_publicly_available']) ?? false,
      learningTrackCount: _readInt(json['learning_track_count']) ?? 0,
    );
  }
}

class SeatDescriptionTrainingVideoModel extends SeatDescriptionTrainingVideo {
  const SeatDescriptionTrainingVideoModel({
    required super.uuid,
    required super.title,
    required super.url,
    required super.duration,
    required super.transcript,
  });

  factory SeatDescriptionTrainingVideoModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return SeatDescriptionTrainingVideoModel(
      uuid: _readString(json['uuid']) ?? '',
      title: _readString(json['title']) ?? '',
      url: _readString(json['url']),
      duration: _readInt(json['duration']) ?? 0,
      transcript: _readString(json['transcript']),
    );
  }
}

class SeatDescriptionTrainingDocumentModel
    extends SeatDescriptionTrainingDocument {
  const SeatDescriptionTrainingDocumentModel({
    required super.uuid,
    required super.text,
  });

  factory SeatDescriptionTrainingDocumentModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return SeatDescriptionTrainingDocumentModel(
      uuid: _readString(json['uuid']) ?? '',
      text: _readString(json['text']),
    );
  }
}

class SeatDescriptionTrainingAssignmentModel
    extends SeatDescriptionTrainingAssignment {
  const SeatDescriptionTrainingAssignmentModel({
    required super.uuid,
    required super.title,
    required super.instructions,
  });

  factory SeatDescriptionTrainingAssignmentModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return SeatDescriptionTrainingAssignmentModel(
      uuid: _readString(json['uuid']) ?? _readString(json['id']) ?? '',
      title: _readString(json['title']),
      instructions: _readString(json['instructions']),
    );
  }
}

class SeatDescriptionTrainingQuestionModel
    extends SeatDescriptionTrainingQuestion {
  const SeatDescriptionTrainingQuestionModel({
    required super.uuid,
    required super.question,
    required super.options,
    required super.selectedOptionUuid,
    required super.imageUrl,
  });

  factory SeatDescriptionTrainingQuestionModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    final options = _readQuestionOptions(json['options']);

    return SeatDescriptionTrainingQuestionModel(
      uuid: _readString(json['uuid']) ?? '',
      question: _readString(json['question']) ?? '',
      selectedOptionUuid: _readSelectedOptionUuid(json, options),
      imageUrl: _readString(json['image_url']) ?? _readString(json['image']),
      options: options,
    );
  }
}

class SeatDescriptionTrainingQuestionOptionModel
    extends SeatDescriptionTrainingQuestionOption {
  const SeatDescriptionTrainingQuestionOptionModel({
    required super.uuid,
    required super.text,
  });

  factory SeatDescriptionTrainingQuestionOptionModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return SeatDescriptionTrainingQuestionOptionModel(
      uuid: _readString(json['uuid']) ?? '',
      text: _readString(json['text']) ?? '',
    );
  }
}

Map<String, dynamic>? _readMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

String? _readString(dynamic value) {
  final resolved = value?.toString().trim();
  if (resolved == null || resolved.isEmpty) {
    return null;
  }
  return resolved;
}

String? _readFirstString(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) {
    return null;
  }

  for (final key in keys) {
    final value = _readString(json[key]);
    if (value != null) {
      return value;
    }
  }

  return null;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return null;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }

  return value.map(_readString).whereType<String>().toList(growable: false);
}

List<SeatDescriptionTrainingQuestion> _readQuestionList(dynamic value) {
  if (value is! List) {
    return const <SeatDescriptionTrainingQuestion>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => SeatDescriptionTrainingQuestionModel.fromApiJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList(growable: false);
}

List<SeatDescriptionTrainingQuestionOption> _readQuestionOptions(
  dynamic value,
) {
  if (value is! List) {
    return const <SeatDescriptionTrainingQuestionOption>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => SeatDescriptionTrainingQuestionOptionModel.fromApiJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList(growable: false);
}

String? _readSelectedOptionUuid(
  Map<String, dynamic> json,
  List<SeatDescriptionTrainingQuestionOption> options,
) {
  for (final key in const [
    'selected_option',
    'selected_option_uuid',
    'selected_answer',
    'selected_answer_uuid',
    'answer_uuid',
    'answer',
    'correct_option',
    'correct_option_uuid',
    'correct_answer',
    'correct_answer_uuid',
  ]) {
    final value = _readString(json[key]);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  final optionsJson = json['options'];
  if (optionsJson is! List) {
    return null;
  }

  for (var index = 0; index < optionsJson.length; index++) {
    final optionJson = optionsJson[index];
    if (optionJson is! Map) {
      continue;
    }

    final optionMap = Map<String, dynamic>.from(optionJson);
    final hasSelectedFlag =
        _readBool(optionMap['selected']) == true ||
        _readBool(optionMap['is_selected']) == true ||
        _readBool(optionMap['is_answer']) == true ||
        _readBool(optionMap['is_correct']) == true ||
        _readBool(optionMap['correct']) == true;
    if (!hasSelectedFlag) {
      continue;
    }

    final optionUuid = _readString(optionMap['uuid']);
    if (optionUuid != null && optionUuid.isNotEmpty) {
      return optionUuid;
    }

    if (index >= 0 && index < options.length) {
      final fallbackUuid = options[index].uuid.trim();
      if (fallbackUuid.isNotEmpty) {
        return fallbackUuid;
      }
    }
  }

  return null;
}
