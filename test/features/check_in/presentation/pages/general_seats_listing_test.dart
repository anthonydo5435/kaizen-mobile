import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_details_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/general_seats_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_member_card.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_status_switcher.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/general_seat_audit_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  final requests = <http.Request>[];
  late MockClient client;
  RouteSettings? descriptionRoute;
  var emptyMainList = false;

  setUp(() async {
    requests.clear();
    descriptionRoute = null;
    emptyMainList = false;
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'reviewer', isOwner: true, roles: ['team_lead']);
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
    ApiCallExecutor.clearGetCache();
    client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      Object response;
      if (path.endsWith('job/job-1/subordinate_profile_jobs/')) {
        response = [
          {
            'uuid': 'subordinate-profile-job',
            'title': 'Backend Dev',
            'is_primary': false,
            'created_at': '1778063413000',
            'profile': {
              'uuid': 'subordinate-profile',
              'name': 'Gretchen Bradford',
              'user_uuid': 'subordinate-user',
              'email': 'paze@mailinator.com',
              'image': null,
              'onboarded': true,
            },
          },
        ];
      } else if (path.endsWith('quarterly_audit/seat_audits/')) {
        response = {
          'count': 2,
          'current': 1,
          'next': null,
          'previous': null,
          'results': [
            _seat,
            {
              ..._seat,
              'uuid': 'new-audit',
              'job': {'uuid': 'job-2', 'title': 'Mobile Developers'},
              'overall_score': 0,
              'last_audit_date': null,
            },
          ],
        };
      } else if (path.endsWith('quarterly_audit/seat/job-1/audits/')) {
        response = {
          ..._seat,
          'has_inconsistency': false,
          'audits': [
            {
              'date': '2026-10-16',
              'quarterly_audit_uuid': 'row-audit',
              'audit_details': {
                'great': 14,
                'needs_improvement': 3,
                'almost_there': 5,
              },
            },
          ],
        };
      } else if (path.endsWith('quarterly_audit/') ||
          path.endsWith('quarterly_audit/my_audits/')) {
        response = {
          'count': 1,
          'current': 1,
          'results': emptyMainList
              ? []
              : [
                  {
                    'uuid': 'normal-audit',
                    'profile_job': 'profile-job',
                    'profile': {
                      'uuid': 'member',
                      'name': 'Member',
                      'onboarded': true,
                    },
                    'job': {'uuid': 'normal-job', 'title': 'Normal Seat'},
                  },
                ],
        };
      } else {
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      }
      return http.Response(jsonEncode(response), 200);
    });
  });
  tearDown(() {
    client.close();
    AppManager.instance.resetSessionState();
  });

  Widget screen({double textScale = 1}) =>
      ChangeNotifierProvider<AppManager>.value(
        value: AppManager.instance,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const CheckInScreen(),
          onGenerateRoute: (settings) {
            if (settings.name == AppRouter.checkInDescriptionsList) {
              descriptionRoute = settings;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Descriptions')),
              );
            }
            return AppRouter.onGenerateRoute(settings);
          },
        ),
      );

  testWidgets(
    'General Seats loads on selection and preserves the Check-ins list',
    (tester) async {
      _setViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        expect(find.byType(CheckInStatusSwitcher), findsOneWidget);
        expect(find.byType(CheckInMemberCard), findsOneWidget);
        expect(requests.where(_isSeatList), isEmpty);
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        expect(requests.where(_isSeatList), hasLength(1));
        final request = requests.last;
        final current = CustomFunctions.currentYearQuarter();
        expect(request.url.queryParameters, {
          'page': '1',
          'page_size': '12',
          'year': '${current.year}',
          'quarter': '${current.quarter}',
        });
        expect(find.byType(GeneralSeatAuditCard), findsNWidgets(2));
        expect(find.text('3'), findsOneWidget);
        expect(find.text(AppStrings.auditScoreUnavailable), findsOneWidget);
        final cards = tester.getTopLeft(
          find.byType(GeneralSeatAuditCard).first,
        );
        final nextCard = tester.getTopLeft(
          find.byType(GeneralSeatAuditCard).last,
        );
        expect(cards.dx, nextCard.dx);
        expect(nextCard.dy, greaterThan(cards.dy));
        await _tap(tester, find.text(AppStrings.auditCheckInsTab));
        expect(find.byType(CheckInMemberCard), findsOneWidget);
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        expect(requests.where(_isSeatList), hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'General Seats is second in the existing team tab bar ($textScale)',
      (tester) async {
        _setViewport(tester, width: 390);
        final user = User(uuid: 'reviewer', roles: ['team_lead']);
        await AppPreference.saveUser(user);
        AppManager.instance.updateCurrentUser(user);
        await http.runWithClient(() async {
          await tester.pumpWidget(screen(textScale: textScale));
          await tester.pumpAndSettle();
          final switcher = find.byType(CheckInStatusSwitcher);
          expect(switcher, findsOneWidget);
          expect(find.text(AppStrings.auditCheckInsTab), findsNothing);
          final team = find.descendant(
            of: switcher,
            matching: find.text(AppStrings.auditTeamMembersTab),
          );
          final general = find.descendant(
            of: switcher,
            matching: find.text(AppStrings.auditGeneralSeatsTab),
          );
          final mine = find.descendant(
            of: switcher,
            matching: find.text(AppStrings.auditMyCheckInsTab),
          );
          expect(tester.getCenter(team).dy, tester.getCenter(general).dy);
          expect(tester.getCenter(general).dy, tester.getCenter(mine).dy);
          expect(
            tester.getCenter(team).dx,
            lessThan(tester.getCenter(general).dx),
          );
          expect(
            tester.getCenter(general).dx,
            lessThan(tester.getCenter(mine).dx),
          );

          await _tap(tester, general);
          expect(switcher, findsOneWidget);
          expect(
            tester
                .widget<CheckInStatusSwitcher>(switcher)
                .isGeneralSeatsSelected,
            isTrue,
          );
          expect(find.byType(GeneralSeatAuditCard), findsWidgets);
          await _tap(tester, mine);
          expect(
            tester
                .widget<CheckInStatusSwitcher>(switcher)
                .isGeneralSeatsSelected,
            isFalse,
          );
          expect(
            tester.widget<CheckInStatusSwitcher>(switcher).selectedStatus,
            AuditMemberStatus.deactivated,
          );
          expect(find.byType(CheckInMemberCard), findsWidgets);
          await _tap(tester, general);
          await _tap(tester, team);
          expect(
            tester.widget<CheckInStatusSwitcher>(switcher).selectedStatus,
            AuditMemberStatus.active,
          );
          expect(requests.where(_isSeatList), hasLength(1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  testWidgets(
    'quarter dropdown changes the selected year and applies a quarter directly',
    (tester) async {
      _setViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        final controller = tester
            .element(find.byType(GeneralSeatAuditCard).first)
            .read<GeneralSeatsController>();
        final previousYear = controller.year - 1;
        final selector = find.byKey(
          const ValueKey('general-seats-quarter-selector'),
        );
        final initialHeight = tester.getSize(selector).height;
        expect(find.byType(InputChip), findsNothing);
        await _tap(tester, selector);
        expect(find.byType(MenuItemButton), findsNWidgets(5));
        await _tap(
          tester,
          find.byKey(const ValueKey('check-in-quarter-year-header')),
        );
        await _tap(
          tester,
          find.byKey(ValueKey('check-in-quarter-year-$previousYear')),
        );
        expect(requests.where(_isSeatList), hasLength(1));
        await _tap(
          tester,
          find.byKey(ValueKey('check-in-quarter-option-$previousYear-2')),
        );
        expect(requests.where(_isSeatList), hasLength(2));
        expect(requests.last.url.queryParameters, {
          'page': '1',
          'page_size': '12',
          'year': '$previousYear',
          'quarter': '2',
        });
        expect(
          find.text(AppStrings.auditQuarterPeriodLabel(previousYear, 2)),
          findsOneWidget,
        );
        expect(tester.getSize(selector).height, initialHeight);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets(
    'quarter picker stays draft until Apply and closing discards it',
    (tester) async {
      _setViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        final controller = tester
            .element(find.byType(GeneralSeatAuditCard).first)
            .read<GeneralSeatsController>();
        final previousYear = controller.year - 1;
        await _tap(tester, find.byTooltip(AppStrings.auditFiltersTitle));
        expect(find.text(AppStrings.auditSeatProfile), findsNothing);
        await _tap(tester, find.text(controller.yearQuarterLabel));
        await _tap(tester, find.text('$previousYear'));
        await _tap(
          tester,
          find.text(AppStrings.auditQuarterYear(previousYear, 2)),
        );
        await _tap(tester, find.text(AppStrings.done));
        expect(requests.where(_isSeatList), hasLength(1));
        Navigator.of(
          tester.element(find.text(AppStrings.auditApplyFilters)),
        ).pop();
        await tester.pumpAndSettle();
        expect(requests.where(_isSeatList), hasLength(1));

        await _tap(tester, find.byTooltip(AppStrings.auditFiltersTitle));
        await _tap(tester, find.text(controller.yearQuarterLabel));
        await _tap(tester, find.text('$previousYear'));
        await _tap(
          tester,
          find.text(AppStrings.auditQuarterYear(previousYear, 2)),
        );
        await _tap(tester, find.text(AppStrings.done));
        await _tap(tester, find.text(AppStrings.auditApplyFilters));
        expect(requests.where(_isSeatList), hasLength(2));
        expect(requests.last.url.queryParameters['year'], '$previousYear');
        expect(requests.last.url.queryParameters['quarter'], '2');
        expect(requests.last.url.queryParameters['page'], '1');
        expect(
          find.text(AppStrings.auditQuarterPeriodLabel(previousYear, 2)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets(
    'View uses seat details, keeps the seat endpoint on period changes and opens row audits',
    (tester) async {
      _setViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        final listController = tester
            .element(find.byType(GeneralSeatAuditCard).first)
            .read<GeneralSeatsController>();
        await listController.applyYearQuarter('2026 - Q4');
        await tester.pumpAndSettle();
        final listRequestCount = requests.where(_isSeatList).length;
        await _tap(
          tester,
          find.descendant(
            of: find.byType(GeneralSeatAuditCard).first,
            matching: find.text(AppStrings.view),
          ),
        );
        expect(find.byType(CheckInDetailsScreen), findsOneWidget);
        http.Request detailsRequest() => requests.lastWhere(
          (request) =>
              request.url.path.endsWith('quarterly_audit/seat/job-1/audits/'),
        );
        expect(
          detailsRequest().url.path,
          endsWith('quarterly_audit/seat/job-1/audits/'),
        );
        expect(detailsRequest().url.queryParameters, {
          'start': '2026-10-01',
          'end': '2026-12-31',
        });
        expect(find.text('14'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('check-in-details-chart-toggle')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('check-in-details-team-filter')),
          findsNothing,
        );
        final detailContext = tester.element(find.text('14'));
        final controller = detailContext.read<CheckInController>();
        final subordinateRequest = requests.singleWhere(
          (request) =>
              request.url.path.endsWith('job/job-1/subordinate_profile_jobs/'),
        );
        expect(subordinateRequest.method, 'GET');
        expect(subordinateRequest.url.queryParameters, isEmpty);
        expect(
          controller.subordinateProfileJobs.single.uuid,
          'subordinate-profile-job',
        );
        expect(
          controller.subordinateProfileJobs.single.profile.name,
          'Gretchen Bradford',
        );
        expect(controller.isSubordinateProfileJobsLoading, isFalse);
        await controller.selectDetailsQuarter('2026 - Q1');
        await tester.pumpAndSettle();
        expect(detailsRequest().url.queryParameters, {
          'start': '2026-01-01',
          'end': '2026-03-31',
        });
        await controller.applyDetailsDateRange(
          startDate: DateTime(2026, 2, 3),
          endDate: DateTime(2026, 2, 20),
        );
        await tester.pumpAndSettle();
        expect(detailsRequest().url.queryParameters, {
          'start': '2026-02-03',
          'end': '2026-02-20',
        });
        await _tap(tester, find.text(CustomFunctions.formatDate('2026-10-16')));
        expect(
          (descriptionRoute!.arguments as CheckInDescriptionsListRouteArgs)
              .quarterlyAuditId,
          'row-audit',
        );
        expect(
          (descriptionRoute!.arguments as CheckInDescriptionsListRouteArgs)
              .isGeneralSeatAudit,
          isTrue,
        );
        Navigator.of(tester.element(find.text('Descriptions'))).pop();
        await tester.pumpAndSettle();
        expect(
          requests.last.url.path,
          endsWith('quarterly_audit/seat/job-1/audits/'),
        );
        expect(requests.last.url.queryParameters, {
          'start': '2026-02-03',
          'end': '2026-02-20',
        });
        Navigator.of(tester.element(find.byType(CheckInDetailsScreen))).pop();
        await tester.pumpAndSettle();
        expect(
          requests.last.url.path,
          endsWith('quarterly_audit/seat_audits/'),
        );
        expect(requests.where(_isSeatList), hasLength(listRequestCount + 1));
        expect(
          requests.where(
            (request) => request.url.path.endsWith('subordinate_profile_jobs/'),
          ),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets(
    'General Seats is overflow-safe on a narrow phone with large text',
    (tester) async {
      _setViewport(tester, width: 320);
      emptyMainList = true;
      await http.runWithClient(() async {
        await tester.pumpWidget(screen(textScale: 2));
        await tester.pumpAndSettle();
        await _tap(tester, find.text(AppStrings.auditGeneralSeatsTab));
        expect(find.byType(GeneralSeatAuditCard), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

const _seat = {
  'uuid': 'seat-audit',
  'job': {'uuid': 'job-1', 'title': 'Senior Full Stack Dev'},
  'overall_score': 3.0,
  'last_audit_date': 'Oct 16, 2026',
  'profiles': [
    {
      'uuid': 'member',
      'name': 'Member',
      'user_uuid': 'member-user',
      'email': 'member@example.com',
      'image': null,
      'onboarded': true,
    },
  ],
};

bool _isSeatList(http.Request request) =>
    request.url.path.endsWith('quarterly_audit/seat_audits/');

void _setViewport(WidgetTester tester, {double width = 600}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
