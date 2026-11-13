import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_descriptions_list_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_details_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_member_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  final requests = <http.Request>[];
  var saved = false;
  var rating = 1;
  final today = CustomFunctions.apiDateString();
  final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object response;
    if (path.endsWith(ApiEndPoints.quarterlyAuditDetails('profile-job'))) {
      response = {
        ..._profile,
        'last_audit_date': saved ? today : '2000-01-01',
        'audits': [
          {
            'date': today,
            'audit_details': {'great': rating},
          },
        ],
      };
    } else if (path.endsWith(
      ApiEndPoints.quarterlyAuditDetail('quarterly-audit'),
    )) {
      response = {
        ..._profile,
        'categories': [
          {'uuid': 'category', 'category_title': 'Responsibilities'},
        ],
        'descriptions': [
          {
            'uuid': 'description',
            'category': 'category',
            'description': 'Daily task',
            'audit_details': {
              'great': rating,
              'has_audit': true,
              'audit_uuid': 'audit-description',
            },
          },
        ],
      };
    } else if (request.method == 'PATCH' &&
        path.endsWith(ApiEndPoints.auditDescription('audit-description'))) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      rating = (body['audit'] as Map)['great'] as int;
      saved = true;
      response = {
        'uuid': 'audit-description',
        'audit': List.filled(rating, 'great'),
      };
    } else if (path.endsWith(ApiEndPoints.quarterlyAudit) ||
        path.endsWith(ApiEndPoints.quarterlyAuditMyAudits)) {
      response = {
        'count': 1,
        'current': 1,
        'results': [
          {
            ..._profile,
            'last_audit_date': saved ? today : '2000-01-01',
            'overall_score': saved ? 90 : 10,
            'confidence_level': saved ? 80 : 50,
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
    saved = false;
    rating = 1;
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
  });
  tearDown(AppManager.instance.resetSessionState);

  for (final isOwner in [true, false]) {
    testWidgets(
      'saving a description refreshes the main card after returning (owner: $isOwner)',
      (tester) async {
        _setViewport(tester);
        await _saveUser(isOwner: isOwner);
        await http.runWithClient(() async {
          await tester.pumpWidget(_screen());
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CheckInMemberCard>(find.byType(CheckInMemberCard))
                .member
                .overallScore,
            10,
          );

          final controller = tester
              .element(find.byType(CheckInMemberCard))
              .read<CheckInController>();
          controller.updateSearchQuery('Member');
          await tester.pump(const Duration(milliseconds: 450));
          await tester.pumpAndSettle();

          await _tap(
            tester,
            find.descendant(
              of: find.byType(CheckInMemberCard),
              matching: find.text(AppStrings.checkInTitle),
            ),
          );
          expect(find.byType(CheckInDetailsScreen), findsOneWidget);
          await _tap(tester, find.text(AppStrings.continueAction));
          expect(find.byType(CheckInDescriptionsListScreen), findsOneWidget);
          await _tap(tester, find.text('1'));
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();
          expect(rating, 2);

          Navigator.of(
            tester.element(find.byType(CheckInDescriptionsListScreen)),
          ).pop();
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(CheckInDetailsScreen))).pop();
          await tester.pumpAndSettle();

          final member = tester
              .widget<CheckInMemberCard>(find.byType(CheckInMemberCard))
              .member;
          expect(member.overallScore, 90);
          expect(member.confidenceLevel, 80);
          expect(member.lastAuditLabel, today);
          expect(controller.state.searchQuery, 'Member');

          // Clearing the search must not restore a summary cached before the save.
          controller.updateSearchQuery('');
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CheckInMemberCard>(find.byType(CheckInMemberCard))
                .member
                .overallScore,
            90,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  testWidgets(
    'return refresh bypasses cached My Check-ins and retains search and period',
    (tester) async {
      _setViewport(tester);
      await _saveUser(isOwner: false);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          _screen(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    saved = true;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Return to listing'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final controller = tester
            .element(find.byType(CheckInMemberCard))
            .read<CheckInController>();
        final period = '${controller.selectedAuditYear - 1} - Q2';
        await controller.applyFilters(yearQuarter: period);
        await controller.selectStatus(AuditMemberStatus.deactivated);
        controller.updateSearchQuery('Member');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();
        final previousRequests = requests.length;

        await _tap(
          tester,
          find.descendant(
            of: find.byType(CheckInMemberCard),
            matching: find.text(AppStrings.checkInTitle),
          ),
        );
        await _tap(tester, find.text('Return to listing'));

        expect(requests, hasLength(previousRequests + 1));
        final refreshed = requests.last;
        expect(
          refreshed.url.path,
          endsWith(ApiEndPoints.quarterlyAuditMyAudits),
        );
        expect(refreshed.url.queryParameters['search'], 'Member');
        expect(
          refreshed.url.queryParameters['year'],
          '${controller.selectedAuditYear}',
        );
        expect(refreshed.url.queryParameters['quarter'], '2');
        expect(controller.state.selectedStatus, AuditMemberStatus.deactivated);
        expect(controller.state.selectedYearQuarter, period);
        expect(controller.state.searchQuery, 'Member');
        expect(
          tester
              .widget<CheckInMemberCard>(find.byType(CheckInMemberCard))
              .member
              .overallScore,
          90,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

const _profile = {
  'uuid': 'quarterly-audit',
  'profile_job': 'profile-job',
  'profile': {'uuid': 'member', 'name': 'Member', 'onboarded': true},
  'job': {'uuid': 'seat', 'title': 'Operator'},
};

Future<void> _saveUser({required bool isOwner}) async {
  final user = User(uuid: 'reviewer', isOwner: isOwner, roles: ['team_lead']);
  await AppPreference.saveUser(user);
  AppManager.instance.updateCurrentUser(user);
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({RouteFactory? onGenerateRoute}) =>
    ChangeNotifierProvider<AppManager>.value(
      value: AppManager.instance,
      child: MaterialApp(
        home: const CheckInScreen(),
        onGenerateRoute: onGenerateRoute ?? AppRouter.onGenerateRoute,
      ),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
