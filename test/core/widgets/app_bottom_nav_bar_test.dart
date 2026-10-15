import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/navigation/app_menu_type.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/core/widgets/app_bottom_nav_bar.dart';
import 'package:sparrowkaizen/core/widgets/app_drawer.dart';
import 'package:sparrowkaizen/core/widgets/drawer_main_screen.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  test('LMS is the authenticated landing page in both API modes', () async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setUseParentApiEndpoints(false);
    expect(AppRouter.defaultAuthenticatedRouteName, AppRouter.trainingLibrary);
    await AppPreference.setUseParentApiEndpoints(true);
    expect(AppRouter.defaultAuthenticatedRouteName, AppRouter.trainingLibrary);
    await AppPreference.setUseParentApiEndpoints(false);
  });

  testWidgets(
    'standalone main tabs replace routes while drawer pages push with Back',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visitedRoutes = <String?>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: _screen(AppMenuType.library),
            onGenerateRoute: (settings) {
              visitedRoutes.add(settings.name);
              final menu = switch (settings.name) {
                AppRouter.trainingLibrary => AppMenuType.library,
                AppRouter.checkIn => AppMenuType.audits,
                AppRouter.performanceSnapshot =>
                  AppMenuType.performanceSnapshot,
                AppRouter.learningTracks => AppMenuType.learningTracks,
                AppRouter.compliance => AppMenuType.compliance,
                AppRouter.seatProfiles => AppMenuType.seatProfiles,
                _ => throw StateError('Unexpected route: ${settings.name}'),
              };
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => _screen(menu),
              );
            },
          ),
        ),
      );

      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(AppBottomNavBar),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data),
        [
          AppStrings.trainingLibraryTitle,
          AppStrings.checkInTitle,
          AppStrings.bottomNavPerformance,
          AppStrings.bottomNavLtc,
        ],
      );
      await tester.tap(_tab(AppStrings.trainingLibraryTitle));
      await tester.pumpAndSettle();
      expect(visitedRoutes, isEmpty);

      for (final destination in [
        (AppStrings.checkInTitle, AppRouter.checkIn),
        (AppStrings.bottomNavPerformance, AppRouter.performanceSnapshot),
        (AppStrings.bottomNavLtc, AppRouter.learningTracks),
        (AppStrings.trainingLibraryTitle, AppRouter.trainingLibrary),
      ]) {
        await tester.tap(_tab(destination.$1));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, destination.$2);
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(destination.$1))
              .flagsCollection
              .isSelected,
          isTrue,
        );
      }

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final drawer = find.byType(AppDrawer);
      for (final label in [
        AppStrings.homeLibrary,
        AppStrings.trainingLibraryTitle,
        AppStrings.weeklyCheckIns,
        AppStrings.checkInTitle,
        AppStrings.bottomNavPerformance,
        AppStrings.performanceSnapshot,
        AppStrings.homeLearningTracks,
        AppStrings.bottomNavLtc,
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(label)),
          findsNothing,
        );
      }
      await tester.tap(
        find.descendant(
          of: drawer,
          matching: find.text(AppStrings.homeCompliance),
        ),
      );
      await tester.pumpAndSettle();
      expect(visitedRoutes.last, AppRouter.compliance);
      expect(navigatorKey.currentState!.canPop(), isTrue);
      expect(_tab(AppStrings.homeCompliance), findsNothing);
      expect(find.byType(AppBottomNavBar), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavBar), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.homeSeatProfiles));
      await tester.pumpAndSettle();
      expect(visitedRoutes.last, AppRouter.seatProfiles);
      expect(find.byType(AppBottomNavBar), findsNothing);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavBar), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('a drawer page opened as the root returns to LMS with Back', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppManager>.value(
        value: AppManager.instance,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: _screen(AppMenuType.seatProfiles),
          onGenerateRoute: (settings) {
            expect(settings.name, AppRouter.trainingLibrary);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => _screen(AppMenuType.library),
            );
          },
        ),
      ),
    );
    expect(find.byType(AppBottomNavBar), findsNothing);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNavBar), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four destinations are enabled and forward taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final selections = <AppMenuType>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavBar(
            selectedMenu: AppMenuType.library,
            onSelected: selections.add,
          ),
        ),
      ),
    );
    for (final destination in [
      (AppStrings.trainingLibraryTitle, AppMenuType.library),
      (AppStrings.checkInTitle, AppMenuType.audits),
      (AppStrings.bottomNavPerformance, AppMenuType.performanceSnapshot),
      (AppStrings.bottomNavLtc, AppMenuType.learningTracks),
    ]) {
      expect(_tab(destination.$1), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(destination.$1))
            .flagsCollection
            .isEnabled,
        isTrue,
      );
      await tester.tap(_tab(destination.$1));
      expect(selections.last, destination.$2);
    }
    expect(selections, hasLength(4));
    semantics.dispose();
  });

  testWidgets(
    'narrow screens keep training margins with large text and system insets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppMenuType? selected;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              padding: const EdgeInsets.only(bottom: 34),
              viewPadding: const EdgeInsets.only(bottom: 34),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: const SizedBox.expand(key: ValueKey('content')),
            bottomNavigationBar: AppBottomNavBar(
              selectedMenu: AppMenuType.performanceSnapshot,
              onSelected: (menu) => selected = menu,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = find.byType(AppBottomNavBar);
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('content'))).dy,
        lessThanOrEqualTo(tester.getTopLeft(bar).dy),
      );
      final surfaceBounds = tester.getRect(
        find.descendant(of: bar, matching: find.byType(ClipRRect)),
      );
      expect(surfaceBounds.left, 12);
      expect(surfaceBounds.right, 320 - 12);
      expect(surfaceBounds.bottom, 740 - 14);
      expect(
        tester.getBottomLeft(_tab(AppStrings.bottomNavPerformance)).dy,
        lessThan(surfaceBounds.bottom),
      );
      await tester.tap(_tab(AppStrings.bottomNavPerformance));
      expect(selected, AppMenuType.performanceSnapshot);
    },
  );
}

Widget _screen(AppMenuType menu) => DrawerMainScreen(
  title: 'Navigation test',
  selectedMenu: menu,
  child: const SizedBox.expand(),
);

Finder _tab(String label) => find.descendant(
  of: find.byType(AppBottomNavBar),
  matching: find.text(label),
);
