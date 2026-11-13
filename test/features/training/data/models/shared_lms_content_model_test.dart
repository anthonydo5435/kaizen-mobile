import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/training/data/models/shared_lms_content_model.dart';

void main() {
  test(
    'shared LMS response retains the list metadata and public lesson IDs',
    () {
      final model = SharedLmsContentModel.fromApiJson({
        'view_type': 'lms',
        'content': {
          'title': 'YRL 3',
          'category_title': 'Iris Jacobson',
          'description': 'Dicta fugiat distinc',
          'modules': [
            {
              'public_id': 'b9a12982d92b57fe7c7d04d8584a445bae214055',
              'title': 'sdfs',
              'duration': 706,
              'thumbnail_url':
                  'https://media-dev.kaizenteams.ai/media/images/first.jpg',
            },
            {
              'public_id': '2ea6df45ebb85d7e0ba7ab28b895868d222cdbb2',
              'title': 'MKAAL',
              'duration': '3661',
              'thumbnail_url': null,
            },
          ],
        },
      });

      expect(model.title, 'YRL 3');
      expect(model.categoryTitle, 'Iris Jacobson');
      expect(model.description, 'Dicta fugiat distinc');
      expect(model.lessons.map((lesson) => lesson.publicId), [
        'b9a12982d92b57fe7c7d04d8584a445bae214055',
        '2ea6df45ebb85d7e0ba7ab28b895868d222cdbb2',
      ]);
      expect(model.lessons.first.thumbnailUrl, endsWith('/first.jpg'));
      expect(model.lessons.map((lesson) => lesson.duration), [706, 3661]);
    },
  );

  test('missing or invalid durations fall back to zero', () {
    final durations = [null, '', 'invalid', -1, 'NaN', 'Infinity'];
    for (final duration in durations) {
      final lesson = SharedLmsLessonModel.fromApiJson({
        'public_id': 'lesson-id',
        'title': 'Lesson',
        if (duration != null) 'duration': duration,
      });
      expect(lesson.duration, 0);
    }
  });

  test('fractional durations round to whole seconds', () {
    for (final duration in [65.7, '65.7']) {
      final lesson = SharedLmsLessonModel.fromApiJson({
        'public_id': 'lesson-id',
        'duration': duration,
      });
      expect(lesson.duration, 66);
    }
  });
}
