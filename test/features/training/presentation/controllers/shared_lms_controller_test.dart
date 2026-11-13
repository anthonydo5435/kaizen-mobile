import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/entities/shared_lms_content.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/shared_lms_repository.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/shared_lms_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the deep-link ID and filters its lessons by title', () async {
    final repository = _SharedLmsRepository();
    final controller = SharedLmsController(repository);
    addTearDown(controller.dispose);

    await controller.load(' shared-id ');
    expect(repository.requestedId, 'shared-id');
    expect(controller.visibleLessons, hasLength(2));

    controller.searchController.text = 'second';
    controller.updateSearchQuery(controller.searchController.text);
    expect(controller.visibleLessons.single.publicId, 'lesson-2');
    controller.clearSearch();
    expect(controller.visibleLessons, hasLength(2));
  });

  test('shows a useful error when the shared content cannot load', () async {
    final controller = SharedLmsController(
      _SharedLmsRepository(shouldFail: true),
    );
    addTearDown(controller.dispose);

    await controller.load('missing');
    expect(controller.content, isNull);
    expect(controller.errorMessage, AppStrings.sharedLmsUnableToLoad);
    expect(controller.isLoading, isFalse);
  });
}

class _SharedLmsRepository extends Fake implements SharedLmsRepository {
  _SharedLmsRepository({this.shouldFail = false});

  final bool shouldFail;
  String? requestedId;

  @override
  Future<SharedLmsContent> getSharedLms(String publicId) async {
    requestedId = publicId;
    if (shouldFail) {
      throw StateError('Shared content unavailable');
    }
    return const SharedLmsContent(
      title: 'Shared LMS',
      categoryTitle: 'Category',
      description: 'Description',
      lessons: [
        SharedLmsLesson(
          publicId: 'lesson-1',
          title: 'First lesson',
          thumbnailUrl: null,
        ),
        SharedLmsLesson(
          publicId: 'lesson-2',
          title: 'Second lesson',
          thumbnailUrl: null,
        ),
      ],
    );
  }
}
