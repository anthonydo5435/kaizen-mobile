import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/login/data/datasources/google_authorization_data_source.dart';
import 'package:sparrowkaizen/features/login/data/datasources/google_oauth_configuration.dart';
import 'package:sparrowkaizen/features/login/domain/entities/google_authorization.dart';

const _browser = MethodChannel('kaizenteams/google_browser_authorization');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    messenger.setMockMethodCallHandler(_browser, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final config in [
    GoogleOAuthConfiguration.production,
    GoogleOAuthConfiguration.development,
  ]) {
    test('Android captures ${config.redirectUri} with the same Web credentials', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_browser, (call) async {
        calls.add(call);
        if (call.method == 'cancel') return null;
        final request = Uri.parse(call.arguments['authorizationUrl'] as String);
        expect(request.origin, 'https://accounts.google.com');
        expect(request.queryParameters['client_id'], config.clientId);
        expect(request.queryParameters['redirect_uri'], config.redirectUri);
        expect(request.queryParameters['response_type'], 'code');
        expect(request.queryParameters['scope'], 'openid email profile');
        expect(request.queryParameters['state'], call.arguments['requestId']);
        return _callback(call, code: 'code+/with_underscores');
      });

      final authorization = await GoogleAuthorizationDataSource(
        clientId: config.clientId,
        redirectUri: config.redirectUri,
      ).authorize();

      expect(authorization!.code, 'code+/with_underscores');
      expect(authorization.redirectUri, config.redirectUri);
      expect(calls.map((call) => call.method), ['authorize', 'cancel']);
      expect(calls.last.arguments['requestId'], calls.first.arguments['requestId']);
    });
  }

  for (final failure in {
    'unsupported_browser': GoogleAuthorizationFailure.browserUnavailable,
    'verification_failed': GoogleAuthorizationFailure.callbackNotVerified,
    'verification_timed_out': GoogleAuthorizationFailure.timedOut,
    'browser_unavailable': GoogleAuthorizationFailure.unavailable,
  }.entries) {
    test('Android ${failure.key} returns an error without browser fallback or app links', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_browser, (call) async {
        calls.add(call);
        if (call.method == 'authorize') {
          throw PlatformException(code: failure.key);
        }
        return null;
      });
      final source = GoogleAuthorizationDataSource();

      await expectLater(source.authorize(), throwsA(_failure(failure.value)));
      expect(calls.map((call) => call.method), ['authorize', 'cancel']);
      // All browser activity goes through this channel; an app_links or
      // url_launcher fallback would fail because neither plugin is mocked.
    });
  }

  test('Android browser dismissal and denied consent cancel without credentials', () async {
    var denied = false;
    messenger.setMockMethodCallHandler(_browser, (call) async {
      if (call.method == 'cancel' || !denied) return null;
      return Uri.parse(_callback(call))
          .replace(
            queryParameters: {
              'state': call.arguments['requestId'] as String,
              'error': 'access_denied',
            },
          )
          .toString();
    });
    final source = GoogleAuthorizationDataSource();
    expect(await source.authorize(), isNull);
    denied = true;
    expect(await source.authorize(), isNull);
  });

  for (final response in ['google_error', 'wrong_host', 'wrong_state', 'missing_code']) {
    test('Android $response fails immediately after the tab returns', () async {
      messenger.setMockMethodCallHandler(_browser, (call) async {
        if (call.method == 'cancel') return null;
        final callback = Uri.parse(_callback(call));
        return switch (response) {
          'google_error' => callback.replace(
            queryParameters: {
              'state': call.arguments['requestId'] as String,
              'error': 'invalid_request',
            },
          ),
          'wrong_host' => callback.replace(host: 'example.com'),
          'wrong_state' => callback.replace(queryParameters: {'state': 'stale', 'code': 'code'}),
          _ => callback.replace(queryParameters: {'state': call.arguments['requestId'] as String}),
        }.toString();
      });
      await expectLater(
        GoogleAuthorizationDataSource().authorize(),
        throwsA(_failure(GoogleAuthorizationFailure.invalidResponse)),
      );
    });
  }

  test('Android timeout closes the browser session and releases the attempt', () async {
    final response = Completer<String?>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_browser, (call) async {
      calls.add(call);
      if (call.method == 'authorize') return response.future;
      response.complete(null);
      return null;
    });
    await expectLater(
      GoogleAuthorizationDataSource(timeout: const Duration(milliseconds: 10)).authorize(),
      throwsA(_failure(GoogleAuthorizationFailure.timedOut)),
    );
    expect(calls.map((call) => call.method), ['authorize', 'cancel']);
    expect(calls.last.arguments['requestId'], calls.first.arguments['requestId']);
  });

  test('cancel closes its Android tab and a late response cannot finish a retry', () async {
    final firstRequest = Completer<MethodCall>();
    final secondRequest = Completer<MethodCall>();
    final firstResponse = Completer<String?>();
    final secondResponse = Completer<String?>();
    final canceledIds = <String>[];
    messenger.setMockMethodCallHandler(_browser, (call) async {
      if (call.method == 'cancel') {
        canceledIds.add(call.arguments['requestId'] as String);
        return null;
      }
      if (!firstRequest.isCompleted) {
        firstRequest.complete(call);
        return firstResponse.future;
      }
      secondRequest.complete(call);
      return secondResponse.future;
    });
    final source = GoogleAuthorizationDataSource();
    final first = source.authorize();
    final firstCall = await firstRequest.future;
    source.cancel();
    expect(await first, isNull);
    expect(canceledIds, [firstCall.arguments['requestId']]);

    var secondCompleted = false;
    final second = source.authorize()..then((_) => secondCompleted = true);
    final secondCall = await secondRequest.future;
    expect(secondCall.arguments['requestId'], isNot(firstCall.arguments['requestId']));
    firstResponse.complete(_callback(firstCall, code: 'stale-code'));
    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);
    secondResponse.complete(_callback(secondCall, code: 'current-code'));
    expect((await second)!.code, 'current-code');
  });

  test('a missing Android bridge fails in the app without opening an external browser', () async {
    await expectLater(
      GoogleAuthorizationDataSource().authorize(),
      throwsA(_failure(GoogleAuthorizationFailure.unavailable)),
    );
  });

  test('iOS retains the external browser and app-link callback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(_browser, (call) async => fail('Android-only bridge'));
    final callbacks = StreamController<Uri>.broadcast(sync: true);
    addTearDown(callbacks.close);
    final source = GoogleAuthorizationDataSource(
      callbackUris: callbacks.stream,
      launchBrowser: (uri) async {
        callbacks.add(
          Uri.parse(
            uri.queryParameters['redirect_uri']!,
          ).replace(queryParameters: {'state': uri.queryParameters['state']!, 'code': 'ios-code'}),
        );
        return true;
      },
    );
    expect((await source.authorize())!.code, 'ios-code');
  });
}

Matcher _failure(GoogleAuthorizationFailure reason) =>
    isA<GoogleAuthorizationException>().having((error) => error.reason, 'reason', reason);

String _callback(MethodCall call, {String code = 'google-code'}) =>
    Uri.parse(call.arguments['redirectUri'] as String)
        .replace(queryParameters: {'state': call.arguments['requestId'] as String, 'code': code})
        .toString();
