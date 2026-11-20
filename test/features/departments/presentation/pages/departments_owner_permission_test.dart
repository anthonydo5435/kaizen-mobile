import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/departments/presentation/pages/department_audit_stats_screen.dart';
import 'package:sparrowkaizen/features/departments/presentation/pages/departments_screen.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  final updates = <http.Request>[];
  final statsRequests = <http.Request>[];
  const statsPath = '/department/department/audit_stats/';
  Completer<void>? statsGate;
  http.Response? statsResponse;
  var hasScopedDepartments = false;
  var organizationType = 'child';
  var departmentName = 'Operations';

  // The API executor retains its client; reuse one mock with fresh fixtures.
  final client = MockClient((request) async {
    final path = request.url.path;
    Object response;
    if (path.endsWith(ApiEndPoints.organizations)) {
      response = [
        {'uuid': 'org', 'name': 'Organisation', 'type': organizationType},
      ];
    } else if (request.method == 'PUT' &&
        path.endsWith(ApiEndPoints.departmentDetail('department'))) {
      updates.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      departmentName = body['name'] as String;
      response = <String, Object?>{};
    } else if (path.endsWith(ApiEndPoints.allDepartments)) {
      final departments = [
        {'uuid': 'department', 'name': departmentName, 'color_hex': '#7654AB'},
        {'uuid': 'privileged', 'name': 'Privileged', 'color_hex': '#7654AB'},
        if (hasScopedDepartments)
          {
            'uuid': 'other-department',
            'name': 'Finance',
            'color_hex': '#7654AB',
          },
      ];
      response = hasScopedDepartments
          ? {
              'all': departments,
              'subordinate_departments': [departments.first],
            }
          : departments;
    } else if (path.endsWith(statsPath)) {
      statsRequests.add(request);
      await statsGate?.future;
      if (statsResponse != null) return statsResponse!;
      response = {
        'score': 0.2,
        'confidence_level': 75,
        'job_stats': [
          {
            'uuid': 'back-desk-lead',
            'name': 'Back Desk Lead',
            'total_members': 1,
            'score': 0.9,
            'confidence_level': 0,
          },
          {
            'uuid': 'insurance-ar',
            'name': 'Insurance A/R',
            'total_members': 2,
            'score': 0.0,
            'confidence_level': 68.5,
          },
        ],
      };
    } else {
      throw StateError('Unexpected request: ${request.method} $path');
    }
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    updates.clear();
    statsRequests.clear();
    statsGate = null;
    statsResponse = null;
    hasScopedDepartments = false;
    organizationType = 'child';
    departmentName = 'Operations';
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
  });
  tearDown(AppManager.instance.resetSessionState);

  Future<void> loadScreen(WidgetTester tester, User user) async {
    AppManager.instance.updateCurrentUser(user);
    await AppManager.instance.fetchOrganizations(requireSuccess: true);
    await tester.pumpWidget(const MaterialApp(home: DepartmentsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'department tap loads audit stats and lays out equal summary cards',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      statsGate = Completer<void>();
      statsResponse = http.Response(
        '{"detail":"No Department matches the given query."}',
        404,
      );

      await http.runWithClient(() async {
        await loadScreen(tester, User(organizationUuid: 'org'));
        await tester.tap(find.text('Operations'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(statsRequests.single.method, 'GET');
        expect(statsRequests.single.url.path, endsWith(statsPath));
        expect(find.widgetWithText(AppBar, 'Operations'), findsOneWidget);
        expect(find.byType(FastCircularProgressIndicator), findsOneWidget);

        statsGate!.complete();
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.departmentAuditStatsLoadError),
          findsOneWidget,
        );
        statsResponse = null;
        await tester.tap(find.text(AppStrings.departmentsRetryAction));
        await tester.pumpAndSettle();

        expect(statsRequests, hasLength(2));
        expect(tester.getRect(find.byType(ListView)).bottom, 900);
        expect(find.text(AppStrings.homeSeatProfiles), findsOneWidget);
        expect(find.text('0.2'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        expect(find.text('Back Desk Lead'), findsOneWidget);
        expect(find.text('1 Member'), findsOneWidget);
        expect(find.text('0.9'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);

        final summary = find
            .descendant(
              of: find.byType(DepartmentAuditStatsScreen),
              matching: find.byType(IntrinsicHeight),
            )
            .first;
        final metrics = find.descendant(
          of: summary,
          matching: find.byType(DecoratedBox),
        );
        expect(metrics, findsNWidgets(2));
        expect(tester.getSize(metrics.first), tester.getSize(metrics.last));
        expect(
          tester.getTopLeft(metrics.first).dy,
          tester.getTopLeft(metrics.last).dy,
        );

        final firstSeat = tester.getRect(
          find.byKey(const ValueKey('back-desk-lead')),
        );
        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        final initialOffset = position.pixels;
        final secondSeatFinder = find.byKey(const ValueKey('insurance-ar'));
        await tester.scrollUntilVisible(
          secondSeatFinder,
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final secondSeat = tester.getRect(secondSeatFinder);
        expect(find.text('Insurance A/R'), findsOneWidget);
        expect(find.text('2 Members'), findsOneWidget);
        expect(find.text('0.0'), findsOneWidget);
        expect(find.text('68.5%'), findsOneWidget);
        expect(firstSeat.width, 304);
        expect(secondSeat.left, firstSeat.left);
        expect(
          secondSeat.top + position.pixels,
          greaterThan(firstSeat.bottom + initialOffset),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Operations'));
        await tester.pumpAndSettle();
        expect(statsRequests, hasLength(3));
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  for (final statusCode in [200, 404]) {
    testWidgets('sandbox department shows empty stats from HTTP $statusCode', (
      tester,
    ) async {
      statsResponse = http.Response(
        '{"score":0.0,"confidence_level":0,"job_stats":[]}',
        statusCode,
      );
      organizationType = 'sandbox';
      await http.runWithClient(() async {
        await loadScreen(tester, User(organizationUuid: 'org'));
        expect(AppPreference.getUseParentApiEndpoints(), isTrue);
        final row = find.widgetWithText(InkWell, 'Operations');
        final ink = tester.widget<InkWell>(row);
        expect(ink.splashFactory, NoSplash.splashFactory);
        expect(ink.highlightColor, Colors.transparent);

        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(statsRequests, hasLength(1));
        expect(statsRequests.single.url.path, '/api/v1$statsPath');
        expect(find.text(AppStrings.departmentAuditScore), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text(AppStrings.confidenceLevel), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
        final emptyMessage = find.text(AppStrings.departmentAuditNoJobStats);
        expect(emptyMessage, findsOneWidget);
        expect(find.text(AppStrings.homeSeatProfiles), findsNothing);
        final viewport = tester.getRect(find.byType(CustomScrollView));
        final summary = tester.getRect(find.byType(IntrinsicHeight));
        final messageCenter = tester.getCenter(emptyMessage);
        expect(messageCenter.dx, closeTo(viewport.center.dx, 1));
        expect(messageCenter.dy, greaterThan(summary.bottom));
        expect(
          messageCenter.dy,
          lessThan((summary.bottom + viewport.bottom) / 2),
        );
        expect(
          find.text(AppStrings.departmentAuditStatsLoadError),
          findsNothing,
        );
        expect(
          find.text(AppStrings.auditGeneralSeatOverallScore),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets('stats use the scoped departments from the directory response', (
    tester,
  ) async {
    hasScopedDepartments = true;
    statsResponse = http.Response(
      '{"score":0.0,"confidence_level":0,"job_stats":[]}',
      200,
    );
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(organizationUuid: 'org', roles: ['team_lead']),
      );

      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.departmentAuditStatsUnavailable),
        findsOneWidget,
      );
      expect(find.byType(DepartmentAuditStatsScreen), findsNothing);
      expect(statsRequests, isEmpty);

      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(statsRequests.single.url.path, '/api/v1$statsPath');
      expect(find.text(AppStrings.departmentAuditNoJobStats), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('owner can edit and save a child department', (tester) async {
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(
          isOwner: true,
          organizationUuid: 'org',
          roles: const ['team_member'],
        ),
      );
      expect(AppManager.instance.isCurrentOrganizationChild, isTrue);
      expect(AppManager.instance.canCurrentOrganizationModifyContent, isTrue);

      await tester.drag(find.text('Operations'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(statsRequests, isEmpty);
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.departmentsEditTitle), findsOneWidget);

      final nameField = find.widgetWithText(TextField, 'Operations');
      await tester.enterText(nameField, 'Updated Operations');
      final saveButton = find.text(AppStrings.seatProfileSaveAction);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(updates, hasLength(1));
      expect(jsonDecode(updates.single.body), {
        'name': 'Updated Operations',
        'color_hex': '#7654AB',
      });
      expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
      expect(find.text('Updated Operations'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('Privileged stays locked for an owner in a child organisation', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await loadScreen(tester, User(isOwner: true, organizationUuid: 'org'));
      await tester.drag(find.text('Privileged'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
      expect(updates, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets(
    'an owner role without the flag retains normal department editing',
    (tester) async {
      await http.runWithClient(() async {
        await loadScreen(
          tester,
          User(isOwner: false, organizationUuid: 'org', roles: const ['owner']),
        );
        await tester.drag(find.text('Operations'), const Offset(-150, 0));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
        expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
        expect(updates, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets('non-owner department editing remains available in a parent', (
    tester,
  ) async {
    organizationType = 'parent';
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(
          isOwner: false,
          organizationUuid: 'org',
          roles: const ['team_member'],
        ),
      );
      await tester.drag(find.text('Operations'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
