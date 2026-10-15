import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/navigation/app_menu_type.dart';
import 'package:sparrowkaizen/core/navigation/main_navigation_controller.dart';
import 'package:sparrowkaizen/core/navigation/main_navigation_route.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/core/widgets/app_bottom_nav_bar.dart';
import 'package:sparrowkaizen/core/widgets/drawer_main_screen.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

const _menus = {
  AppMenuType.library: AppRouter.trainingLibrary,
  AppMenuType.audits: AppRouter.checkIn,
  AppMenuType.performanceSnapshot: AppRouter.performanceSnapshot,
  AppMenuType.learningTracks: AppRouter.learningTracks,
  AppMenuType.compliance: AppRouter.compliance,
  AppMenuType.seatProfiles: AppRouter.seatProfiles,
  AppMenuType.paygrades: AppRouter.paygrades,
  AppMenuType.departments: AppRouter.departments,
  AppMenuType.kaizenGpt: AppRouter.kaizenGpt,
  AppMenuType.home: AppRouter.kaizengram,
};
const _detailsRoute = '/test/details';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'account', organizationUuid: 'org-one'),
    );
  });

  testWidgets(
    'tabs load lazily and keep the bar, search, and scroll state mounted',
    (tester) async {
      final harness = _NavigationHarness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final bar = tester.element(find.byType(AppBottomNavBar));
      final barRect = tester.getRect(find.byType(AppBottomNavBar));
      final library = tester.state<_ProbePageState>(find.byType(_ProbePage));
      expect(harness.loads, {AppMenuType.library: 1});

      await tester.enterText(find.byType(TextField), 'remember this search');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      final scrollOffset = library.scrollController.offset;
      expect(scrollOffset, greaterThan(0));

      harness.loading.value = true;
      await tester.tap(_tab(AppStrings.checkInTitle));
      await tester.pump();
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(tester.element(find.byType(AppBottomNavBar)), same(bar));
      expect(tester.getRect(find.byType(AppBottomNavBar)), barRect);
      expect(harness.loads, {AppMenuType.library: 1, AppMenuType.audits: 1});
      expect(harness.observer.pushes, 1);
      expect(harness.observer.replacements, 0);
      expect(harness.routes.single.settings.name, AppRouter.checkIn);
      expect(AppManager.instance.currentRouteName, AppRouter.checkIn);

      harness.loading.value = false;
      await tester.pumpAndSettle();
      for (final label in [
        AppStrings.bottomNavPerformance,
        AppStrings.bottomNavLtc,
        AppStrings.trainingLibraryTitle,
      ]) {
        await tester.tap(_tab(label));
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(AppBottomNavBar)), same(bar));
      }
      expect(
        tester.state<_ProbePageState>(find.byType(_ProbePage)),
        same(library),
      );
      expect(library.searchController.text, 'remember this search');
      expect(library.scrollController.offset, scrollOffset);
      expect(harness.loads.values, everyElement(1));
      expect(harness.loads.length, 4);
      expect(harness.disposals, isEmpty);
      expect(harness.navigatorKey.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'drawer pages hide the bottom bar and Back preserves the previous tab',
    (tester) async {
      final harness = _NavigationHarness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final bar = tester.element(find.byType(AppBottomNavBar));
      await tester.tap(_tab(AppStrings.checkInTitle));
      await tester.pumpAndSettle();
      final checkIn = tester.state<_ProbePageState>(find.byType(_ProbePage));
      await tester.enterText(find.byType(TextField), 'saved search');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrollOffset = checkIn.scrollController.offset;

      for (final destination in [
        (AppStrings.homeCompliance, AppRouter.compliance),
        (AppStrings.homeSeatProfiles, AppRouter.seatProfiles),
        (AppStrings.homePaygrades, AppRouter.paygrades),
        (AppStrings.homeDepartments, AppRouter.departments),
      ]) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(destination.$1));
        await tester.pumpAndSettle();
        expect(AppManager.instance.currentRouteName, destination.$2);
        expect(harness.routes.single.settings.name, AppRouter.checkIn);
        expect(find.byType(AppBottomNavBar), findsNothing);
        expect(find.byType(AppBackButton), findsOneWidget);
        expect(find.byTooltip('Open navigation menu'), findsNothing);
        expect(harness.navigatorKey.currentState!.canPop(), isTrue);

        final drawerPage = tester.state<_ProbePageState>(
          find.byType(_ProbePage),
        );
        await tester.tap(find.text('Open details'));
        await tester.pumpAndSettle();
        expect(find.text('Details'), findsOneWidget);
        expect(find.byType(AppBottomNavBar), findsNothing);
        expect(AppManager.instance.currentRouteName, _detailsRoute);
        await harness.navigatorKey.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(
          tester.state<_ProbePageState>(find.byType(_ProbePage)),
          same(drawerPage),
        );
        expect(AppManager.instance.currentRouteName, destination.$2);
        expect(find.byType(AppBottomNavBar), findsNothing);

        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(AppBottomNavBar)), same(bar));
        expect(
          tester.state<_ProbePageState>(find.byType(_ProbePage)),
          same(checkIn),
        );
        expect(checkIn.searchController.text, 'saved search');
        expect(checkIn.scrollController.offset, scrollOffset);
        expect(AppManager.instance.currentRouteName, AppRouter.checkIn);
        expect(harness.navigatorKey.currentState!.canPop(), isFalse);
      }
      expect(harness.loads[AppMenuType.audits], 1);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'sandbox drawer pages support system Back without changing tabs',
    (tester) async {
      AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
      final harness = _NavigationHarness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      for (final label in [
        AppStrings.homeSeatProfiles,
        AppStrings.homePaygrades,
        AppStrings.homeDepartments,
      ]) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.homeCompliance), findsNothing);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomNavBar), findsNothing);
        expect(find.byType(AppBackButton), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomNavBar), findsOneWidget);
        expect(AppManager.instance.currentRouteName, AppRouter.trainingLibrary);
        expect(harness.navigatorKey.currentState!.canPop(), isFalse);
      }
      expect(harness.loads[AppMenuType.library], 1);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets('organization changes discard cached pages and return to LMS', (
    tester,
  ) async {
    final harness = _NavigationHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final bar = tester.element(find.byType(AppBottomNavBar));
    await tester.tap(_tab(AppStrings.checkInTitle));
    await tester.pumpAndSettle();

    AppManager.instance.updateCurrentUser(
      User(uuid: 'account', organizationUuid: 'org-one', firstName: 'Updated'),
    );
    await tester.pumpAndSettle();
    expect(harness.loads, {AppMenuType.library: 1, AppMenuType.audits: 1});
    expect(harness.disposals, isEmpty);

    AppManager.instance.updateCurrentUser(
      User(uuid: 'account', organizationUuid: 'org-two'),
    );
    await tester.pumpAndSettle();
    expect(harness.routes.single.settings.name, AppRouter.trainingLibrary);
    expect(harness.loads, {AppMenuType.library: 2, AppMenuType.audits: 1});
    expect(harness.disposals, {AppMenuType.library: 1, AppMenuType.audits: 1});
    expect(tester.element(find.byType(AppBottomNavBar)), same(bar));

    await tester.tap(_tab(AppStrings.checkInTitle));
    await tester.pumpAndSettle();
    expect(harness.loads[AppMenuType.audits], 2);
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets(
    'drawer covers the bottom bar and scrim taps do not switch tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _NavigationHarness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final bar = tester.element(find.byType(AppBottomNavBar));
      final lastTabCenter = tester.getCenter(_tab(AppStrings.bottomNavLtc));
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_tab(AppStrings.bottomNavLtc).hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(harness.navigatorKey.currentState!.canPop(), isTrue);
      expect(_tab(AppStrings.trainingLibraryTitle).hitTestable(), findsNothing);
      expect(tester.getBottomRight(find.byType(Drawer)).dy, 844);
      expect(
        tester.getTopRight(find.byType(Drawer)).dx,
        lessThan(lastTabCenter.dx),
      );
      expect(tester.element(find.byType(AppBottomNavBar)), same(bar));

      await tester.tapAt(lastTabCenter);
      await tester.pumpAndSettle();
      expect(harness.routes.single.settings.name, AppRouter.trainingLibrary);
      expect(harness.navigatorKey.currentState!.canPop(), isFalse);
      expect(_tab(AppStrings.bottomNavLtc).hitTestable(), findsOneWidget);

      await tester.tap(_tab(AppStrings.bottomNavLtc));
      await tester.pumpAndSettle();
      expect(harness.routes.single.settings.name, AppRouter.learningTracks);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await harness.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(harness.routes.single.settings.name, AppRouter.learningTracks);
      expect(tester.element(find.byType(AppBottomNavBar)), same(bar));
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets('resetting the root route releases all retained pages', (
    tester,
  ) async {
    final harness = _NavigationHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final bar = tester.element(find.byType(AppBottomNavBar));
    await tester.tap(_tab(AppStrings.bottomNavPerformance));
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.pushNamedAndRemoveUntil(
      AppRouter.trainingLibrary,
      (_) => false,
    );
    await tester.pumpAndSettle();
    expect(harness.loads[AppMenuType.library], 2);
    expect(harness.disposals, {
      AppMenuType.library: 1,
      AppMenuType.performanceSnapshot: 1,
    });
    expect(tester.element(find.byType(AppBottomNavBar)), isNot(same(bar)));
    expect(harness.navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  test('main named routes enter the shell at their requested destination', () {
    for (final entry in _menus.entries.where(
      (entry) => entry.key.isBottomNavigationTab,
    )) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: entry.value));
      expect(route, isA<MainNavigationRoute>());
      final navigation = (route as MainNavigationRoute).navigationController;
      expect(navigation.selectedMenu, entry.key);
      expect(route.settings.name, entry.value);
      expect(navigation.destinations.length, 4);
      expect(
        navigation.destinations
            .where((item) => navigation.hasVisited(item.menu))
            .length,
        1,
      );
      route.dispose();
    }
  });

  test('drawer named routes open standalone pages outside the main shell', () {
    for (final entry in _menus.entries.where(
      (entry) => !entry.key.isBottomNavigationTab,
    )) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: entry.value));
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route, isNot(isA<MainNavigationRoute>()));
      expect(route.settings.name, entry.value);
    }
  });

  testWidgets('all four tabs switch pages in Sandbox and retain the bar', (
    tester,
  ) async {
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    expect(AppManager.instance.usesParentApiEndpoints, isTrue);
    final harness = _NavigationHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final bar = tester.element(find.byType(AppBottomNavBar));
    for (final destination in [
      (AppStrings.checkInTitle, AppMenuType.audits),
      (AppStrings.bottomNavPerformance, AppMenuType.performanceSnapshot),
      (AppStrings.bottomNavLtc, AppMenuType.learningTracks),
      (AppStrings.trainingLibraryTitle, AppMenuType.library),
    ]) {
      await tester.tap(_tab(destination.$1));
      await tester.pumpAndSettle();
      expect(
        harness.routes.single.navigationController.selectedMenu,
        destination.$2,
      );
      expect(find.text('${destination.$2.name} row 0'), findsOneWidget);
      expect(AppManager.instance.currentRouteName, _menus[destination.$2]);
      expect(tester.element(find.byType(AppBottomNavBar)), same(bar));
    }
    expect(harness.loads.values, everyElement(1));
    expect(harness.loads, hasLength(4));
    await harness.dispose(tester);
  });

  test(
    'the shell allows all four Sandbox tabs and rejects unsupported menus',
    () {
      AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
      expect(AppManager.instance.usesParentApiEndpoints, isTrue);
      final route =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRouter.trainingLibrary),
              )
              as MainNavigationRoute;
      final navigation = route.navigationController;
      for (final menu in [
        AppMenuType.audits,
        AppMenuType.performanceSnapshot,
        AppMenuType.learningTracks,
        AppMenuType.library,
      ]) {
        navigation.selectMenu(menu);
        expect(navigation.selectedMenu, menu);
        expect(navigation.hasVisited(menu), isTrue);
        expect(route.settings.name, _menus[menu]);
      }
      for (final menu in [
        AppMenuType.compliance,
        AppMenuType.profile,
        AppMenuType.seatProfiles,
        AppMenuType.paygrades,
        AppMenuType.departments,
        AppMenuType.kaizenGpt,
        AppMenuType.home,
      ]) {
        navigation.selectMenu(menu);
        expect(navigation.selectedMenu, AppMenuType.library);
        expect(navigation.hasVisited(menu), isFalse);
      }
      route.dispose();
    },
  );
}

Finder _tab(String label) => find.descendant(
  of: find.byType(AppBottomNavBar),
  matching: find.text(label),
);

class _NavigationHarness {
  final navigatorKey = GlobalKey<NavigatorState>();
  final observer = _RouteObserver();
  final loading = ValueNotifier(false);
  final loads = <AppMenuType, int>{};
  final disposals = <AppMenuType, int>{};
  final routes = <MainNavigationRoute>[];

  MainNavigationRoute _mainRoute(RouteSettings settings) {
    final route = MainNavigationRoute(
      settings: settings,
      initialMenu: _menus.entries
          .firstWhere((entry) => entry.value == settings.name)
          .key,
      destinations: _menus.entries
          .where((entry) => entry.key.isBottomNavigationTab)
          .map(
            (entry) => MainNavigationDestination(
              menu: entry.key,
              routeName: entry.value,
              builder: (_) => _ProbePage(menu: entry.key, harness: this),
            ),
          )
          .toList(),
      onRouteNameChanged: AppManager.instance.updateCurrentRouteName,
    );
    routes.add(route);
    return route;
  }

  Route<dynamic> _route(RouteSettings settings) {
    if (settings.name == _detailsRoute) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('Details')),
      );
    }
    final menu = _menus.entries
        .firstWhere((entry) => entry.value == settings.name)
        .key;
    if (menu.isBottomNavigationTab) {
      return _mainRoute(settings);
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _ProbePage(menu: menu, harness: this),
    );
  }

  Widget build() => ChangeNotifierProvider<AppManager>.value(
    value: AppManager.instance,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      onGenerateInitialRoutes: (_) => [
        _mainRoute(const RouteSettings(name: AppRouter.trainingLibrary)),
      ],
      onGenerateRoute: _route,
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    loading.dispose();
  }
}

class _ProbePage extends StatefulWidget {
  const _ProbePage({required this.menu, required this.harness});

  final AppMenuType menu;
  final _NavigationHarness harness;

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  final searchController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.harness.loads.update(
      widget.menu,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    widget.harness.disposals.update(
      widget.menu,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DrawerMainScreen(
    title: widget.menu.name,
    selectedMenu: widget.menu,
    child: ValueListenableBuilder<bool>(
      valueListenable: widget.harness.loading,
      builder: (context, loading, _) =>
          loading && widget.menu == AppMenuType.audits
          ? const Center(child: FastCircularProgressIndicator())
          : Column(
              children: [
                TextField(controller: searchController),
                TextButton(
                  onPressed: () =>
                      AppRouter.pushNamed<void>(context, _detailsRoute),
                  child: const Text('Open details'),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: 50,
                    itemExtent: 60,
                    itemBuilder: (_, index) =>
                        Text('${widget.menu.name} row $index'),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;
  int replacements = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    AppManager.instance.updateCurrentRouteName(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
    AppManager.instance.updateCurrentRouteName(newRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppManager.instance.updateCurrentRouteName(previousRoute?.settings.name);
  }
}
