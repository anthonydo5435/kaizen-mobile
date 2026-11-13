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
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_descriptions_list_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_details_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_details_period_controls.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  var response = _details();
  Future<http.Response> Function(http.Request)? responseHandler;
  final requests = <http.Request>[];
  // ApiCallExecutor keeps one HTTP client, so its mock reads the current fixture.
  final client = MockClient((request) async {
    requests.add(request);
    if (responseHandler != null) return responseHandler!(request);
    if (request.url.path.endsWith(ApiEndPoints.quarterlyAuditEvaluationChart('profile-job'))) {
      return http.Response('[]', 200);
    }
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    response = _details();
    responseHandler = null;
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'reviewer', isOwner: true);
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);

  for (final tapAction in [false, true]) {
    testWidgets('audit ${tapAction ? 'action' : 'row'} passes its quarterly audit UUID', (
      tester,
    ) async {
      _setViewport(tester);
      const rows = [
        (uuid: 'first-quarterly-audit', date: '2000-01-01', key: 'quarterly_audit_uuid'),
        (uuid: 'second-quarterly-audit', date: '2000-04-01', key: 'quarterlyAuditUuid'),
      ];
      response = {
        ..._details(),
        'uuid': 'summary-id',
        'audits': rows
            .map(
              (row) => {
                row.key: row.uuid,
                'date': row.date,
                'audit_details': {'great': 1},
              },
            )
            .toList(),
      };
      responseHandler = (request) async {
        final path = request.url.path;
        if (path.endsWith(ApiEndPoints.quarterlyAuditDetails('profile-job'))) {
          return http.Response(jsonEncode(response), 200);
        }
        if (path.endsWith(ApiEndPoints.quarterlyAudit)) {
          return http.Response(jsonEncode({'count': 0, 'current': 1, 'results': []}), 200);
        }
        if (path.endsWith('/details/')) {
          return http.Response(
            jsonEncode({
              'uuid': path.split('/').reversed.elementAt(2),
              'profile': {'uuid': 'member', 'name': 'Member', 'onboarded': true},
              'job': {'uuid': 'seat', 'title': 'Operator'},
              'profile_job': 'profile-job',
              'categories': [],
              'descriptions': [],
            }),
            200,
          );
        }
        throw StateError('Unexpected request: ${request.url}');
      };

      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(openDescriptions: true));
        await tester.pumpAndSettle();
        for (final row in rows) {
          final dateLabel = find.text(CustomFunctions.formatDate(row.date));
          final target = tapAction
              ? find.descendant(
                  of: find.ancestor(of: dateLabel, matching: find.byType(GestureDetector)).first,
                  matching: find.text(AppStrings.view),
                )
              : dateLabel;
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          final screen = tester.widget<CheckInDescriptionsListScreen>(
            find.byType(CheckInDescriptionsListScreen),
          );
          expect(screen.quarterlyAuditId, row.uuid);
          expect(screen.date, row.date);
          final request = requests.lastWhere((request) => request.url.path.endsWith('/details/'));
          expect(request.url.path, endsWith(ApiEndPoints.quarterlyAuditDetail(row.uuid)));
          expect(request.url.queryParameters, {'date': row.date});
          Navigator.of(tester.element(find.byType(CheckInDescriptionsListScreen))).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  testWidgets('quarter dropdown refreshes the selected period and retains the profile', (
    tester,
  ) async {
    _setViewport(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(year: 2026, quarter: 4, selectedProfileUuid: 'member'));
      await tester.pumpAndSettle();
      final selectorFinder = find.byKey(const ValueKey('check-in-details-period-selector'));
      final initialSelectorHeight = tester.getSize(selectorFinder).height;
      await tester.tap(find.byKey(const ValueKey('check-in-details-quarter-selector')));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(5));
      _expectNoDateShortcutOptions();
      final selectedQuarter = tester.widget<MenuItemButton>(
        find.byKey(const ValueKey('check-in-quarter-option-2026-4')),
      );
      expect(selectedQuarter.style!.backgroundColor!.resolve({}), AppColors.secondaryColor);
      await tester.tap(find.text(AppStrings.auditQuarterOptionLabel(2)));
      await tester.pumpAndSettle();

      expect(requests.last.url.queryParameters, {
        'year': '2026',
        'quarter': '2',
        'start': '2026-04-01',
        'end': '2026-06-30',
        'profile': 'member',
      });
      expect(find.text(AppStrings.auditQuarterPeriodLabel(2026, 2)), findsOneWidget);
      expect(tester.getSize(selectorFinder).height, initialSelectorHeight);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('quarter menu changes the displayed year before applying a quarter', (tester) async {
    _setViewport(tester);
    final current = CustomFunctions.currentYearQuarter();
    final previousYear = current.year - 1;
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(selectedProfileUuid: 'member'));
      await tester.pumpAndSettle();
      final requestCount = requests.length;
      await tester.tap(find.byKey(const ValueKey('check-in-details-quarter-selector')));
      await tester.pumpAndSettle();
      expect(find.text('${current.year}'), findsOneWidget);
      expect(find.byType(MenuItemButton), findsNWidgets(5));
      await tester.tap(find.byKey(const ValueKey('check-in-quarter-year-header')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_quarterMenuSurface()).width,
        closeTo(
          tester.getSize(find.byKey(const ValueKey('check-in-details-period-selector'))).width,
          0.5,
        ),
      );
      await tester.tap(find.byKey(ValueKey('check-in-quarter-year-$previousYear')));
      await tester.pumpAndSettle();
      expect(find.text('$previousYear'), findsOneWidget);
      expect(find.byType(MenuItemButton), findsNWidgets(5));
      expect(requests.length, requestCount);
      await tester.tap(find.text(AppStrings.auditQuarterOptionLabel(3)));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {
        'year': '$previousYear',
        'quarter': '3',
        'start': '$previousYear-07-01',
        'end': '$previousYear-09-30',
        'profile': 'member',
      });
      expect(find.text(AppStrings.auditQuarterPeriodLabel(previousYear, 3)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('check-in-details-quarter-selector')));
      await tester.pumpAndSettle();
      final selectedQuarter = tester.widget<MenuItemButton>(
        find.byKey(ValueKey('check-in-quarter-option-$previousYear-3')),
      );
      expect(selectedQuarter.style!.backgroundColor!.resolve({}), AppColors.secondaryColor);
      expect(tester.takeException(), isNull);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }, () => client);
  });

  testWidgets('date-range picker applies dates and remembers them when switching modes', (
    tester,
  ) async {
    _setViewport(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(year: 2026, quarter: 2, selectedProfileUuid: 'member'));
      await tester.pumpAndSettle();
      final selectorFinder = find.byKey(const ValueKey('check-in-details-period-selector'));
      final quarterHeight = tester.getSize(selectorFinder).height;
      await tester.tap(find.text(AppStrings.auditDateRangeMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(selectorFinder).height, quarterHeight);
      expect(find.byKey(const ValueKey('check-in-details-quarter-selector')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-details-date-range')));
      await tester.pumpAndSettle();
      _expectNoDateShortcutOptions();
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      final formatDate = MaterialLocalizations.of(
        tester.element(find.byType(Dialog)),
      ).formatShortDate;
      expect(find.text(formatDate(DateTime(2026, 4, 1))), findsOneWidget);
      expect(find.text(formatDate(DateTime(2026, 6, 30))), findsOneWidget);
      final selectedDay = tester.widget<Container>(
        find.ancestor(of: find.text('15'), matching: find.byType(Container)).first,
      );
      expect((selectedDay.decoration as BoxDecoration).color, AppColors.secondaryColor);
      final requestsBeforeEditing = requests.length;
      await tester.tap(find.text('5').first);
      await tester.pump();
      await tester.tap(find.text('12'));
      await tester.pump();
      expect(requests.length, requestsBeforeEditing);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(requests.last.url.queryParameters, {
        'start': '2026-04-05',
        'end': '2026-04-12',
        'profile': 'member',
      });
      expect(find.text(AppStrings.auditDateRangeLabel('2026-04-05', '2026-04-12')), findsOneWidget);
      expect(tester.getSize(selectorFinder).height, quarterHeight);

      ApiCallExecutor.clearGetCache();
      await tester.tap(find.text(AppStrings.auditQuarterMode));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('check-in-details-quarter-selector')), findsOneWidget);
      expect(requests.last.url.queryParameters['start'], '2026-04-01');
      expect(requests.last.url.queryParameters['end'], '2026-06-30');
      ApiCallExecutor.clearGetCache();
      await tester.tap(find.text(AppStrings.auditDateRangeMode));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.auditDateRangeLabel('2026-04-05', '2026-04-12')), findsOneWidget);
      expect(requests.last.url.queryParameters['start'], '2026-04-05');
      expect(requests.last.url.queryParameters['end'], '2026-04-12');

      final requestCount = requests.length;
      await tester.tap(find.byKey(const ValueKey('check-in-details-date-range')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      _expectNoDateShortcutOptions();
      expect(requests.length, requestCount);
      expect(find.text(AppStrings.auditDateRangeLabel('2026-04-05', '2026-04-12')), findsOneWidget);

      final controller = tester
          .element(find.byType(CheckInDetailsPeriodControls))
          .read<CheckInController>();
      await controller.selectDetailsQuarter('2026 - Q3');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.auditDateRangeMode));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-details-date-range')));
      await tester.pumpAndSettle();
      expect(find.text(formatDate(DateTime(2026, 7, 1))), findsOneWidget);
      expect(find.text(formatDate(DateTime(2026, 9, 30))), findsOneWidget);
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('graph requests follow the selected quarter and custom date range', (tester) async {
    _setViewport(tester);
    final current = CustomFunctions.currentYearQuarter();
    final previousYear = current.year - 1;
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(selectedProfileUuid: 'member'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.checkInListTitle), findsOneWidget);
      expect(find.text(AppStrings.checkInPerformanceChart), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-details-chart-toggle')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.checkInPerformanceChart), findsOneWidget);
      expect(find.text(AppStrings.checkInListTitle), findsNothing);
      expect(requests.last.url.queryParameters, {
        'time_range': 'current_quarter',
        'profile': 'member',
      });
      final controller = tester
          .element(find.byType(CheckInDetailsPeriodControls))
          .read<CheckInController>();
      expect(controller.detailsPeriodMode, CheckInDetailsPeriodMode.quarter);
      await controller.selectDetailsQuarter('$previousYear - Q1');
      await tester.pumpAndSettle();
      expect(
        requests.last.url.path,
        endsWith(ApiEndPoints.quarterlyAuditEvaluationChart('profile-job')),
      );
      expect(requests.last.url.queryParameters['start'], '$previousYear-01-01');
      expect(requests.last.url.queryParameters['end'], '$previousYear-03-31');
      expect(requests.last.url.queryParameters, isNot(contains('time_range')));

      await controller.applyDetailsDateRange(
        startDate: DateTime(2026, 2, 15),
        endDate: DateTime(2026, 4, 5),
      );
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {
        'start': '2026-02-15',
        'end': '2026-04-05',
        'profile': 'member',
      });
      ApiCallExecutor.clearGetCache();
      await controller.selectDetailsQuarter('${current.year} - Q${current.quarter}');
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {
        'time_range': 'current_quarter',
        'profile': 'member',
      });
      await tester.tap(find.byKey(const ValueKey('check-in-details-chart-toggle')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.checkInListTitle), findsOneWidget);
      expect(find.text(AppStrings.checkInPerformanceChart), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('changing team member and returning from details retain the custom dates', (
    tester,
  ) async {
    _setViewport(tester);
    response = {
      ..._details(),
      'profiles': [
        {'uuid': 'other-member', 'name': 'Other Member', 'onboarded': true},
      ],
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(year: 2026, quarter: 2));
      await tester.pumpAndSettle();
      final controller = tester
          .element(find.byType(CheckInDetailsPeriodControls))
          .read<CheckInController>();
      await controller.applyDetailsDateRange(
        startDate: DateTime(2026, 4, 5),
        endDate: DateTime(2026, 4, 12),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-details-team-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other Member'));
      await tester.tap(find.text(AppStrings.done));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {
        'start': '2026-04-05',
        'end': '2026-04-12',
        'profile': 'other-member',
      });

      await tester.tap(find.text(AppStrings.view));
      await tester.pumpAndSettle();
      ApiCallExecutor.clearGetCache();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(controller.detailsPeriodMode, CheckInDetailsPeriodMode.dateRange);
      expect(requests.last.url.queryParameters, {
        'start': '2026-04-05',
        'end': '2026-04-12',
        'profile': 'other-member',
      });
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('a late response cannot replace the most recently selected quarter', (tester) async {
    _setViewport(tester);
    final olderResponse = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(year: 2026, quarter: 4));
      await tester.pumpAndSettle();
      final controller = tester
          .element(find.byType(CheckInDetailsPeriodControls))
          .read<CheckInController>();
      responseHandler = (request) async {
        if (request.url.queryParameters['quarter'] == '2') return olderResponse.future;
        return http.Response(
          jsonEncode({
            ..._details(),
            'job': {'uuid': 'seat', 'title': 'Latest Seat'},
          }),
          200,
        );
      };
      final olderSelection = controller.selectDetailsQuarter('2026 - Q2');
      await tester.pump();
      expect(requests.last.url.queryParameters['quarter'], '2');
      await controller.selectDetailsQuarter('2026 - Q1');
      olderResponse.complete(http.Response(jsonEncode(_details()), 200));
      await olderSelection;
      await tester.pumpAndSettle();
      expect(controller.selectedAuditQuarter, 1);
      expect(controller.state.details?.jobTitle, 'Latest Seat');
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('a failed period refresh keeps selectors available and hides stale audit rows', (
    tester,
  ) async {
    _setViewport(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen(year: 2026, quarter: 4));
      await tester.pumpAndSettle();
      final controller = tester
          .element(find.byType(CheckInDetailsPeriodControls))
          .read<CheckInController>();
      responseHandler = (_) async => http.Response('{}', 400);
      await controller.selectDetailsQuarter('2026 - Q2');
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.auditDetailsLoadFailed), findsOneWidget);
      expect(find.text(AppStrings.view), findsNothing);
      expect(find.byKey(const ValueKey('check-in-details-quarter-selector')), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);

      responseHandler = null;
      await controller.selectDetailsQuarter('2026 - Q1');
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.auditDetailsLoadFailed), findsNothing);
      expect(find.text(AppStrings.view), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  for (final width in [320.0, 600.0, 800.0]) {
    testWidgets('period controls fit width $width with enlarged text', (tester) async {
      _setViewport(tester);
      tester.view.physicalSize = Size(width, 844);
      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(year: 2026, quarter: 4, textScale: 1.5));
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text(AppStrings.checkInListTitle));
        final toggle = tester.getRect(find.text(AppStrings.auditQuarterMode));
        final chart = tester.getRect(find.byKey(const ValueKey('check-in-details-chart-toggle')));
        final controls = tester.getRect(find.byType(CheckInDetailsPeriodControls));
        final cardFinder = find.byKey(const ValueKey('check-in-details-evaluation-card'));
        expect(controls.bottom, lessThan(tester.getRect(cardFinder).top));
        expect(toggle.bottom, lessThan(title.top));
        expect(chart.center.dy, closeTo(title.center.dy, 0.5));
        expect(chart.left, greaterThan(title.right));
        expect(
          find.descendant(of: cardFinder, matching: find.byType(CheckInDetailsPeriodControls)),
          findsNothing,
        );
        if (width == 800) {
          final selector = tester.getRect(
            find.byKey(const ValueKey('check-in-details-quarter-selector')),
          );
          expect(selector.left, greaterThan(toggle.right));
          expect(selector.top, lessThan(toggle.bottom));
        }
        await tester.ensureVisible(find.byKey(const ValueKey('check-in-details-quarter-selector')));
        await tester.pumpAndSettle();
        final selectorFinder = find.byKey(const ValueKey('check-in-details-period-selector'));
        final quarterHeight = tester.getSize(selectorFinder).height;
        expect(
          find.byKey(const ValueKey('check-in-details-quarter-selector')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('check-in-details-quarter-selector')));
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(5));
        final fieldWidth = tester.getSize(selectorFinder).width;
        expect(tester.getSize(_quarterMenuSurface()).width, closeTo(fieldWidth, 0.5));
        expect(
          tester.getSize(find.byKey(const ValueKey('check-in-quarter-option-2026-4'))).width,
          closeTo(fieldWidth - 16, 0.5),
        );
        expect(tester.takeException(), isNull);
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(AppStrings.auditDateRangeMode));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.auditDateRangeMode));
        await tester.pumpAndSettle();
        expect(tester.getSize(selectorFinder).height, quarterHeight);
        await tester.ensureVisible(find.byKey(const ValueKey('check-in-details-date-range')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('check-in-details-date-range')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('check-in-details-date-range')));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(Dialog))).pop();
        await tester.pumpAndSettle();
      }, () => client);
    });
  }

  testWidgets('opening without a selected period sends the current quarter dates', (tester) async {
    _setViewport(tester);
    final current = CustomFunctions.currentYearQuarter();
    final (start, end) = switch (current.quarter) {
      1 => ('01-01', '03-31'),
      2 => ('04-01', '06-30'),
      3 => ('07-01', '09-30'),
      _ => ('10-01', '12-31'),
    };

    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, endsWith(ApiEndPoints.quarterlyAuditDetails('profile-job')));
      expect(request.url.queryParameters['start'], '${current.year}-$start');
      expect(request.url.queryParameters['end'], '${current.year}-$end');
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  for (final period in [
    (year: 2026, quarter: 1, start: '2026-01-01', end: '2026-03-31'),
    (year: 2026, quarter: 2, start: '2026-04-01', end: '2026-06-30'),
    (year: 2026, quarter: 3, start: '2026-07-01', end: '2026-09-30'),
    (year: 2026, quarter: 4, start: '2026-10-01', end: '2026-12-31'),
    (year: 2025, quarter: 4, start: '2025-10-01', end: '2025-12-31'),
  ]) {
    testWidgets('selected ${period.year} Q${period.quarter} sends its full date range', (
      tester,
    ) async {
      _setViewport(tester);

      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(year: period.year, quarter: period.quarter));
        await tester.pumpAndSettle();

        final request = requests.single;
        expect(request.url.queryParameters['year'], '${period.year}');
        expect(request.url.queryParameters['quarter'], '${period.quarter}');
        expect(request.url.queryParameters['start'], period.start);
        expect(request.url.queryParameters['end'], period.end);
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  for (final scenario in [
    (
      name: 'current quarter shows New',
      yearOffset: 0,
      quarterOffset: 0,
      today: false,
      self: false,
      action: AppStrings.newCheckIn,
    ),
    (
      name: 'previous quarter hides New',
      yearOffset: 0,
      quarterOffset: -1,
      today: false,
      self: false,
      action: null,
    ),
    (
      name: 'same quarter in a previous year hides New',
      yearOffset: -1,
      quarterOffset: 0,
      today: false,
      self: false,
      action: null,
    ),
    (
      name: 'future quarter hides New',
      yearOffset: 0,
      quarterOffset: 1,
      today: false,
      self: false,
      action: null,
    ),
    (
      name: 'today still shows Continue',
      yearOffset: 0,
      quarterOffset: 0,
      today: true,
      self: false,
      action: AppStrings.continueCheckIn,
    ),
    (
      name: 'quarter guard does not change Continue',
      yearOffset: -1,
      quarterOffset: 0,
      today: true,
      self: false,
      action: AppStrings.continueCheckIn,
    ),
    (
      name: 'self check-in still hides New',
      yearOffset: 0,
      quarterOffset: 0,
      today: false,
      self: true,
      action: null,
    ),
    (
      name: 'self check-in still hides Continue',
      yearOffset: 0,
      quarterOffset: 0,
      today: true,
      self: true,
      action: null,
    ),
  ]) {
    testWidgets(scenario.name, (tester) async {
      _setViewport(tester);
      final current = CustomFunctions.currentYearQuarter();
      final period = CustomFunctions.currentYearQuarter(
        date: DateTime(
          current.year + scenario.yearOffset,
          (current.quarter - 1 + scenario.quarterOffset) * 3 + 1,
        ),
      );
      response = _details(today: scenario.today, self: scenario.self);

      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(year: period.year, quarter: period.quarter));
        await tester.pumpAndSettle();
        final request = requests.single;
        expect(request.method, 'GET');
        expect(request.url.path, endsWith(ApiEndPoints.quarterlyAuditDetails('profile-job')));
        expect(request.url.queryParameters['year'], '${period.year}');
        expect(request.url.queryParameters['quarter'], '${period.quarter}');

        if (scenario.action == null) {
          expect(find.byType(AppButton), findsNothing);
        } else {
          final button = tester.widget<AppButton>(find.byType(AppButton));
          expect(button.text, scenario.action);
          expect(button.onPressed, isNotNull);
        }
        // Existing historical rows remain available regardless of the new-action guard.
        expect(find.text(AppStrings.view).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  testWidgets('stale New action rechecks the selected quarter before navigation', (tester) async {
    _setViewport(tester);
    final current = CustomFunctions.currentYearQuarter();
    var navigations = 0;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _screen(year: current.year, quarter: current.quarter, onNavigate: () => navigations++),
      );
      await tester.pumpAndSettle();
      final buttonFinder = find.byType(AppButton);
      final onPressed = tester.widget<AppButton>(buttonFinder).onPressed!;
      final controller = tester.element(buttonFinder).read<CheckInController>();

      await controller.initializeDetails(
        'profile-job',
        year: current.year - 1,
        quarter: current.quarter,
      );
      onPressed();
      await tester.pumpAndSettle();

      expect(find.byType(AppButton), findsNothing);
      expect(navigations, 0);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('New action retains the existing action-loading guard', (tester) async {
    _setViewport(tester);
    final current = CustomFunctions.currentYearQuarter();
    var navigations = 0;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        _screen(year: current.year, quarter: current.quarter, onNavigate: () => navigations++),
      );
      await tester.pumpAndSettle();
      final buttonFinder = find.byType(AppButton);
      final onPressed = tester.widget<AppButton>(buttonFinder).onPressed!;
      final controller = tester.element(buttonFinder).read<CheckInController>();
      controller.setAuditActionLoading(true);
      onPressed();
      await tester.pump();

      expect(tester.widget<AppButton>(buttonFinder).isLoading, isTrue);
      expect(navigations, 0);
      controller.setAuditActionLoading(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

void _expectNoDateShortcutOptions() {
  expect(find.text('This Month'), findsNothing);
  expect(find.text(AppStrings.performanceReportThisQuarter), findsNothing);
  expect(find.text(AppStrings.performanceReportCustomDateRange), findsNothing);
}

Finder _quarterMenuSurface() => find
    .ancestor(
      of: find.byKey(const ValueKey('check-in-quarter-year-header')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == AppColors.surfaceDark3,
      ),
    )
    .first;

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({
  int? year,
  int? quarter,
  String? selectedProfileUuid,
  double textScale = 1,
  VoidCallback? onNavigate,
  bool openDescriptions = false,
}) {
  return ChangeNotifierProvider<AppManager>.value(
    value: AppManager.instance,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: CheckInDetailsScreen(
        profileJobId: 'profile-job',
        year: year,
        quarter: quarter,
        selectedProfileUuid: selectedProfileUuid,
      ),
      onGenerateRoute: (settings) {
        onNavigate?.call();
        if (openDescriptions) return AppRouter.onGenerateRoute(settings);
        return MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink());
      },
    ),
  );
}

Map<String, Object?> _details({bool today = false, bool self = false}) => {
  'uuid': 'quarterly-audit',
  'profile_job': 'profile-job',
  'last_audit_date': today ? CustomFunctions.apiDateString() : '2000-01-01',
  'profile': {'uuid': self ? 'reviewer' : 'member', 'name': 'Member', 'onboarded': true},
  'job': {'uuid': 'seat', 'title': 'Operator'},
  'audits': [
    {
      'date': '2000-01-01',
      'audit_details': {'great': 1},
    },
  ],
};
