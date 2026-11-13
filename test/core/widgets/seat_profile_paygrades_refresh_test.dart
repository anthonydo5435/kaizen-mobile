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
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/paygrades_screen.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/providers/paygrades_controller.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_controller.dart';

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) respond;
  final client = MockClient((request) {
    if (request.url.path.contains('/department/')) {
      return Future.value(
        http.Response(
          jsonEncode([
            {'uuid': 'operations', 'name': 'Operations'},
          ]),
          200,
        ),
      );
    }
    requests.add(request);
    return respond(request);
  });

  setUp(() async {
    requests.clear();
    respond = (_) async => _response('Before');
    ApiCallExecutor.clearGetCache();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'owner', isOwner: true, organizationUuid: 'org');
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);
  tearDownAll(client.close);

  for (final paygrades in [false, true]) {
    final name = paygrades ? 'Paygrades' : 'Seat Profile';

    testWidgets(
      '$name refresh fetches fresh data and keeps search and filter',
      (tester) async {
        await http.runWithClient(() async {
          await _pumpScreen(tester, paygrades: paygrades);
          final field = find.byType(TextField);
          final context = tester.element(field);
          if (paygrades) {
            await context.read<PaygradesController>().selectDepartment(
              'operations',
            );
          } else {
            await context.read<SeatProfileController>().selectDepartment(
              'operations',
            );
          }
          await tester.pumpAndSettle();
          await tester.enterText(field, 'Before');
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();

          final previousRequest = requests.last.url;
          final requestCount = requests.length;
          final response = Completer<http.Response>();
          respond = (_) => response.future;
          expect(
            tester
                .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                .color,
            AppColors.purple2,
          );

          // Pulling over the search area also refreshes a one-card listing.
          await tester.dragFrom(tester.getCenter(field), const Offset(0, 300));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(requests.length, requestCount + 1);
          expect(requests.last.url, previousRequest);
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(find.byType(FastCircularProgressIndicator), findsNothing);
          expect(find.text('Before'), findsWidgets);

          response.complete(_response('After'));
          await tester.pumpAndSettle();
          expect(find.text('After'), findsOneWidget);
          expect(tester.widget<TextField>(field).controller!.text, 'Before');
          expect(requests.last.url.queryParameters['department'], 'operations');
          expect(requests.last.url.queryParameters['title'], 'Before');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );

    testWidgets('$name empty listing can pull refresh', (tester) async {
      respond = (_) async => _response(null);
      await http.runWithClient(() async {
        await _pumpScreen(tester, paygrades: paygrades);
        final emptyMessage = paygrades
            ? AppStrings.paygradesNoItemsFound
            : AppStrings.seatProfileNoItemsFound;
        expect(find.text(emptyMessage), findsOneWidget);
        final requestCount = requests.length;
        final response = Completer<http.Response>();
        respond = (_) => response.future;
        await _pullRefresh(tester);
        expect(requests.length, requestCount + 1);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        expect(find.byType(FastCircularProgressIndicator), findsNothing);
        response.complete(_response('After'));
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });

    testWidgets('$name failed refresh retains cards and permits another pull', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, paygrades: paygrades);
        respond = (_) async => http.Response('{}', 400);
        await _pullRefresh(tester);
        await tester.pumpAndSettle();
        expect(find.text('Before'), findsOneWidget);
        respond = (_) async => _response('After');
        await _pullRefresh(tester);
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });

    testWidgets('$name refresh discards a previous pagination response', (
      tester,
    ) async {
      respond = (_) async => _response('Before', hasNextPage: true);
      await http.runWithClient(() async {
        await _pumpScreen(tester, paygrades: paygrades);
        final context = tester.element(find.byType(TextField));
        final nextPage = Completer<http.Response>();
        respond = (_) => nextPage.future;
        final pageOperation = paygrades
            ? context.read<PaygradesController>().loadNextPage()
            : context.read<SeatProfileController>().loadNextPage();
        await tester.pump();
        expect(requests.last.url.queryParameters['page'], '2');
        respond = (_) async => _response('After');
        await _pullRefresh(tester);
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests.last.url.queryParameters['page'], '1');
        nextPage.complete(_response('Old page'));
        await pageOperation;
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(find.text('Old page'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }
}

Future<void> _pumpScreen(WidgetTester tester, {required bool paygrades}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: paygrades ? const PaygradesScreen() : const SeatProfileScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pullRefresh(WidgetTester tester) async {
  final scrolling = find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.drag(scrolling, const Offset(0, 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

http.Response _response(String? title, {bool hasNextPage = false}) {
  return http.Response(
    jsonEncode({
      'count': title == null ? 0 : 1,
      'current': 1,
      'next': hasNextPage ? 'next' : null,
      'results': title == null
          ? []
          : [
              {
                'uuid': 'seat',
                'title': title,
                'department': 'Operations',
                'total_categories': 2,
                'total_descriptions': 3,
              },
            ],
    }),
    200,
  );
}
