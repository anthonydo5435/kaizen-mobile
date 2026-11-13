import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/navigation/app_menu_type.dart';
import 'package:sparrowkaizen/core/navigation/main_navigation_controller.dart';
import 'package:sparrowkaizen/core/widgets/app_bottom_nav_bar.dart';
import 'package:sparrowkaizen/core/widgets/drawer_main_screen.dart';
import 'package:sparrowkaizen/core/widgets/main_navigation_shell.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/repositories/seat_profile_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_content.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_search_bar.dart';

void main() {
  for (final inShell in [true, false]) {
    for (final mode in TrainingLibraryViewMode.values) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          '${mode.name} last card clears the home bar (shell: $inShell, text: $textScale)',
          (tester) async {
            final harness = _Harness();
            await harness.pump(
              tester,
              inShell: inShell,
              mode: mode,
              textScale: textScale,
            );
            final position = harness.library.scrollController.position;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();

            final lastCard = find.byType(TrainingLibraryModuleCard).last;
            final cardBounds = tester.getRect(lastCard);
            final barBounds = tester.getRect(find.byType(AppBottomNavBar));
            expect(cardBounds.bottom, lessThanOrEqualTo(barBounds.top - 12));
            expect(
              cardBounds.top,
              greaterThanOrEqualTo(tester.getRect(_listingScroll).top),
            );
            expect(_bottomTab.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await harness.dispose(tester);
          },
        );
      }

      testWidgets(
        '${mode.name} hides both bars down and restores them up (shell: $inShell)',
        (tester) async {
          final harness = _Harness();
          await harness.pump(tester, inShell: inShell, mode: mode);
          final listElement = tester.element(_listingScroll);
          final searchTop = tester
              .getTopLeft(find.byType(TrainingLibrarySearchBar))
              .dy;
          final initialViewport =
              harness.library.scrollController.position.viewportDimension;
          expect(_menuButton.hitTestable(), findsOneWidget);
          expect(_bottomTab.hitTestable(), findsOneWidget);

          await tester.drag(_listingScroll, const Offset(0, -320));
          await tester.pumpAndSettle();

          expect(harness.library.navigationBarsVisible, isFalse);
          expect(_menuButton.hitTestable(), findsNothing);
          expect(_bottomTab.hitTestable(), findsNothing);
          expect(tester.element(_listingScroll), same(listElement));
          expect(
            tester.getTopLeft(find.byType(TrainingLibrarySearchBar)).dy,
            closeTo(searchTop - kToolbarHeight, 0.1),
          );
          expect(
            harness.library.scrollController.position.viewportDimension,
            closeTo(initialViewport + kToolbarHeight, 0.1),
          );

          await tester.drag(_listingScroll, const Offset(0, 100));
          await tester.pumpAndSettle();

          expect(harness.library.scrollController.offset, greaterThan(0));
          expect(harness.library.navigationBarsVisible, isTrue);
          expect(_menuButton.hitTestable(), findsOneWidget);
          expect(_bottomTab.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await harness.dispose(tester);
        },
      );
    }
  }

  testWidgets(
    'small motion and top/bottom overscroll do not flicker the bars',
    (tester) async {
      final harness = _Harness();
      await harness.pump(tester);
      harness.library.scrollController.jumpTo(300);
      await tester.pumpAndSettle();
      expect(harness.library.navigationBarsVisible, isTrue);

      final gesture = await tester.startGesture(
        tester.getCenter(_listingScroll),
      );
      await gesture.moveBy(const Offset(0, -22));
      await tester.pump();
      expect(harness.library.navigationBarsVisible, isTrue);
      await gesture.moveBy(const Offset(0, -30));
      await tester.pumpAndSettle();
      expect(harness.library.navigationBarsVisible, isFalse);
      await gesture.moveBy(const Offset(0, 3));
      await tester.pump();
      expect(harness.library.navigationBarsVisible, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();

      final position = harness.library.scrollController.position;
      harness.library.scrollController.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.drag(_listingScroll, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(harness.library.navigationBarsVisible, isFalse);

      harness.library.scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_menuButton.hitTestable(), findsOneWidget);
      expect(_bottomTab.hitTestable(), findsOneWidget);
      await tester.drag(_listingScroll, const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(harness.library.navigationBarsVisible, isTrue);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'visibility stays scoped to LMS and refresh restores navigation',
    (tester) async {
      final harness = _Harness();
      await harness.pump(tester);
      await tester.drag(_listingScroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      final offset = harness.library.scrollController.offset;
      expect(_bottomTab.hitTestable(), findsNothing);

      harness.navigation.selectMenu(AppMenuType.audits);
      await tester.pumpAndSettle();
      expect(_menuButton.hitTestable(), findsOneWidget);
      expect(_bottomTab.hitTestable(), findsOneWidget);
      harness.navigation.selectMenu(AppMenuType.library);
      await tester.pumpAndSettle();
      expect(harness.library.scrollController.offset, offset);
      expect(_menuButton.hitTestable(), findsNothing);
      expect(_bottomTab.hitTestable(), findsNothing);

      harness.repository.itemCount = 0;
      await harness.library.refresh();
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.trainingLibraryNoModulesFound),
        findsOneWidget,
      );
      expect(_menuButton.hitTestable(), findsOneWidget);
      expect(_bottomTab.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );
}

final _listingScroll = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);
final _menuButton = find.byTooltip('Open navigation menu');
final _bottomTab = find.descendant(
  of: find.byType(AppBottomNavBar),
  matching: find.text(AppStrings.trainingLibraryTitle),
);

class _Harness {
  final repository = _LibraryRepository();
  late final library = TrainingLibraryController(
    GetTrainingLibraryModulesUseCase(repository),
    getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
    onNavigationBarsVisibilityChanged: (visible) =>
        navigation.setNavigationBarsVisible(AppMenuType.library, visible),
  );
  late final navigation = MainNavigationController(
    initialMenu: AppMenuType.library,
    destinations: [
      MainNavigationDestination(
        menu: AppMenuType.library,
        routeName: '/library',
        builder: (_) => _listing(),
      ),
      MainNavigationDestination(
        menu: AppMenuType.audits,
        routeName: '/audits',
        builder: (_) => const DrawerMainScreen(
          title: 'Check-in',
          selectedMenu: AppMenuType.audits,
          child: SizedBox.expand(),
        ),
      ),
    ],
  );

  Widget _listing() => ListenableBuilder(
    listenable: library,
    builder: (_, __) => TrainingLibraryContent(
      controller: library,
      onOpenLesson: (_) async {},
      onSelectSeat: () {},
      onCreate: () {},
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    bool inShell = true,
    TrainingLibraryViewMode mode = TrainingLibraryViewMode.list,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await library.initialize();
    await library.changeViewMode(mode);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppManager>.value(
        value: AppManager.instance,
        child: MaterialApp(
          // Exercise the iOS status bar inset and bouncing scroll physics.
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: inShell
              ? MainNavigationShell(controller: navigation)
              : _listing(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    library.dispose();
    navigation.dispose();
  }
}

class _SeatRepository extends Fake implements SeatProfileRepository {}

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  int itemCount = 30;

  @override
  Future<TrainingLibraryPage> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) async => TrainingLibraryPage(
    items: List.generate(
      itemCount,
      (index) => TrainingLibraryModule(
        id: 'lesson-$index',
        title: 'Lesson $index',
        description: '',
        department: const TrainingLibraryDepartment(
          id: 'department',
          name: 'Department',
        ),
        totalDuration: 60,
        seat: const TrainingLibrarySeat(id: 'seat', title: 'Seat'),
        lessons: const [],
        thumbnailLink: null,
        category: const TrainingLibraryCategory(
          id: 'category',
          title: 'Category',
        ),
      ),
    ),
    hasNextPage: false,
  );
}
