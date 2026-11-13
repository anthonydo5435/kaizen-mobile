import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/features/auth/presentation/pages/forgot_password_screen.dart';
import 'package:sparrowkaizen/features/auth/presentation/pages/set_password_screen.dart';
import 'package:sparrowkaizen/features/auth/presentation/providers/set_password_controller.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = DeepLinkService.instance;
  String? initialLink;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.updateCurrentRouteName(null);
    initialLink = null;
    messenger.setMockMethodCallHandler(messages, (call) async => initialLink);
    messenger.setMockMethodCallHandler(events, (call) async => null);
  });

  tearDown(() async {
    service.takePendingAuthenticatedTarget();
    await service.dispose();
    messenger.setMockMethodCallHandler(messages, null);
    messenger.setMockMethodCallHandler(events, null);
    AppManager.instance.updateCurrentRouteName(null);
  });

  Future<void> openForgotPassword(WidgetTester tester) async {
    await service.initialize();
    final startup = service.consumeStartupTarget(timeout: Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));
    await startup;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        navigatorObservers: [_RouteObserver()],
        onGenerateInitialRoutes: (_) => [
          AppRouter.onGenerateRoute(
            const RouteSettings(name: AppRouter.forgotPassword),
          ),
        ],
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  }

  Future<void> receiveLink(WidgetTester tester, String link) async {
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(link),
      (_) {},
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final host in [
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  ]) {
    testWidgets('$host reset link replaces Forgot Password with Set Password', (
      tester,
    ) async {
      await openForgotPassword(tester);
      await receiveLink(
        tester,
        'https://$host/auth/password-reset/confirm?token=reset-token',
      );

      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(find.byType(SetPasswordScreen), findsOneWidget);
      expect(AppManager.instance.currentRouteName, AppRouter.loginSetPassword);
      final field = find
          .descendant(
            of: find.byType(SetPasswordScreen),
            matching: find.byType(TextField),
          )
          .first;
      expect(
        tester.element(field).read<SetPasswordController>().token,
        'reset-token',
      );
      expect(AppRouter.navigatorKey.currentState!.canPop(), isFalse);
    });
  }

  test('production reset link is available to cold-start navigation', () async {
    initialLink =
        'https://app.kaizenteams.ai/auth/password-reset/confirm/?token=initial-token';
    await service.initialize();
    final target = await service.consumeStartupTarget(timeout: Duration.zero);

    expect(target?.routeName, AppRouter.loginSetPassword);
    expect(
      (target?.arguments as LoginSetPasswordRouteArgs?)?.token,
      'initial-token',
    );
  });

  for (final host in [
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  ]) {
    test(
      '$host verification link opens onboarding with its original token',
      () async {
        final payload = base64Url.encode(
          utf8.encode(jsonEncode({'token_type': 'invitation'})),
        );
        final token = 'Header.$payload.Signature';
        await AppPreference.setAuthToken('previous-session');
        initialLink = 'https://$host/verify_token/$token/';
        await service.initialize();

        final target = await service.consumeStartupTarget(
          timeout: Duration.zero,
        );
        expect(target?.routeName, AppRouter.onboarding);
        expect(target?.clearStack, isTrue);
        expect(target?.requiresAuthentication, isFalse);
        expect(AppPreference.getOnboardingToken(), token);
        expect(AppPreference.getOnboardingTokenType(), 'invitation');
        expect(AppPreference.getAuthToken(), isEmpty);
      },
    );

    test(
      '$host organization link preserves its destination until login',
      () async {
        initialLink =
            'https://$host/organization/Org-ID/ltc/assigned-track/Track-ID/';
        await service.initialize();

        expect(
          await service.consumeStartupTarget(timeout: Duration.zero),
          isNull,
        );
        final target = service.takePendingAuthenticatedTarget();
        expect(target?.routeName, AppRouter.complianceTracks);
        expect(target?.requiresAuthentication, isTrue);
        expect(target?.organizationId, 'Org-ID');
        expect(
          (target?.arguments as ComplianceTracksRouteArgs?)
              ?.trackAssignmentUuid,
          'Track-ID',
        );
      },
    );

    test(
      '$host Google callback cannot be interpreted as a password reset',
      () async {
        initialLink =
            'https://$host/auth/google/callback'
            '?code=google-code&state=google-state&token=unrelated'
            '&next=/auth/password-reset/confirm';
        await service.initialize();

        expect(
          await service.consumeStartupTarget(timeout: Duration.zero),
          isNull,
        );
        expect(service.hasPendingAuthenticatedTarget, isFalse);
      },
    );
  }

  test(
    'untrusted verification and organization links do not change the session',
    () async {
      await AppPreference.setAuthToken('existing-session');
      for (final path in [
        '/verify_token/untrusted-token/',
        '/organization/Org-ID/ltc/assigned-track/Track-ID/',
      ]) {
        initialLink = 'https://example.com$path';
        await service.initialize();
        expect(
          await service.consumeStartupTarget(timeout: Duration.zero),
          isNull,
        );
        expect(service.hasPendingAuthenticatedTarget, isFalse);
        expect(AppPreference.getAuthToken(), 'existing-session');
        expect(AppPreference.getOnboardingToken(), isEmpty);
        await service.dispose();
      }
    },
  );

  for (final host in [
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  ]) {
    test('$host shared LMS link opens without login', () async {
      initialLink = 'https://$host/shared/lms/lesson-123/?source=share';
      await service.initialize();

      final target = await service.consumeStartupTarget(timeout: Duration.zero);
      expect(target?.routeName, AppRouter.sharedLms);
      expect(target?.requiresAuthentication, isFalse);
      expect(
        (target?.arguments as SharedLmsRouteArgs?)?.publicId,
        'lesson-123',
      );
    });
  }

  test('authenticated shared LMS link is available at cold start', () async {
    await AppPreference.setAuthToken('access-token');
    initialLink = 'https://app.kaizenteams.ai/shared/lms/lesson-456';
    await service.initialize();

    final target = await service.consumeStartupTarget(timeout: Duration.zero);
    expect(target?.routeName, AppRouter.sharedLms);
    expect((target?.arguments as SharedLmsRouteArgs?)?.publicId, 'lesson-456');
  });

  test('shared LMS link requires one safe public ID segment', () async {
    for (final link in [
      'https://app.kaizenteams.ai/shared/lms/',
      'https://app.kaizenteams.ai/shared/lms/lesson-123/extra',
      'https://app.kaizenteams.ai/shared/lms/lesson%2F123',
      'https://example.com/shared/lms/lesson-123',
    ]) {
      initialLink = link;
      await service.initialize();
      expect(
        await service.consumeStartupTarget(timeout: Duration.zero),
        isNull,
      );
      await service.dispose();
    }
  });

  for (final host in [
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  ]) {
    test('$host shared seat profile link opens without login', () async {
      initialLink = 'https://$host/shared/seat-profile/seat-123/?source=share';
      await service.initialize();

      final target = await service.consumeStartupTarget(timeout: Duration.zero);
      expect(target?.routeName, AppRouter.sharedSeatProfile);
      expect(target?.requiresAuthentication, isFalse);
      expect(
        (target?.arguments as SharedSeatProfileRouteArgs?)?.publicId,
        'seat-123',
      );
    });
  }

  test('shared seat profile link requires one safe ID segment', () async {
    for (final link in [
      'https://app.kaizenteams.ai/shared/seat-profile/',
      'https://app.kaizenteams.ai/shared/seat-profile/seat-123/extra',
      'https://app.kaizenteams.ai/shared/seat-profile/seat%2F123',
      'https://example.com/shared/seat-profile/seat-123',
    ]) {
      initialLink = link;
      await service.initialize();
      expect(
        await service.consumeStartupTarget(timeout: Duration.zero),
        isNull,
      );
      await service.dispose();
    }
  });

  for (final host in [
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  ]) {
    test('$host shared paygrades link opens without login', () async {
      initialLink =
          'https://$host/shared/paygrades/Paygrades-123/?source=share';
      await service.initialize();
      final target = await service.consumeStartupTarget(timeout: Duration.zero);
      expect(target?.routeName, AppRouter.sharedPaygrades);
      expect(target?.requiresAuthentication, isFalse);
      expect(
        (target?.arguments as SharedPaygradesRouteArgs?)?.publicId,
        'Paygrades-123',
      );
    });
  }

  test(
    'shared paygrades link requires a trusted host and one safe ID',
    () async {
      for (final link in [
        'https://app.kaizenteams.ai/shared/paygrades/',
        'https://app.kaizenteams.ai/shared/paygrades/id/extra',
        'https://app.kaizenteams.ai/shared/paygrades/id%2F123',
        'https://example.com/shared/paygrades/id',
      ]) {
        initialLink = link;
        await service.initialize();
        expect(
          await service.consumeStartupTarget(timeout: Duration.zero),
          isNull,
        );
        await service.dispose();
      }
    },
  );

  test(
    'browser Open app handoff uses the existing shared content routes',
    () async {
      for (final entry in {
        'paygrades': AppRouter.sharedPaygrades,
        'seat-profile': AppRouter.sharedSeatProfile,
        'lms': AppRouter.sharedLms,
      }.entries) {
        final url = 'https://dev.kaizenteams.ai/shared/${entry.key}/Public-ID';
        initialLink = 'kaizenteams://open?url=${Uri.encodeComponent(url)}';
        await service.initialize();
        final target = await service.consumeStartupTarget(
          timeout: Duration.zero,
        );
        expect(target?.routeName, entry.value);
        expect(target?.requiresAuthentication, isFalse);
        await service.dispose();
      }
    },
  );

  test('browser handoff keeps a password reset token intact', () async {
    const url =
        'https://app.kaizenteams.ai/auth/password-reset/confirm?token=A%2BB%26C';
    initialLink = 'kaizenteams://open?url=${Uri.encodeComponent(url)}';
    await service.initialize();
    final target = await service.consumeStartupTarget(timeout: Duration.zero);
    expect(target?.routeName, AppRouter.loginSetPassword);
    expect((target?.arguments as LoginSetPasswordRouteArgs?)?.token, 'A+B&C');
  });

  test('an invalid browser handoff cannot navigate', () async {
    const url = 'https://example.com/shared/paygrades/id';
    initialLink = 'kaizenteams://open?url=${Uri.encodeComponent(url)}';
    await service.initialize();
    expect(await service.consumeStartupTarget(timeout: Duration.zero), isNull);
  });

  test(
    'authenticated shared paygrades links are available at startup',
    () async {
      await AppPreference.setAuthToken('access-token');
      initialLink = 'https://app.kaizenteams.ai/shared/paygrades/id';
      await service.initialize();
      final target = await service.consumeStartupTarget(timeout: Duration.zero);
      expect(target?.routeName, AppRouter.sharedPaygrades);
      expect((target?.arguments as SharedPaygradesRouteArgs?)?.publicId, 'id');
    },
  );

  testWidgets('a different shared paygrades link opens while viewing one', (
    tester,
  ) async {
    await service.initialize();
    final startup = service.consumeStartupTarget(timeout: Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));
    await startup;
    final openedIds = <String>[];
    final openedRoutes = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        navigatorObservers: [_RouteObserver()],
        home: const Scaffold(),
        onGenerateRoute: (settings) {
          openedRoutes.add(settings.name);
          openedIds.add(
            (settings.arguments as SharedPaygradesRouteArgs).publicId,
          );
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(),
          );
        },
      ),
    );
    await receiveLink(
      tester,
      'https://app.kaizenteams.ai/shared/paygrades/first',
    );
    await receiveLink(
      tester,
      'https://app.kaizenteams.ai/shared/paygrades/second',
    );
    const browserDestination =
        'https://app.kaizenteams.ai/shared/paygrades/Third-ID';
    await receiveLink(
      tester,
      'kaizenteams://open?url=${Uri.encodeComponent(browserDestination)}',
    );
    expect(openedIds, ['first', 'second', 'Third-ID']);
    expect(openedRoutes, [
      AppRouter.sharedPaygrades,
      AppRouter.sharedPaygrades,
      AppRouter.sharedPaygrades,
    ]);
  });

  testWidgets(
    'missing tokens, untrusted hosts and Google callbacks do not open Set Password',
    (tester) async {
      await openForgotPassword(tester);
      for (final link in [
        'https://app.kaizenteams.ai/auth/password-reset/confirm',
        'https://app.kaizenteams.ai/auth/password-reset/confirm?token=',
        'https://example.com/auth/password-reset/confirm?token=reset-token',
        'https://app.kaizenteams.ai/auth/google/callback?code=google-code&state=google-state',
      ]) {
        await receiveLink(tester, link);
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        expect(find.byType(SetPasswordScreen), findsNothing);
      }
    },
  );
}

class _RouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppManager.instance.updateCurrentRouteName(route.settings.name);
  }
}
