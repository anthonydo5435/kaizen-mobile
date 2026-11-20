class TrainingLibraryDepartment {
  const TrainingLibraryDepartment({
    required this.id,
    required this.name,
    this.colorHex,
  });

  final String id;
  final String name;
  final String? colorHex;
}

class TrainingLibraryCategory {
  const TrainingLibraryCategory({required this.id, required this.title});

  final String id;
  final String title;
}

class TrainingLibrarySeat {
  const TrainingLibrarySeat({
    required this.id,
    required this.title,
    this.actualId,
  });

  final String id;
  final String title;
  final String? actualId;

  Iterable<String> get profileIds sync* {
    yield id;
    if (actualId case final id? when id.isNotEmpty) yield id;
  }
}

class TrainingLibraryLesson {
  const TrainingLibraryLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailLink,
    required this.isPubliclyAvailable,
    this.duration = 0,
    this.fromSandbox = false,
    this.sopExists = false,
    this.quizExists = false,
  });

  final String id;
  final String title;
  final String description;
  final String? thumbnailLink;
  final bool isPubliclyAvailable;
  final int duration;
  final bool fromSandbox;
  final bool sopExists;
  final bool quizExists;

  bool get hasDescription => description.trim().isNotEmpty;
}

class TrainingLibraryModule {
  const TrainingLibraryModule({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.totalDuration,
    required this.seat,
    required this.lessons,
    required this.thumbnailLink,
    required this.category,
    this.descriptionId,
  });

  final String id;
  final String title;
  final String description;
  final TrainingLibraryDepartment department;
  final int totalDuration;
  final TrainingLibrarySeat seat;
  final List<TrainingLibraryLesson> lessons;
  final String? thumbnailLink;
  final TrainingLibraryCategory category;

  /// Separate from the lesson UUID in the flat listing response. Legacy grouped
  /// responses use [id] as their description UUID.
  final String? descriptionId;

  int get lessonsCount => lessons.length;
  bool get isLessonListing => descriptionId != null;
  String get trainingDescriptionId => descriptionId ?? id;
}
