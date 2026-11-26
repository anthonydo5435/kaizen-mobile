import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/features/login/presentation/pages/verify_email_screen.dart';
import 'package:sparrowkaizen/main.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../support/user_detail_fixtures.dart';

void main() {
  testWidgets('an unfinished workspace shows a dialog on Login until ready', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    addTearDown(AppManager.instance.resetSessionState);
    addTearDown(DeepLinkService.instance.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 844);
    addTearDown(tester.view.reset);

    const messages = MethodChannel('com.llfbandit.app_links/messages');
    const links = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(messages, (_) async => null);
    messenger.setMockMethodCallHandler(links, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(messages, null);
      messenger.setMockMethodCallHandler(links, null);
    });

    final payload = base64Url
        .encode(utf8.encode('{"token_type":"email_verification"}'))
        .replaceAll('=', '');
    final verificationToken = 'Header.$payload.Signature';
    var verified = false;
    var workspaceReady = false;
    var verificationCheckFails = false;
    var resendFails = false;
    var accessExpired = false;
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
      if (endpoint == ApiEndPoints.resendVerificationLink && resendFails) {
        return http.Response(
          '{"error":"Please wait before sending another email."}',
          400,
        );
      }
      if (endpoint == ApiEndPoints.userDetail && verificationCheckFails) {
        return http.Response('{"detail":"Unavailable"}', 500);
      }
      if (endpoint == ApiEndPoints.userDetail && accessExpired) {
        accessExpired = false;
        return http.Response('{"detail":"Token expired"}', 401);
      }
      if (endpoint == ApiEndPoints.verifyToken(verificationToken)) {
        verified = true;
        return http.Response(
          '{"success":true,"type":"email_verification"}',
          200,
        );
      }
      final Object response = switch (endpoint) {
        ApiEndPoints.login => {'access': 'access', 'refresh': 'refresh'},
        ApiEndPoints.refreshToken => {
          'access': 'rotated-access',
          'refresh': 'rotated-refresh',
        },
        ApiEndPoints.organizations => [
          {'uuid': 'org', 'name': 'Workspace', 'type': 'organization'},
        ],
        ApiEndPoints.userDetail => {
          ...userDetailResponse,
          'is_email_verified': verified,
        },
        ApiEndPoints.resendVerificationLink => {
          'message': 'Link has been resent successfully',
        },
        ApiEndPoints.companyImportStatus => {
          'ready': workspaceReady,
          'job': null,
        },
        ApiEndPoints.organizationHierarchy => [],
        ApiEndPoints.companyDetail => {
          'uuid': 'org',
          'name': 'Workspace',
          'billing': {'can_use_paid_features': true},
        },
        ApiEndPoints.trainingModulesAll => {'results': []},
        _ => throw StateError('Unexpected endpoint $endpoint'),
      };
      return http.Response(jsonEncode(response), 200);
    });
    addTearDown(client.close);

    int callsTo(String endpoint) => requests
        .where((r) => r.url.path == '${ApiEndPoints.version}$endpoint')
        .length;

    final appBoundaryKey = GlobalKey();
    Future<void> openApp() async {
      await tester.pumpWidget(
        RepaintBoundary(key: appBoundaryKey, child: const MyApp()),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    Future<void> signIn() async {
      await tester.enterText(find.byType(TextField).at(0), 'owner@kaizen.com');
      await tester.enterText(find.byType(TextField).at(1), 'test-password');
      await tester.tap(find.text(AppStrings.loginButton));
      await tester.pumpAndSettle();
    }

    Future<void> dismissAccountInProgressDialog() async {
      expect(find.text('Account In-progress'), findsOneWidget);
      expect(
        find.text(
          'Please wait while your account is being setting up on KaizenTeams!',
        ),
        findsOneWidget,
      );
      expect(AppPreference.getAuthToken(), isEmpty);
      expect(AppPreference.getRefreshToken(), isEmpty);
      expect(callsTo(ApiEndPoints.companyDetail), 0);
      expect(callsTo(ApiEndPoints.organizationHierarchy), 0);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.loginToYourAccount), findsOneWidget);
      expect(AppManager.instance.currentRouteName, AppRouter.login);
    }

    await http.runWithClient(() async {
      await DeepLinkService.instance.initialize();
      await openApp();
      expect(tester.takeException(), isNull, reason: 'initial sign-in screen');
      await signIn();
      expect(tester.takeException(), isNull, reason: 'verification screen');

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(AppManager.instance.currentRouteName, AppRouter.verifyEmail);
      expect(find.text(AppStrings.loginVerifyEmailDescription), findsOneWidget);
      expect(find.text('owner@kaizen.com'), findsNothing);
      expect(AppPreference.getAuthToken(), isEmpty);
      expect(AppPreference.getRefreshToken(), isEmpty);
      expect(callsTo(ApiEndPoints.companyImportStatus), 0);
      expect(callsTo(ApiEndPoints.companyDetail), 0);
      expect(callsTo(ApiEndPoints.organizationHierarchy), 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await AppPreference.init();
      AppManager.instance.resetSessionState();
      await AppManager.instance.hydrateCurrentUser();
      final previousChecks = callsTo(ApiEndPoints.userDetail);
      await openApp();
      expect(find.text(AppStrings.loginToYourAccount), findsOneWidget);
      expect(callsTo(ApiEndPoints.userDetail), previousChecks);
      await signIn();

      final sendEmail = find.widgetWithText(InkWell, 'Send Email');
      await _expectCompactGradient(tester, sendEmail, appBoundaryKey);
      final confirmVerification = find.widgetWithText(
        TextButton,
        AppStrings.loginConfirmEmailVerified,
      );
      expect(
        tester.getCenter(confirmVerification).dy,
        greaterThan(tester.getCenter(sendEmail).dy),
      );
      final sendButton = tester.getRect(sendEmail);
      await tester.tapAt(sendButton.topCenter - const Offset(0, 3));
      await tester.pumpAndSettle();
      expect(callsTo(ApiEndPoints.resendVerificationLink), 0);

      await tester.tapAt(sendButton.centerLeft + const Offset(5, 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Link has been resent successfully'),
        ),
        findsOneWidget,
      );
      final resend = requests.singleWhere(
        (r) => r.url.path.endsWith(ApiEndPoints.resendVerificationLink),
      );
      expect(resend.method, 'POST');
      expect(jsonDecode(resend.body), {
        'user_uuid': userDetailResponse['uuid'],
      });

      resendFails = true;
      await tester.tap(sendEmail);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Please wait before sending another email.'),
        ),
        findsOneWidget,
      );

      verificationCheckFails = true;
      await tester.tap(confirmVerification);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(AppStrings.loginSetupStatusFailed),
        ),
        findsOneWidget,
      );

      verificationCheckFails = false;
      accessExpired = true;
      await tester.tap(confirmVerification);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'verification feedback');
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(AppStrings.loginEmailNotVerifiedYet),
        ),
        findsOneWidget,
      );
      expect(callsTo(ApiEndPoints.companyImportStatus), 0);
      expect(callsTo(ApiEndPoints.refreshToken), 1);
      expect(requests.last.headers['authorization'], 'Bearer rotated-access');
      expect(AppPreference.getAuthToken(), isEmpty);
      expect(AppPreference.getRefreshToken(), isEmpty);

      await messenger.handlePlatformMessage(
        links.name,
        const StandardMethodCodec().encodeSuccessEnvelope(
          'https://dev.kaizenteams.ai/verify_token/$verificationToken/',
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(callsTo(ApiEndPoints.verifyToken(verificationToken)), 1);
      expect(callsTo(ApiEndPoints.companyImportStatus), 1);
      await dismissAccountInProgressDialog();

      await tester.pumpWidget(const SizedBox.shrink());
      await AppPreference.setAuthToken('saved-access');
      await AppPreference.setRefreshToken('saved-refresh');
      AppManager.instance.resetSessionState();
      await AppManager.instance.hydrateCurrentUser();
      await openApp();
      expect(callsTo(ApiEndPoints.companyImportStatus), 2);
      await dismissAccountInProgressDialog();

      await signIn();
      expect(callsTo(ApiEndPoints.companyImportStatus), 3);
      await dismissAccountInProgressDialog();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'owner@kaizen.com',
      );

      workspaceReady = true;
      await tester.tap(find.text(AppStrings.loginButton));
      await tester.pumpAndSettle();
      expect(callsTo(ApiEndPoints.companyImportStatus), 4);
      expect(callsTo(ApiEndPoints.companyDetail), 1);
      expect(callsTo(ApiEndPoints.organizationHierarchy), 1);
      expect(
        AppManager.instance.currentRouteName,
        AppRouter.defaultAuthenticatedRouteName,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }, () => client);
  });
}

Future<void> _expectCompactGradient(
  WidgetTester tester,
  Finder button,
  GlobalKey boundaryKey,
) async {
  final surface = find.descendant(
    of: button,
    matching: find.byWidgetPredicate((widget) {
      final decoration = widget is Ink ? widget.decoration : null;
      return decoration is ShapeDecoration && decoration.gradient != null;
    }),
  );
  final rect = tester.getRect(surface);
  expect(rect.height, 32);
  expect(rect.width, lessThan(175));

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int blueAt(Offset point) => pixels.getUint8(
        (point.dy.floor() * image.width + point.dx.floor()) * 4 + 2,
      );
      final left = blueAt(rect.centerLeft + const Offset(5, 0));
      final right = blueAt(rect.centerRight - const Offset(5, 0));
      final corner = blueAt(rect.topLeft + const Offset(1, 1));
      expect(left - right, greaterThan(40));
      expect(corner, lessThan(125));
    } finally {
      image.dispose();
    }
  });
}
