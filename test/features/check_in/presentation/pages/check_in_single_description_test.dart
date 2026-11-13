import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_single_description.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';

import '../../support/single_description_fixtures.dart';

void main() {
  late SingleDescriptionRepository repository;
  late CheckInController checkIn;

  setUp(() {
    repository = SingleDescriptionRepository();
    checkIn = singleDescriptionCheckInController(repository);
  });
  tearDown(() => checkIn.dispose());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final audit = singleDescriptionQuarterlyAudit();
    await tester.pumpWidget(
      ChangeNotifierProvider<CheckInController>.value(
        value: checkIn,
        child: MaterialApp(
          home: SingleDescriptionDetails(
            audit: audit,
            descriptions: audit.descriptions,
            initialDescriptionIndex: 0,
            initialRatingCounts: const {'great': 7},
            date: singleDescriptionDate(),
            isOwner: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'paging preserves each description draft, scroll and arrow boundaries',
    (tester) async {
      await mount(tester);
      final previous = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_rounded,
      );
      final next = find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(1, 2)),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('7'));
      await tester.tap(find.text('7'));
      await tester.pump();
      expect(find.text('8'), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(2, 2)),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      expect(checkIn.state.selectedQuarterlyAuditDescriptionUuid, 'second');
      expect(repository.saves.single.counts['great'], 8);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('8').hitTestable(), findsOneWidget);
      expect(repository.loads.where((id) => id == 'first'), hasLength(1));
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(2, 2)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing the actual detail page saves a tap still inside its debounce',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('7'));
      await tester.tap(find.text('7'));
      expect(repository.saves, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.id, 'resolved-audit');
      expect(repository.saves.single.counts['great'], 8);
      expect(tester.takeException(), isNull);
    },
  );
}
