import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/training/data/models/seat_description_training_model.dart';

void main() {
  test('assignment model reads the API id for PATCH requests', () {
    final assignment = SeatDescriptionTrainingAssignmentModel.fromApiJson({
      'id': 42,
      'title': 'Assignment',
      'instructions': '<p>Complete the task</p>',
    });

    expect(assignment.uuid, '42');
    expect(assignment.title, 'Assignment');
    expect(assignment.instructions, '<p>Complete the task</p>');
  });

  test(
    'assignment uuid takes precedence when both identifiers are present',
    () {
      final assignment = SeatDescriptionTrainingAssignmentModel.fromApiJson({
        'uuid': 'assignment-uuid',
        'id': 42,
        'title': 'Assignment',
        'instructions': '',
      });

      expect(assignment.uuid, 'assignment-uuid');
    },
  );
}
