import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/navigation/browser_app_link.dart';
import '../../domain/entities/google_authorization.dart';
import '../../google_sign_in_diagnostics.dart';
import 'google_oauth_configuration.dart';

/// Uses a browser OAuth code flow, with a captured Auth Tab callback on Android.
class GoogleAuthorizationDataSource {
  GoogleAuthorizationDataSource({
    String? clientId,
    String? redirectUri,
    Stream<Uri>? callbackUris,
    Future<bool> Function(Uri)? launchBrowser,
    bool? isSupported,
    this.timeout = const Duration(minutes: 3),
  }) : clientId = (clientId ?? GoogleOAuthConfiguration.current.clientId).trim(),
       redirectUri = redirectUri ?? GoogleOAuthConfiguration.current.redirectUri,
       _callbackUris = callbackUris,
       _launchBrowser = launchBrowser ?? _openBrowser,
       _usesAndroidAuthTab =
           launchBrowser == null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
       _isSupported =
           isSupported ??
           (!kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.android ||
                   defaultTargetPlatform == TargetPlatform.iOS));

  final String clientId;
  final String redirectUri;
  final Duration timeout;
  final Stream<Uri>? _callbackUris;
  final Future<bool> Function(Uri) _launchBrowser;
  final bool _isSupported;
  final bool _usesAndroidAuthTab;
  static const _androidBrowser = MethodChannel('kaizenteams/google_browser_authorization');
  Completer<GoogleAuthorization?>? _pending;

  Future<GoogleAuthorization?> authorize() async {
    final callback = Uri.tryParse(redirectUri);
    GoogleSignInDiagnostics.log(
      'authorization.config',
      data: {
        'client_id': clientId,
        'redirect_uri': callback ?? redirectUri,
        'platform': defaultTargetPlatform.name,
        'supported': _isSupported,
        'attempt_pending': _pending != null,
        'timeout_seconds': timeout.inSeconds,
      },
    );
    if (!_isSupported ||
        _pending != null ||
        clientId.isEmpty ||
        !GoogleOAuthConfiguration(
          clientId: clientId,
          redirectUri: redirectUri,
        ).hasMatchingCallback ||
        callback == null ||
        callback.scheme != 'https' ||
        callback.host.isEmpty ||
        callback.hasQuery ||
        callback.hasFragment ||
        callback.userInfo.isNotEmpty) {
      GoogleSignInDiagnostics.log('authorization.unavailable');
      throw const GoogleAuthorizationException(GoogleAuthorizationFailure.unavailable);
    }

    final random = Random.secure();
    final state = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    final result = Completer<GoogleAuthorization?>();
    _pending = result;
    StreamSubscription<Uri>? subscription;
    Timer? timer;

    try {
      if (!_usesAndroidAuthTab) {
        subscription = (_callbackUris ?? AppLinks().uriLinkStream).listen(
          (uri) => _handleCallback(uri, callback, state, result),
          onError: (Object error, StackTrace stackTrace) {
            GoogleSignInDiagnostics.log(
              'callback.stream_error',
              error: error,
              stackTrace: stackTrace,
            );
            _fail(result, GoogleAuthorizationFailure.unavailable);
          },
          onDone: () => GoogleSignInDiagnostics.log('callback.stream_closed'),
        );
        GoogleSignInDiagnostics.log('callback.listener_attached');
      }
      timer = Timer(timeout, () {
        GoogleSignInDiagnostics.log(
          'callback.timeout',
          data: {
            'timeout_seconds': timeout.inSeconds,
            'expected_callback': callback,
            'reason': _usesAndroidAuthTab
                ? 'No valid Google callback returned from the Android Auth Tab.'
                : 'No valid Google callback reached this attempt; check browser redirect and app-link association.',
          },
        );
        _fail(result, GoogleAuthorizationFailure.timedOut);
      });
      final authorizationUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'prompt': 'select_account',
        'state': state,
      });
      unawaited(
        _usesAndroidAuthTab
            ? _launchAndroidAuthTab(authorizationUri, callback, state, result)
            : _launch(authorizationUri, result),
      );
      return await result.future;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      if (_usesAndroidAuthTab) await _closeAndroidAuthTab(state);
      _pending = null;
      GoogleSignInDiagnostics.log('callback.listener_removed');
    }
  }

  Future<void> _launchAndroidAuthTab(
    Uri authorizationUri,
    Uri callback,
    String state,
    Completer<GoogleAuthorization?> result,
  ) async {
    try {
      GoogleSignInDiagnostics.log('auth_tab.launch', data: {'url': authorizationUri});
      final response = await _androidBrowser.invokeMethod<String>('authorize', {
        'authorizationUrl': authorizationUri.toString(),
        'redirectUri': redirectUri,
        'requestId': state,
      });
      if (result.isCompleted) return;
      if (response == null) {
        GoogleSignInDiagnostics.log('auth_tab.cancelled');
        result.complete(null);
        return;
      }
      final uri = Uri.tryParse(response);
      if (uri != null) _handleCallback(uri, callback, state, result);
      // The browser has closed. An invalid callback must fail here, without
      // opening a website or waiting for another app link.
      if (!result.isCompleted) {
        _fail(result, GoogleAuthorizationFailure.invalidResponse);
      }
    } on PlatformException catch (error, stackTrace) {
      GoogleSignInDiagnostics.log('auth_tab.error', error: error, stackTrace: stackTrace);
      _fail(result, switch (error.code) {
        'unsupported_browser' => GoogleAuthorizationFailure.browserUnavailable,
        'verification_failed' => GoogleAuthorizationFailure.callbackNotVerified,
        'verification_timed_out' => GoogleAuthorizationFailure.timedOut,
        _ => GoogleAuthorizationFailure.unavailable,
      });
    } catch (error, stackTrace) {
      GoogleSignInDiagnostics.log('auth_tab.error', error: error, stackTrace: stackTrace);
      _fail(result, GoogleAuthorizationFailure.unavailable);
    }
  }

  Future<void> _closeAndroidAuthTab(String requestId) async {
    try {
      await _androidBrowser.invokeMethod<void>('cancel', {'requestId': requestId});
    } catch (error, stackTrace) {
      GoogleSignInDiagnostics.log('auth_tab.close_error', error: error, stackTrace: stackTrace);
    }
  }

  void cancel() {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      GoogleSignInDiagnostics.log('authorization.cancel_requested');
      pending.complete(null);
    }
  }

  Future<void> _launch(Uri uri, Completer<GoogleAuthorization?> result) async {
    try {
      GoogleSignInDiagnostics.log('browser.launch', data: {'url': uri});
      final launched = await _launchBrowser(uri);
      GoogleSignInDiagnostics.log('browser.launch_result', data: {'launched': launched});
      if (!launched) _fail(result, GoogleAuthorizationFailure.unavailable);
    } catch (error, stackTrace) {
      GoogleSignInDiagnostics.log('browser.launch_error', error: error, stackTrace: stackTrace);
      _fail(result, GoogleAuthorizationFailure.unavailable);
    }
  }

  void _handleCallback(
    Uri incomingUri,
    Uri callback,
    String expectedState,
    Completer<GoogleAuthorization?> result,
  ) {
    final uri = resolveBrowserAppLink(incomingUri);
    if (uri == null) return;

    GoogleSignInDiagnostics.log(
      'callback.received',
      data: {'url': uri, 'parameters': uri.queryParametersAll},
    );
    if (result.isCompleted) {
      GoogleSignInDiagnostics.log(
        'callback.ignored',
        data: {'reason': 'attempt_already_completed'},
      );
      return;
    }
    if (uri.scheme != callback.scheme ||
        uri.host != callback.host ||
        uri.port != callback.port ||
        uri.path != callback.path ||
        uri.userInfo.isNotEmpty) {
      GoogleSignInDiagnostics.log(
        'callback.ignored',
        data: {'reason': 'callback_url_mismatch', 'expected_callback': callback},
      );
      return;
    }

    // Browsers may append a fragment, including an empty trailing '#'. This
    // code flow reads credentials only from the query, never from the fragment.
    if (uri.hasFragment) {
      GoogleSignInDiagnostics.log(
        'callback.fragment_ignored',
        data: {'fragment_is_empty': uri.fragment.isEmpty},
      );
    }

    final states = uri.queryParametersAll['state'];
    // Ignore unsolicited or stale callbacks, including links from a prior attempt.
    if (states == null || states.length != 1 || states.single != expectedState) {
      GoogleSignInDiagnostics.log(
        'callback.ignored',
        data: {'reason': 'missing_duplicate_or_stale_state', 'state_count': states?.length ?? 0},
      );
      return;
    }

    final errors = uri.queryParametersAll['error'];
    if (errors != null) {
      GoogleSignInDiagnostics.log('google.error', data: {'parameters': uri.queryParametersAll});
      if (errors.length == 1 && errors.single == 'access_denied') {
        result.complete(null);
      } else {
        _fail(result, GoogleAuthorizationFailure.invalidResponse);
      }
      return;
    }
    final codes = uri.queryParametersAll['code'];
    if (codes == null || codes.length != 1 || codes.single.trim().isEmpty) {
      GoogleSignInDiagnostics.log(
        'callback.invalid_code',
        data: {
          'code_count': codes?.length ?? 0,
          'has_nonblank_code': codes?.any((code) => code.trim().isNotEmpty) ?? false,
        },
      );
      _fail(result, GoogleAuthorizationFailure.invalidResponse);
      return;
    }
    GoogleSignInDiagnostics.log('callback.accepted', data: {'has_code': true});
    result.complete(GoogleAuthorization(code: codes.single, redirectUri: redirectUri));
  }

  static void _fail(Completer<GoogleAuthorization?> result, GoogleAuthorizationFailure failure) {
    if (!result.isCompleted) {
      GoogleSignInDiagnostics.log('authorization.failure', data: {'reason': failure.name});
      result.completeError(GoogleAuthorizationException(failure));
    }
  }

  static Future<bool> _openBrowser(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}
