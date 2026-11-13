import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _logNotificationMessage(
    'Background FCM message: ${message.messageId ?? 'unknown-id'}',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _isInitialized = false;
  bool _isFetchingToken = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _logNotificationMessage('PushNotificationService.initialize started.');
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final permissionSettings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    _logNotificationMessage(
      'Notification permission status: ${permissionSettings.authorizationStatus.name}',
    );

    messaging.onTokenRefresh.listen((token) {
      _logToken(token, source: 'refresh');
    });

    unawaited(_fetchAndLogToken(messaging));

    FirebaseMessaging.onMessage.listen((message) {
      _logNotificationMessage(
        'Foreground FCM message: ${message.messageId ?? 'unknown-id'}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logNotificationMessage(
        'Opened from FCM notification: ${message.messageId ?? 'unknown-id'}',
      );
    });

    _isInitialized = true;
    _logNotificationMessage('PushNotificationService.initialize completed.');
  }

  Future<void> _fetchAndLogToken(FirebaseMessaging messaging) async {
    if (_isFetchingToken) {
      return;
    }

    _isFetchingToken = true;
    try {
      for (var attempt = 1; attempt <= 10; attempt++) {
        _logNotificationMessage('Fetching FCM token, attempt $attempt/10...');
        final token = await _resolveFcmToken(messaging);
        if (token != null && token.isNotEmpty) {
          _logToken(token, source: 'startup');
          return;
        }

        if (attempt < 10) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }

      _logToken(null, source: 'startup');
    } finally {
      _isFetchingToken = false;
    }
  }

  Future<String?> _resolveFcmToken(FirebaseMessaging messaging) async {
    if (Platform.isIOS) {
      final apnsToken = await _waitForApnsToken(messaging);
      if (apnsToken == null || apnsToken.isEmpty) {
        _logNotificationMessage(
          'Skipping FCM token fetch because APNs token is not available yet.',
        );
        return null;
      }
    }

    try {
      return await messaging.getToken();
    } on FirebaseException catch (error) {
      if (error.code == 'apns-token-not-set') {
        _logNotificationMessage(
          'Skipping FCM token fetch because APNs token is not available yet.',
        );
        return null;
      }
      _logNotificationMessage(
        'FCM token fetch failed with FirebaseException: ${error.code}',
      );
      rethrow;
    }
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        _logNotificationMessage('APNs token: $apnsToken');
        return apnsToken;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    return null;
  }

  void _logToken(String? token, {required String source}) {
    if (token == null || token.isEmpty) {
      _logNotificationMessage('FCM token unavailable from $source.');
      return;
    }

    _logNotificationMessage('FCM token ($source): $token');
  }
}

void _logNotificationMessage(String message) {
  debugPrint(message);
}
