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
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_details_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  var response = _details();
  final requests = <http.Request>[];
  // ApiCallExecutor keeps one HTTP client, so its mock reads the current fixture.
  final client = MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    response = _details();
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

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({required int year, required int quarter, VoidCallback? onNavigate}) {
  return ChangeNotifierProvider<AppManager>.value(
    value: AppManager.instance,
    child: MaterialApp(
      home: CheckInDetailsScreen(profileJobId: 'profile-job', year: year, quarter: quarter),
      onGenerateRoute: (_) {
        onNavigate?.call();
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
