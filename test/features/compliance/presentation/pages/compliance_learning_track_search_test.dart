import 'dart:async';
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
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/core/widgets/main_navigation_shell.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_tab_type.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/compliance_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_learning_track_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/learning_track_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) respondToSearch;
  final client = MockClient((request) async {
    requests.add(request);
    if (!request.url.queryParameters.containsKey('name')) {
      return _trackResponse('Original Track');
    }
    return respondToSearch(request);
  });

  setUp(() async {
    requests.clear();
    respondToSearch = (_) async => _trackResponse('Server Result');
    ApiCallExecutor.clearGetCache();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'member', organizationUuid: 'org');
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);
  tearDownAll(client.close);

  testWidgets('debounces typing and sends the name search to the API', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      final field = find.byType(TextField);
      expect(find.text('Original Track'), findsOneWidget);
      expect(find.byTooltip(AppStrings.clearSearch), findsNothing);

      await tester.enterText(field, 'M');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'Ma');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'Man');
      await tester.pump(const Duration(milliseconds: 399));
      expect(requests, hasLength(1));
      expect(find.byTooltip(AppStrings.clearSearch), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(
        requests.last.url.path,
        endsWith('/learning_compliance/track_assignments/my_tracks/'),
      );
      expect(requests.last.url.queryParameters, {
        'page': '1',
        'name': 'Man',
        'page_size': '10',
      });
      expect(find.text('Server Result'), findsOneWidget);
      expect(find.text('Original Track'), findsNothing);

      await tester.enterText(field, ' Man & Safety ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['name'], 'Man & Safety');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('typing a repeated search term makes a fresh API request', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      final field = find.byType(TextField);
      await tester.enterText(field, 'Man');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Server Result'), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      respondToSearch = (_) async => _trackResponse('Fresh Result');
      await tester.enterText(field, 'Man');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        requests.where(
          (request) => request.url.queryParameters['name'] == 'Man',
        ),
        hasLength(2),
      );
      expect(find.text('Fresh Result'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('LTC home-tab search survives keyboard layout changes', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester, useHomeNavigation: true);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      final field = find.byType(TextField);
      final controller = tester
          .element(field)
          .read<ComplianceLearningTrackController>();
      await tester.enterText(field, 'Man');
      await tester.pump(const Duration(milliseconds: 200));
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(
        tester.element(field).read<ComplianceLearningTrackController>(),
        same(controller),
      );
      expect(requests.last.url.queryParameters['name'], 'Man');
      expect(find.text('Server Result'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('clear cancels a pending debounce and restores the listing', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Man');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(find.text('Original Track'), findsOneWidget);
      expect(find.byTooltip(AppStrings.clearSearch), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('clear remains available and ignores an in-flight result', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    respondToSearch = (_) => response.future;
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Man');
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, hasLength(2));
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.clearSearch).hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('Original Track'), findsOneWidget);
      response.complete(_trackResponse('Late Result'));
      await tester.pumpAndSettle();
      expect(find.text('Original Track'), findsOneWidget);
      expect(find.text('Late Result'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('a changed query rejects old responses during its debounce', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    respondToSearch = (request) =>
        request.url.queryParameters['name'] == 'Alpha'
        ? oldResponse.future
        : Future.value(_trackResponse('Beta Result'));
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pump(const Duration(milliseconds: 100));
      oldResponse.complete(_trackResponse('Alpha Result'));
      await tester.pump();
      expect(find.text('Alpha Result'), findsNothing);
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.url.queryParameters['name']), [
        null,
        'Alpha',
        'Beta',
      ]);
      expect(find.text('Beta Result'), findsOneWidget);
      expect(find.text('Alpha Result'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('search failures show feedback and clear recovers the list', (
    tester,
  ) async {
    respondToSearch = (_) async => http.Response('{}', 500);
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Man');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.complianceTrackSearchFailed), findsOneWidget);
      expect(find.text(AppStrings.complianceNoTracksFound), findsNothing);
      expect(find.byType(FastCircularProgressIndicator), findsNothing);

      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('Original Track'), findsOneWidget);
      expect(find.text(AppStrings.complianceTrackSearchFailed), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('refresh keeps the active search and seat-profile filter', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      final field = find.byType(TextField);
      final controller = tester
          .element(field)
          .read<ComplianceLearningTrackController>();
      controller.updateSelectedSeatProfiles({'QA'});
      await tester.enterText(field, 'Man');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(LearningTrackCard), findsOneWidget);

      respondToSearch = (_) async => _trackResponse('Refreshed Result');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (request) => request.url.queryParameters['name'] == 'Man',
        ),
        hasLength(2),
      );
      expect(find.text('Refreshed Result'), findsOneWidget);
      expect(controller.selectedSeatProfiles, {'QA'});
      expect(controller.searchController.text, 'Man');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets(
    'leaving the screen cancels debounce and ignores late responses',
    (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester);
        await tester.enterText(find.byType(TextField), 'Man');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 400));
        expect(requests, hasLength(1));

        final response = Completer<http.Response>();
        respondToSearch = (_) => response.future;
        await _pumpScreen(tester);
        await tester.enterText(find.byType(TextField), 'Man');
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          requests.where(
            (request) => request.url.queryParameters['name'] == 'Man',
          ),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        response.complete(_trackResponse('Late Result'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool useHomeNavigation = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppManager>.value(
      value: AppManager.instance,
      child: useHomeNavigation
          ? MaterialApp(
              onGenerateRoute: AppRouter.onGenerateRoute,
              onGenerateInitialRoutes: (_) => [
                AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRouter.learningTracks),
                ),
              ],
            )
          : const MaterialApp(
              home: ComplianceScreen(module: ComplianceTabType.learningTrack),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response _trackResponse(String name) => http.Response(
  jsonEncode({
    'count': 1,
    'next': null,
    'previous': null,
    'results': [
      {
        'uuid': name,
        'name': name,
        'job': 'QA',
        'status': 'pending',
        'completion_percentage': 0,
      },
    ],
  }),
  200,
);
