import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/auth_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  late Future<http.Response> Function(http.Request) respond;
  // ApiCallExecutor owns one client, so keep the mock alive across this suite.
  final client = MockClient((request) => respond(request));
  tearDownAll(client.close);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await _signIn('original');
    ApiCallExecutor.clearGetCache();
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
  });

  Future<void> runWithNavigator(
    WidgetTester tester,
    Future<void> Function(_LoginObserver observer) body,
  ) => http.runWithClient(() async {
    final observer = _LoginObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        navigatorObservers: [observer],
        initialRoute: '/lms',
        routes: {
          '/': (_) => const Scaffold(body: Text('LMS')),
          '/lms': (_) => const Scaffold(body: Text('LMS')),
          AppRouter.login: (_) => const Scaffold(body: Text('Login')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await body(observer);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, () => client);

  for (final refreshStatus in [400, 401]) {
    testWidgets(
      'concurrent and delayed 401s open Login once after refresh $refreshStatus',
      (tester) async {
        final refresh = Completer<http.Response>();
        final lateResponse = Completer<http.Response>();
        var refreshCalls = 0;
        respond = (request) async {
          if (_isRefresh(request)) {
            refreshCalls++;
            return refresh.future;
          }
          if (request.url.path.endsWith('/late/')) return lateResponse.future;
          return http.Response('{}', 401);
        };
        await runWithNavigator(tester, (observer) async {
          final results = Future.wait([
            _expectStatus(_get('lessons/'), refreshStatus),
            _expectStatus(_get('profile/'), refreshStatus),
            _expectStatus(_get('late/'), 401),
          ]);
          await tester.pump();
          expect(refreshCalls, 1);
          refresh.complete(http.Response('{}', refreshStatus));
          await tester.pumpAndSettle();
          expect(observer.loginPushes, 1);
          expect(AppPreference.getAuthToken(), isEmpty);
          expect(AppPreference.getRefreshToken(), isEmpty);
          expect(AppManager.instance.currentUser, isNull);
          lateResponse.complete(http.Response('{}', 401));
          await tester.pumpAndSettle();
          await results;
          await _expectStatus(_get('another-background-request/'), 401);
          await tester.pumpAndSettle();
          expect(refreshCalls, 1);
          expect(observer.loginPushes, 1);
          expect(find.text('Login'), findsOneWidget);
        });
      },
    );
  }

  testWidgets(
    'one successful refresh retries concurrent and late requests with the new token',
    (tester) async {
      final refresh = Completer<http.Response>();
      final lateResponse = Completer<http.Response>();
      var refreshCalls = 0;
      final retryTokens = <String>[];
      respond = (request) async {
        if (_isRefresh(request)) {
          refreshCalls++;
          return refresh.future;
        }
        final token = request.headers['authorization'];
        if (token == 'Bearer rotated-access') {
          retryTokens.add(token!);
          return http.Response('{"ok":true}', 200);
        }
        if (request.url.path.endsWith('/late/')) return lateResponse.future;
        return http.Response('{}', 401);
      };
      await runWithNavigator(tester, (observer) async {
        final version = AppPreference.sessionVersion;
        final results = Future.wait([
          _get('lessons/'),
          _get('profile/'),
          _get('late/'),
        ]);
        await tester.pump();
        expect(refreshCalls, 1);
        refresh.complete(_tokens('rotated'));
        await tester.pumpAndSettle();
        lateResponse.complete(http.Response('{}', 401));
        await tester.pumpAndSettle();
        expect(await results, everyElement({'ok': true}));
        expect(refreshCalls, 1);
        expect(retryTokens, hasLength(3));
        expect(AppPreference.getAuthToken(), 'rotated-access');
        expect(AppPreference.getRefreshToken(), 'rotated-refresh');
        expect(AppPreference.sessionVersion, version);
        expect(observer.loginPushes, 0);
      });
    },
  );

  testWidgets(
    'a temporary refresh failure allows a later attempt without logging out',
    (tester) async {
      var refreshCalls = 0;
      respond = (request) async {
        if (_isRefresh(request)) {
          refreshCalls++;
          return refreshCalls == 1
              ? http.Response('{}', 503)
              : _tokens('rotated');
        }
        return http.Response(
          '{}',
          request.headers['authorization'] == 'Bearer rotated-access'
              ? 200
              : 401,
        );
      };
      await runWithNavigator(tester, (observer) async {
        await _expectStatus(_get('lessons/'), 503);
        expect(AppPreference.getRefreshToken(), 'original-refresh');
        await _get('lessons/');
        expect(refreshCalls, 2);
        expect(observer.loginPushes, 0);
      });
    },
  );

  for (final refreshStatus in [200, 401]) {
    testWidgets(
      'old refresh $refreshStatus cannot replace or log out a newer login',
      (tester) async {
        final refresh = Completer<http.Response>();
        var refreshCalls = 0;
        respond = (request) async {
          if (_isRefresh(request)) {
            refreshCalls++;
            return refresh.future;
          }
          return http.Response('{}', 401);
        };
        await runWithNavigator(tester, (observer) async {
          final oldRequest = _expectStatus(_get('lessons/'), 401);
          await tester.pump();
          await _signIn('new-session');
          refresh.complete(
            refreshStatus == 200
                ? _tokens('obsolete')
                : http.Response('{}', 401),
          );
          await tester.pumpAndSettle();
          await oldRequest;
          expect(refreshCalls, 1);
          expect(AppPreference.getAuthToken(), 'new-session-access');
          expect(AppPreference.getRefreshToken(), 'new-session-refresh');
          expect(AppManager.instance.currentUser?.uuid, 'new-session');
          expect(observer.loginPushes, 0);
        });
      },
    );
  }

  testWidgets('a delayed API 401 cannot refresh or log out a newer login', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var refreshCalls = 0;
    respond = (request) async {
      if (_isRefresh(request)) refreshCalls++;
      return response.future;
    };
    await runWithNavigator(tester, (observer) async {
      final oldRequest = _expectStatus(_get('late/'), 401);
      await tester.pump();
      await _signIn('new-session');
      response.complete(http.Response('{}', 401));
      await tester.pumpAndSettle();
      await oldRequest;
      expect(refreshCalls, 0);
      expect(observer.loginPushes, 0);
      expect(AppPreference.getAuthToken(), 'new-session-access');
    });
  });

  testWidgets('each newly signed-in session can expire once', (tester) async {
    var refreshCalls = 0;
    respond = (request) async {
      if (_isRefresh(request)) refreshCalls++;
      return http.Response('{}', 401);
    };
    await runWithNavigator(tester, (observer) async {
      await _expectStatus(_get('lessons/'), 401);
      await tester.pumpAndSettle();
      expect(observer.loginPushes, 1);
      await _signIn('new-session');
      AppRouter.navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/lms',
        (_) => false,
      );
      await tester.pumpAndSettle();
      await _expectStatus(_get('lessons/'), 401);
      await tester.pumpAndSettle();
      expect(refreshCalls, 2);
      expect(observer.loginPushes, 2);
    });
  });

  testWidgets('missing refresh credentials redirect only once', (tester) async {
    await AppPreference.clearRefreshToken();
    var refreshCalls = 0;
    respond = (request) async {
      if (_isRefresh(request)) refreshCalls++;
      return http.Response('{}', 401);
    };
    await runWithNavigator(tester, (observer) async {
      await Future.wait([
        _expectStatus(_get('lessons/'), 401),
        _expectStatus(_get('profile/'), 401),
      ]);
      await tester.pumpAndSettle();
      expect(refreshCalls, 0);
      expect(observer.loginPushes, 1);
    });
  });

  testWidgets(
    'manual logout is shared and an outstanding refresh cannot restore the session',
    (tester) async {
      final refresh = Completer<http.Response>();
      respond = (request) async =>
          _isRefresh(request) ? refresh.future : http.Response('{}', 401);
      await runWithNavigator(tester, (observer) async {
        final oldRequest = _expectStatus(_get('lessons/'), 401);
        await tester.pump();
        await Future.wait([AuthController.logout(), AuthController.logout()]);
        await tester.pumpAndSettle();
        refresh.complete(_tokens('obsolete'));
        await tester.pumpAndSettle();
        await oldRequest;
        await AuthController.logout();
        expect(observer.loginPushes, 1);
        expect(AppPreference.getAuthToken(), isEmpty);
        expect(AppPreference.getRefreshToken(), isEmpty);
      });
    },
  );
}

Future<void> _signIn(String session) async {
  await AppPreference.clearUserSession();
  await AppPreference.setAuthToken('$session-access');
  await AppPreference.setRefreshToken('$session-refresh');
  AppManager.instance.updateCurrentUser(User(uuid: session));
}

Future<Object?> _get(String endpoint) =>
    const ApiCallExecutor().processApi<Object?>(
      apiCallType: ApiCallType.get,
      endpoint: endpoint,
      decoder: (json) => json,
    );

Future<void> _expectStatus(Future<Object?> request, int status) => expectLater(
  request,
  throwsA(
    isA<ApiError>().having((error) => error.statusCode, 'statusCode', status),
  ),
);

bool _isRefresh(http.Request request) =>
    request.url.path.endsWith('/${ApiEndPoints.refreshToken}');

http.Response _tokens(String prefix) => http.Response(
  jsonEncode({'access': '$prefix-access', 'refresh': '$prefix-refresh'}),
  200,
);

class _LoginObserver extends NavigatorObserver {
  int loginPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == AppRouter.login) loginPushes++;
  }
}
