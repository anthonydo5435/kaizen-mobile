import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/core/widgets/main_navigation_shell.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_snapshot_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../features/training/fixtures/training_library_fixtures.dart';

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) respond;
  final client = MockClient((request) {
    requests.add(request);
    return respond(request);
  });

  setUp(() async {
    requests.clear();
    respond = (request) async => _response(request, 'Before');
    ApiCallExecutor.clearGetCache();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(
      uuid: 'lead',
      roles: ['dept_lead'],
      organizationUuid: 'org',
    );
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);
  tearDownAll(client.close);

  const cases = [
    (
      name: 'Check-in team',
      route: AppRouter.checkIn,
      personal: false,
      grid: false,
    ),
    (
      name: 'Check-in personal',
      route: AppRouter.checkIn,
      personal: true,
      grid: false,
    ),
    (
      name: 'Performance team',
      route: AppRouter.performanceSnapshot,
      personal: false,
      grid: false,
    ),
    (
      name: 'Performance personal',
      route: AppRouter.performanceSnapshot,
      personal: true,
      grid: false,
    ),
    (
      name: 'LMS list',
      route: AppRouter.trainingLibrary,
      personal: false,
      grid: false,
    ),
    (
      name: 'LMS grid',
      route: AppRouter.trainingLibrary,
      personal: false,
      grid: true,
    ),
  ];
  for (final scenario in cases) {
    testWidgets(
      '${scenario.name} pull refresh fetches fresh data and keeps selection',
      (tester) async {
        await http.runWithClient(() async {
          await _pumpHome(tester, scenario.route);
          final field = find.byType(TextField);
          if (scenario.personal) {
            await tester.tap(
              find.text(
                scenario.route == AppRouter.checkIn
                    ? AppStrings.auditMyCheckInsTab
                    : AppStrings.myReportsTitle,
              ),
            );
            await tester.pumpAndSettle();
          }
          final context = tester.element(field);
          if (scenario.route == AppRouter.trainingLibrary) {
            final controller = context.read<TrainingLibraryController>();
            if (scenario.grid) {
              await controller.changeViewMode(TrainingLibraryViewMode.grid);
            }
            await controller.selectSeat(controller.items.single.seat);
          } else if (scenario.route == AppRouter.checkIn) {
            await context.read<CheckInController>().applyFilters(
              yearQuarter: '2025 - Q2',
              seatProfile: 'Seat',
            );
          } else {
            context.read<PerformanceSnapshotController>().setSelectedJobTitle(
              'Seat',
            );
          }
          await tester.pumpAndSettle();
          await tester.enterText(field, 'Before');
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(find.text('Before'), findsWidgets);

          final lastRequest = requests.last.url;
          final requestCount = requests.length;
          final tab = scenario.route == AppRouter.trainingLibrary
              ? null
              : find.text(
                  scenario.route == AppRouter.checkIn
                      ? AppStrings.auditMyCheckInsTab
                      : AppStrings.myReportsTitle,
                );
          final tabBounds = tab == null ? null : tester.getRect(tab);
          final response = Completer<http.Response>();
          respond = (_) => response.future;
          final indicator = find.byType(RefreshIndicator);
          expect(
            tester.widget<RefreshIndicator>(indicator).color,
            AppColors.purple2,
          );
          final scrolling = find
              .descendant(of: indicator, matching: find.byType(Scrollable))
              .first;

          // The single card does not fill the viewport, but must still allow a pull.
          await tester.drag(scrolling, const Offset(0, 300));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(requests.length, requestCount + 1);
          expect(requests.last.url, lastRequest);
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(find.text('Before'), findsWidgets);
          if (tab != null) {
            expect(tester.getRect(tab), tabBounds);
          }

          response.complete(_response(requests.last, 'After'));
          await tester.pumpAndSettle();
          expect(find.text('After'), findsOneWidget);
          expect(tester.widget<TextField>(field).controller!.text, 'Before');
          if (scenario.route == AppRouter.checkIn) {
            final controller = context.read<CheckInController>();
            expect(
              controller.state.selectedStatus,
              scenario.personal
                  ? AuditMemberStatus.deactivated
                  : AuditMemberStatus.active,
            );
            expect(controller.state.selectedSeatProfile, 'Seat');
            expect(controller.selectedAuditYear, 2025);
            expect(controller.selectedAuditQuarter, 2);
            if (!scenario.personal) {
              expect(requests.last.url.queryParameters['job'], 'job');
            }
          } else if (scenario.route == AppRouter.performanceSnapshot) {
            final controller = context.read<PerformanceSnapshotController>();
            expect(
              controller.selectedTab,
              scenario.personal
                  ? PerformanceSnapshotTab.myReports
                  : PerformanceSnapshotTab.reports,
            );
            expect(controller.selectedJobTitle, 'Seat');
          } else {
            final controller = context.read<TrainingLibraryController>();
            expect(
              controller.selectedSeatId,
              '2a685b4e-5642-4faa-8201-20e2896b2c5b',
            );
            expect(
              controller.viewMode,
              scenario.grid
                  ? TrainingLibraryViewMode.grid
                  : TrainingLibraryViewMode.list,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  for (final route in [
    AppRouter.checkIn,
    AppRouter.performanceSnapshot,
    AppRouter.trainingLibrary,
  ]) {
    testWidgets('$route can pull refresh an empty list', (tester) async {
      respond = (request) async => _response(request, null);
      await http.runWithClient(() async {
        await _pumpHome(tester, route);
        final requestCount = requests.length;
        final response = Completer<http.Response>();
        respond = (_) => response.future;
        final scrolling = find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scrolling, const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(requests.length, requestCount + 1);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        if (route == AppRouter.trainingLibrary) {
          expect(find.byType(FastCircularProgressIndicator), findsNothing);
        }
        response.complete(_response(requests.last, 'After'));
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets('LMS failed pull refresh retains cards and allows retry', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpHome(tester, AppRouter.trainingLibrary);
      respond = (_) async => http.Response('{}', 400);
      final scrolling = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrolling, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Before'), findsOneWidget);
      final controller = tester
          .element(scrolling)
          .read<TrainingLibraryController>();
      expect(controller.isRefreshing, isFalse);
      respond = (request) async => _response(request, 'After');
      await tester.drag(scrolling, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('After'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}

Future<void> _pumpHome(WidgetTester tester, String route) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppManager>.value(
      value: AppManager.instance,
      child: MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [
          AppRouter.onGenerateRoute(RouteSettings(name: route)),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(MainNavigationShell), findsOneWidget);
}

http.Response _response(http.Request request, String? name) {
  if (request.url.path.endsWith('/job/subordinate_jobs/')) {
    return http.Response(
      jsonEncode([
        {'uuid': 'job', 'title': 'Seat'},
      ]),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'count': name == null ? 0 : 1,
      'current': 1,
      'next': null,
      'previous': null,
      'results': name == null
          ? []
          : [
              if (request.url.path.contains('training_modules'))
                {...lessonListingJson(), 'title': name, 'thumbnail_link': null}
              else
                {
                  'uuid': 'audit',
                  'profile_job': 'profile-job',
                  'profile': {
                    'uuid': 'profile',
                    'name': name,
                    'onboarded': true,
                  },
                  'job': {'uuid': 'job', 'title': 'Seat'},
                  'overall_score': 4,
                  'confidence_level': 80,
                },
            ],
    }),
    200,
  );
}
