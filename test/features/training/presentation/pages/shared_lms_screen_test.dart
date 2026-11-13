import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/entities/shared_lms_content.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/shared_lms_repository.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lms_screen.dart';

void main() {
  testWidgets('shared LMS cards scroll without overflowing a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: SharedLmsScreen(
          publicId: 'shared-list',
          repository: _SharedLmsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sharedLmsSeatLabel), findsOneWidget);
    expect(find.text(AppStrings.sharedLmsCategoryLabel), findsOneWidget);
    expect(find.text(AppStrings.sharedLmsDescriptionLabel), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('Shared lesson'), findsOneWidget);
    expect(find.text('11:46 min'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('11:46 min')).dy,
      greaterThan(tester.getBottomLeft(find.text('Shared lesson')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

class _SharedLmsRepository extends Fake implements SharedLmsRepository {
  @override
  Future<SharedLmsContent> getSharedLms(String publicId) async {
    assert(publicId == 'shared-list');
    return const SharedLmsContent(
      title: 'Admin Controller for a Very Long Seat Profile Name',
      categoryTitle: 'Financial Management and Operations Category',
      description: 'Controls Financial Records and Reporting Processes',
      lessons: [
        SharedLmsLesson(
          publicId: 'lesson-public-id',
          title: 'Shared lesson',
          thumbnailUrl: null,
          duration: 706,
        ),
      ],
    );
  }
}
