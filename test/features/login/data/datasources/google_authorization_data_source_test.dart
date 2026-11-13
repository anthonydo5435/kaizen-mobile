import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/login/data/datasources/google_authorization_data_source.dart';
import 'package:sparrowkaizen/features/login/domain/entities/google_authorization.dart';
import 'package:sparrowkaizen/features/login/data/datasources/google_oauth_configuration.dart';

const _testClientId = 'test-web-client.apps.googleusercontent.com';
const _productionWebClientId =
    '273718420607-q4dcl17i18nql3s6n7hr31o7m5rvsjkf.apps.googleusercontent.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OAuth configuration', () {
    test('default browser request uses the configured Web client and callback together', () async {
      final harness = _Harness(clientId: null);
      addTearDown(harness.close);
      final pending = harness.source.authorize();
      final request = await harness.firstRequest.future;
      expect(request.queryParameters['client_id'], GoogleOAuthConfiguration.current.clientId);
      expect(request.queryParameters['redirect_uri'], GoogleOAuthConfiguration.current.redirectUri);
      expect(request.path, '/o/oauth2/v2/auth');
      expect(request.queryParameters['state'], isNot('[REDACTED]'));
      harness.callbacks.add(harness.callback());
      expect((await pending)!.code, 'test-code');
    });

    test('development backend selects its Web client and callback together', () {
      final config = GoogleOAuthConfiguration.forBackend('https://dev-api.kaizenteams.ai');
      expect(
        config.clientId,
        '273718420607-sma08mj14celj9c4dshthl3nbeqttb12.apps.googleusercontent.com',
      );
      expect(config.redirectUri, 'https://dev.kaizenteams.ai/auth/google/callback');
      expect(config.hasMatchingCallback, isTrue);
    });

    test('production backend selects its Web client and callback together', () {
      final config = GoogleOAuthConfiguration.forBackend('https://api.kaizenteams.ai');
      expect(config.clientId, _productionWebClientId);
      expect(config.redirectUri, 'https://app.kaizenteams.ai/auth/google/callback');
      expect(config.hasMatchingCallback, isTrue);
    });

    test('explicit configuration overrides are preserved and trimmed', () async {
      final config = GoogleOAuthConfiguration.forBackend(
        'https://api.kaizenteams.ai',
        clientIdOverride: '  $_testClientId  ',
        redirectUriOverride: '  https://login.example.com/google/callback/  ',
      );
      final harness = _Harness(clientId: config.clientId, redirectUri: config.redirectUri);
      addTearDown(harness.close);
      final pending = harness.source.authorize();
      expect(harness.requests.single.queryParameters['client_id'], _testClientId);
      expect(
        harness.requests.single.queryParameters['redirect_uri'],
        'https://login.example.com/google/callback/',
      );
      harness.source.cancel();
      expect(await pending, isNull);
    });

    for (final clientId in ['', '   ']) {
      test('blank client ID ($clientId) cannot open the browser', () async {
        final harness = _Harness(clientId: clientId);
        addTearDown(harness.close);
        await expectLater(harness.source.authorize(), throwsA(_unavailableAuthorization));
        expect(harness.requests, isEmpty);
      });
    }

    for (final config in [
      GoogleOAuthConfiguration(
        clientId: GoogleOAuthConfiguration.development.clientId,
        redirectUri: GoogleOAuthConfiguration.production.redirectUri,
      ),
      GoogleOAuthConfiguration(
        clientId: GoogleOAuthConfiguration.production.clientId,
        redirectUri: GoogleOAuthConfiguration.development.redirectUri,
      ),
    ]) {
      test(
        'mixed environment credentials (${config.redirectUri}) cannot open the browser',
        () async {
          final harness = _Harness(clientId: config.clientId, redirectUri: config.redirectUri);
          addTearDown(harness.close);
          await expectLater(harness.source.authorize(), throwsA(_unavailableAuthorization));
          expect(harness.requests, isEmpty);
        },
      );
    }
  });

  test('callback diagnostics explain ignored state and preserve Google errors', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final messages = <String>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalPrint);
    final pending = harness.source.authorize();
    final expectation = expectLater(pending, throwsA(isA<GoogleAuthorizationException>()));
    harness.callbacks.add(harness.callback().replace(queryParameters: {'code': 'visible-code'}));
    harness.callbacks.add(
      harness.callback().replace(
        queryParameters: {
          'state': harness.requests.last.queryParameters['state']!,
          'error': 'invalid_request',
          'error_description': 'Redirect URI rejected',
        },
      ),
    );
    await expectation;
    final output = messages.join('\n');
    expect(output, contains('callback.received'));
    expect(output, contains('missing_duplicate_or_stale_state'));
    expect(output, contains('google.error'));
    expect(output, contains('Redirect URI rejected'));
    expect(output, contains('"code":["visible-code"]'));
    expect(output, isNot(contains(harness.requests.last.queryParameters['state']!)));
  });

  test('browser request and backend exchange use the same redirect and a fresh state', () async {
    final harness = _Harness(redirectUri: GoogleOAuthConfiguration.production.redirectUri);
    addTearDown(harness.close);
    final first = harness.source.authorize();
    final request = harness.requests.single;
    expect(request.origin, 'https://accounts.google.com');
    expect(request.queryParameters['response_type'], 'code');
    expect(request.queryParameters['scope'], 'openid email profile');
    expect(
      request.queryParameters['redirect_uri'],
      'https://app.kaizenteams.ai/auth/google/callback',
    );
    expect(request.queryParameters['redirect_uri'], harness.source.redirectUri);
    expect(request.queryParameters['state']!.length, greaterThanOrEqualTo(32));
    harness.callbacks.add(harness.callback(code: 'code+/with_underscores'));
    final result = await first;
    expect(result!.code, 'code+/with_underscores');
    expect(result.redirectUri, harness.source.redirectUri);

    final second = harness.source.authorize();
    expect(harness.requests.last.queryParameters['state'], isNot(request.queryParameters['state']));
    harness.source.cancel();
    expect(await second, isNull);
  });

  test('wrong origin, path, missing state, and stale state cannot complete login', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    var completed = false;
    final result = harness.source.authorize()..then((_) => completed = true);
    final callback = harness.callback();
    harness.callbacks.add(callback.replace(host: 'example.com'));
    harness.callbacks.add(callback.replace(scheme: 'http'));
    harness.callbacks.add(callback.replace(path: '/auth/google/callback/extra'));
    harness.callbacks.add(callback.replace(queryParameters: {'code': 'unsolicited'}));
    harness.callbacks.add(callback.replace(queryParameters: {'code': 'stale', 'state': 'old'}));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    harness.callbacks.add(callback);
    expect((await result)!.code, 'test-code');
  });

  for (final host in ['app.kaizenteams.ai', 'dev.kaizenteams.ai']) {
    test('browser Open app resumes an active Google sign-in on $host', () async {
      final harness = _Harness(redirectUri: 'https://$host/auth/google/callback');
      addTearDown(harness.close);
      final pending = harness.source.authorize();
      final callback = harness.callback(code: 'code+/with_underscores').replace(fragment: '_=_');
      harness.callbacks.add(
        Uri.parse('kaizenteams://open?url=${Uri.encodeComponent(callback.toString())}'),
      );
      final result = await pending;
      expect(result!.code, 'code+/with_underscores');
      expect(result.redirectUri, harness.source.redirectUri);
      expect(harness.requests.single.queryParameters['redirect_uri'], result.redirectUri);
    });
  }

  test('browser handoffs cannot bypass Google callback or state validation', () async {
    final harness = _Harness(redirectUri: GoogleOAuthConfiguration.production.redirectUri);
    addTearDown(harness.close);
    var completed = false;
    final pending = harness.source.authorize()..then((_) => completed = true);
    final callback = harness.callback();
    for (final uri in [
      callback.replace(host: 'example.com'),
      callback.replace(host: 'dev.kaizenteams.ai'),
      callback.replace(scheme: 'http'),
      callback.replace(path: '/auth/google/callback/extra'),
      callback.replace(queryParameters: {'code': 'unsolicited'}),
      callback.replace(queryParameters: {'code': 'stale', 'state': 'old'}),
      callback.replace(
        queryParameters: {
          'code': 'duplicate',
          'state': [callback.queryParameters['state']!, callback.queryParameters['state']!],
        },
      ),
    ]) {
      harness.callbacks.add(
        Uri.parse('kaizenteams://open?url=${Uri.encodeComponent(uri.toString())}'),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    harness.callbacks.add(callback);
    expect((await pending)!.code, 'test-code');
  });

  test(
    'valid query callbacks accept browser fragments without changing the exchanged code',
    () async {
      final harness = _Harness();
      addTearDown(harness.close);

      for (final fragment in ['', '_=_', 'code=fragment-code&state=fragment-state']) {
        final pending = harness.source.authorize();
        final callback = harness.callback(code: 'query-code');
        final responseUri = callback.replace(
          queryParameters: {
            ...callback.queryParameters,
            'iss': 'https://accounts.google.com',
            'scope': 'openid email profile',
            'authuser': '0',
            'prompt': 'none',
          },
          fragment: fragment,
        );
        expect(responseUri.hasFragment, isTrue);
        harness.callbacks.add(responseUri);

        final authorization = await pending.timeout(const Duration(seconds: 1));
        expect(authorization!.code, 'query-code');
        expect(authorization.redirectUri, harness.source.redirectUri);
        expect(Uri.parse(authorization.redirectUri).hasFragment, isFalse);
      }
    },
  );

  test('fragments cannot supply missing state or override a mismatched callback', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    var completed = false;
    final pending = harness.source.authorize()..then((_) => completed = true);
    final callback = harness.callback();
    final fragmentCredentials = callback.query;

    harness.callbacks.add(callback.replace(host: 'example.com', fragment: '_=_'));
    harness.callbacks.add(callback.replace(scheme: 'http', fragment: '_=_'));
    harness.callbacks.add(callback.replace(port: 444, fragment: '_=_'));
    harness.callbacks.add(callback.replace(path: '/auth/google/other', fragment: '_=_'));
    harness.callbacks.add(callback.replace(userInfo: 'untrusted', fragment: '_=_'));
    harness.callbacks.add(
      callback.replace(queryParameters: {'code': 'query-code'}, fragment: fragmentCredentials),
    );
    harness.callbacks.add(
      callback.replace(
        queryParameters: {'code': 'query-code', 'state': 'stale'},
        fragment: fragmentCredentials,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    harness.callbacks.add(callback);
    expect((await pending)!.code, 'test-code');
  });

  test('a fragment cannot provide the authorization code', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final pending = harness.source.authorize();
    final expectation = expectLater(
      pending,
      throwsA(
        isA<GoogleAuthorizationException>().having(
          (error) => error.reason,
          'reason',
          GoogleAuthorizationFailure.invalidResponse,
        ),
      ),
    );
    harness.callbacks.add(
      harness.callback().replace(
        queryParameters: {'state': harness.requests.last.queryParameters['state']!},
        fragment: 'code=fragment-only-code',
      ),
    );
    await expectation;
  });

  test('denied consent and explicit cancel are silent cancellations', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final denied = harness.source.authorize();
    harness.callbacks.add(
      harness.callback().replace(
        queryParameters: {
          'state': harness.requests.last.queryParameters['state']!,
          'error': 'access_denied',
        },
      ),
    );
    expect(await denied, isNull);
    final canceled = harness.source.authorize();
    harness.source.cancel();
    expect(await canceled, isNull);
  });

  test('duplicate codes in a matching callback fail without returning a credential', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final result = harness.source.authorize();
    final expectation = expectLater(result, throwsA(isA<GoogleAuthorizationException>()));
    harness.callbacks.add(
      harness.callback().replace(
        queryParameters: {
          'state': harness.requests.last.queryParameters['state']!,
          'code': ['first', 'second'],
        },
      ),
    );
    await expectation;
  });

  test('browser launch failure and timeout release the pending attempt', () async {
    final failed = GoogleAuthorizationDataSource(
      clientId: _testClientId,
      isSupported: true,
      callbackUris: const Stream.empty(),
      launchBrowser: (_) async => false,
    );
    await expectLater(failed.authorize(), throwsA(isA<GoogleAuthorizationException>()));
    final timedOut = GoogleAuthorizationDataSource(
      clientId: _testClientId,
      isSupported: true,
      callbackUris: const Stream.empty(),
      launchBrowser: (_) async => true,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timedOut.authorize(),
      throwsA(
        isA<GoogleAuthorizationException>().having(
          (error) => error.reason,
          'reason',
          GoogleAuthorizationFailure.timedOut,
        ),
      ),
    );
    await expectLater(timedOut.authorize(), throwsA(isA<GoogleAuthorizationException>()));
  });

  test('late callbacks after cancel cannot authenticate the next attempt', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final first = harness.source.authorize();
    final staleCallback = harness.callback();
    harness.source.cancel();
    await first;
    var completed = false;
    final second = harness.source.authorize()..then((_) => completed = true);
    harness.callbacks.add(staleCallback);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    harness.callbacks.add(harness.callback(code: 'current-code'));
    expect((await second)!.code, 'current-code');
  });
}

final _unavailableAuthorization = isA<GoogleAuthorizationException>().having(
  (error) => error.reason,
  'reason',
  GoogleAuthorizationFailure.unavailable,
);

class _Harness {
  _Harness({
    String? clientId = _testClientId,
    String? redirectUri,
    Duration timeout = const Duration(minutes: 3),
  }) {
    source = GoogleAuthorizationDataSource(
      clientId: clientId,
      redirectUri: redirectUri,
      timeout: timeout,
      isSupported: true,
      callbackUris: callbacks.stream,
      launchBrowser: (uri) async {
        requests.add(uri);
        if (!firstRequest.isCompleted) firstRequest.complete(uri);
        return true;
      },
    );
  }

  final callbacks = StreamController<Uri>.broadcast(sync: true);
  final requests = <Uri>[];
  final firstRequest = Completer<Uri>();
  late final GoogleAuthorizationDataSource source;

  Uri callback({String code = 'test-code'}) => Uri.parse(
    source.redirectUri,
  ).replace(queryParameters: {'code': code, 'state': requests.last.queryParameters['state']!});

  Future<void> close() async {
    source.cancel();
    await callbacks.close();
  }
}
