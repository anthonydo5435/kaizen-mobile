import '../../domain/entities/training_library_module.dart';

class TrainingLibraryDepartmentModel extends TrainingLibraryDepartment {
  const TrainingLibraryDepartmentModel({
    required super.id,
    required super.name,
    super.colorHex,
  });

  factory TrainingLibraryDepartmentModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    return TrainingLibraryDepartmentModel(
      id: _readString(json['uuid']),
      name: _readString(json['name']),
      colorHex: _readNullableString(json['color_hex']),
    );
  }
}

class TrainingLibraryCategoryModel extends TrainingLibraryCategory {
  const TrainingLibraryCategoryModel({required super.id, required super.title});

  factory TrainingLibraryCategoryModel.fromApiJson(Map<String, dynamic> json) {
    return TrainingLibraryCategoryModel(
      id: _readString(json['uuid']),
      title: _readString(json['title']),
    );
  }
}

class TrainingLibrarySeatModel extends TrainingLibrarySeat {
  const TrainingLibrarySeatModel({
    required super.id,
    required super.title,
    super.actualId,
  });

  factory TrainingLibrarySeatModel.fromApiJson(Map<String, dynamic> json) {
    return TrainingLibrarySeatModel(
      id: _readString(json['uuid']),
      title: _readString(json['title']),
      actualId: _readNullableString(json['actual_id']),
    );
  }
}

class TrainingLibraryLessonModel extends TrainingLibraryLesson {
  const TrainingLibraryLessonModel({
    required super.id,
    required super.title,
    required super.description,
    required super.thumbnailLink,
    required super.isPubliclyAvailable,
    super.duration,
    super.fromSandbox,
    super.sopExists,
    super.quizExists,
  });

  factory TrainingLibraryLessonModel.fromApiJson(Map<String, dynamic> json) {
    final title = _readNullableString(json['title']);
    final description = _readDescription(json['description']);

    return TrainingLibraryLessonModel(
      id: _readString(json['uuid']),
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : (description?.trim() ?? ''),
      description: description?.trim() ?? '',
      thumbnailLink: _readNullableString(json['thumbnail_link']),
      isPubliclyAvailable: _readBool(json['is_publicly_available']),
      duration: _readInt(json['duration']),
      fromSandbox: _readBool(json['from_sandbox']),
      sopExists: _readBool(json['sop_exists']),
      quizExists: _readBool(json['quiz_exists']),
    );
  }
}

class TrainingLibraryModuleModel extends TrainingLibraryModule {
  const TrainingLibraryModuleModel({
    required super.id,
    required super.title,
    required super.description,
    required super.department,
    required super.totalDuration,
    required super.seat,
    required super.lessons,
    required super.thumbnailLink,
    required super.category,
    super.descriptionId,
    super.moduleType,
  });

  factory TrainingLibraryModuleModel.fromApiJson(Map<String, dynamic> json) {
    final descriptionJson = json['description'];
    final description = _readDescription(descriptionJson);
    final isGeneral =
        json['module_type'] == TrainingModuleType.general.apiValue;
    final isLessonListing =
        descriptionJson is Map<String, dynamic> ||
        (json['training_modules'] is! List && json.containsKey('duration'));
    final title = _readNullableString(json['title']);
    final department = json['department'] is Map<String, dynamic>
        ? TrainingLibraryDepartmentModel.fromApiJson(
            json['department'] as Map<String, dynamic>,
          )
        : const TrainingLibraryDepartmentModel(id: '', name: '');
    final seat = json['job'] is Map<String, dynamic>
        ? TrainingLibrarySeatModel.fromApiJson(
            json['job'] as Map<String, dynamic>,
          )
        : TrainingLibrarySeatModel(
            id: json['job'] is String ? _readString(json['job']) : '',
            title: '',
          );
    final category = json['category'] is Map<String, dynamic>
        ? TrainingLibraryCategoryModel.fromApiJson(
            json['category'] as Map<String, dynamic>,
          )
        : const TrainingLibraryCategoryModel(id: '', title: '');

    return TrainingLibraryModuleModel(
      id: _readString(json['uuid']),
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : (description?.trim() ?? ''),
      description: description?.trim() ?? '',
      department: department,
      totalDuration: _readInt(json['duration'] ?? json['total_duration']),
      seat: seat,
      lessons: isGeneral || isLessonListing
          ? [TrainingLibraryLessonModel.fromApiJson(json)]
          : _readLessons(json['training_modules']),
      thumbnailLink: _readNullableString(json['thumbnail_link']),
      category: category,
      moduleType: isGeneral
          ? TrainingModuleType.general
          : TrainingModuleType.jobBased,
      descriptionId: !isGeneral && isLessonListing
          ? (descriptionJson is Map<String, dynamic>
                ? _readString(descriptionJson['uuid'])
                : '')
          : null,
    );
  }

  static List<TrainingLibraryLessonModel> _readLessons(dynamic value) {
    if (value is! List) {
      return const <TrainingLibraryLessonModel>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(TrainingLibraryLessonModel.fromApiJson)
        .toList(growable: false);
  }
}

String? _readDescription(dynamic value) {
  if (value is Map<String, dynamic>) {
    return _readNullableString(value['description']);
  }
  return value is String ? _readNullableString(value) : null;
}

String _readString(dynamic value) {
  return value?.toString().trim() ?? '';
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}
