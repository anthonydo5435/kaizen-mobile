import 'seat_description_training.dart';

class SharedLessonContent {
  const SharedLessonContent({
    required this.module,
    required this.document,
    required this.assignment,
  });

  final SeatDescriptionTrainingModuleDetail module;
  final SeatDescriptionTrainingDocument document;
  final SeatDescriptionTrainingAssignment assignment;
}
