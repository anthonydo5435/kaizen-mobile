import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_page.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_screen.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
  });
  tearDown(AppManager.instance.resetSessionState);

  testWidgets(
    'expansion keeps the title fixed and moves the next card smoothly',
    (tester) async {
      await _openScreen(tester);
      final card = find.byKey(const ValueKey('first-seat'));
      final title = find.text('Operations Lead');
      final nextTitle = find.text('Designer');
      final details = _firstDetails();
      final collapsedHeight = tester.getSize(card).height;
      final titleTop = tester.getTopLeft(title).dy;
      final nextTitleTop = tester.getTopLeft(nextTitle).dy;
      expect(details.hitTestable(), findsNothing);

      await tester.tap(title);
      await tester.pump();
      var previousHeight = collapsedHeight;
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        final height = tester.getSize(card).height;
        expect(height, greaterThan(previousHeight));
        expect(tester.getTopLeft(title).dy, closeTo(titleTop, 0.01));
        expect(
          tester.getTopLeft(nextTitle).dy,
          closeTo(nextTitleTop + height - collapsedHeight, 0.01),
        );
        if (frame < 7) {
          expect(details.hitTestable(), findsNothing);
        }
        previousHeight = height;
      }
      final expandedHeight = previousHeight;
      await tester.pumpAndSettle();
      expect(details.hitTestable(), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('second-seat'))).height,
        collapsedHeight - 16,
      );

      await tester.tap(title);
      await tester.pump();
      expect(details.hitTestable(), findsNothing);
      previousHeight = expandedHeight;
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        final height = tester.getSize(card).height;
        expect(height, lessThan(previousHeight));
        expect(tester.getTopLeft(title).dy, closeTo(titleTop, 0.01));
        previousHeight = height;
      }
      expect(previousHeight, closeTo(collapsedHeight, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick repeated taps reverse without jumping and retain details navigation',
    (tester) async {
      RouteSettings? openedRoute;
      await _openScreen(tester, onRoute: (settings) => openedRoute = settings);
      final card = find.byKey(const ValueKey('first-seat'));
      final title = find.text('Operations Lead');
      final collapsedHeight = tester.getSize(card).height;

      await tester.tap(title);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final openingHeight = tester.getSize(card).height;
      expect(openingHeight, greaterThan(collapsedHeight));
      await tester.tap(title);
      await tester.pump();
      expect(tester.getSize(card).height, closeTo(openingHeight, 0.01));
      await tester.pump(const Duration(milliseconds: 60));
      final closingHeight = tester.getSize(card).height;
      expect(closingHeight, lessThan(openingHeight));
      expect(_firstDetails().hitTestable(), findsNothing);

      await tester.tap(title);
      await tester.pump();
      expect(tester.getSize(card).height, closeTo(closingHeight, 0.01));
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, greaterThan(openingHeight));
      expect(_firstDetails().hitTestable(), findsOneWidget);
      await tester.tap(_firstDetails());
      await tester.pumpAndSettle();
      expect(openedRoute?.name, AppRouter.seatProfileDetail);
      expect(
        (openedRoute!.arguments as SeatProfileDetailRouteArgs).seatId,
        'first-detail',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long titles and large text expand on narrow screens without overflow',
    (tester) async {
      const longTitle = 'Operations and Customer Experience Department Lead';
      await _openScreen(
        tester,
        firstTitle: longTitle,
        width: 320,
        textScale: 2,
      );
      final title = find.text(longTitle);
      final titleTop = tester.getTopLeft(title).dy;
      await tester.tap(title);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.getTopLeft(title).dy, closeTo(titleTop, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_firstDetails());
      await tester.pumpAndSettle();
      expect(_firstDetails().hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion expands and collapses immediately', (
    tester,
  ) async {
    await _openScreen(tester, disableAnimations: true);
    final card = find.byKey(const ValueKey('first-seat'));
    final title = find.text('Operations Lead');
    final collapsedHeight = tester.getSize(card).height;
    final titleTop = tester.getTopLeft(title).dy;

    await tester.tap(title);
    await tester.pump();
    final expandedHeight = tester.getSize(card).height;
    expect(expandedHeight, greaterThan(collapsedHeight));
    expect(_firstDetails().hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(title).dy, titleTop);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(card).height, expandedHeight);

    await tester.tap(title);
    await tester.pump();
    expect(tester.getSize(card).height, collapsedHeight);
    expect(_firstDetails().hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Finder _firstDetails() => find.descendant(
  of: find.byKey(const ValueKey('first-seat')),
  matching: find.text(AppStrings.seatProfileDetailsTitle),
);

Future<void> _openScreen(
  WidgetTester tester, {
  String firstTitle = 'Operations Lead',
  double width = 390,
  double textScale = 1,
  bool disableAnimations = false,
  ValueChanged<RouteSettings>? onRoute,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      onGenerateRoute: (settings) {
        onRoute?.call(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: SizedBox()),
        );
      },
      home: SeatProfileScreen(
        getSeatProfilesUseCase: _SeatProfilesUseCase(firstTitle),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SeatProfilesUseCase extends Fake implements GetSeatProfilesUseCase {
  _SeatProfilesUseCase(this.firstTitle);

  final String firstTitle;

  @override
  Future<List<Department>> getDepartments() async => const [];

  @override
  Future<SeatProfilePage> call({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String title = '',
    bool forceRefresh = false,
  }) async => SeatProfilePage(
    items: [
      SeatProfile(
        id: 'first-seat',
        actualId: 'first-detail',
        name: firstTitle,
        categoriesCount: 7,
        descriptionsCount: 18,
        hasPrimaryPaygrade: true,
        hasAncillaryPaygrade: false,
      ),
      const SeatProfile(
        id: 'second-seat',
        actualId: 'second-detail',
        name: 'Designer',
        categoriesCount: 3,
        descriptionsCount: 8,
        hasPrimaryPaygrade: false,
        hasAncillaryPaygrade: true,
      ),
    ],
    hasNextPage: false,
  );
}
