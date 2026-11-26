import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_details.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/core/widgets/billing_banner.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/main.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  final requests = <String>[];
  final client = MockClient((request) async {
    final path = request.url.path;
    requests.add(path);
    Object body;
    if (path.endsWith(ApiEndPoints.organizations)) {
      body = [
        {'uuid': 'first', 'name': 'First Organisation', 'type': 'child'},
      ];
    } else if (path.endsWith(ApiEndPoints.userDetail)) {
      body = {
        'profile': User(uuid: 'user', organizationUuid: 'first').toJson(),
      };
    } else if (path.endsWith(ApiEndPoints.organizationHierarchy)) {
      body = [];
    } else if (path.endsWith(ApiEndPoints.companyDetail)) {
      body = {'uuid': 'first', 'name': 'First Organisation'};
    } else {
      throw StateError('Unexpected request: $path');
    }
    return http.Response(jsonEncode(body), 200);
  });
  tearDownAll(client.close);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    requests.clear();
  });
  tearDown(() async {
    await DeepLinkService.instance.dispose();
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
  });

  testWidgets(
    'the trial banner is dismissible and updates when the trial ends',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      AppRouter.navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();

      final manager = AppManager.instance;
      final trialCompany = CompanyDetails.fromApiJson({
        'uuid': 'first',
        'billing': {
          'status': 'unpaid',
          'is_in_trial': true,
          'can_use_paid_features': true,
        },
      });
      manager.saveActiveCompany(trialCompany);
      await tester.pumpAndSettle();
      expect(find.text('You are in trial access for now'), findsOneWidget);
      expect(find.text(AppStrings.billingBannerText), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(BillingBanner),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BillingBanner), findsNothing);
      expect(manager.canUsePaidFeatures, isTrue);

      manager.saveActiveCompany(trialCompany);
      await tester.pumpAndSettle();
      expect(find.byType(BillingBanner), findsNothing);

      manager.saveActiveCompany(
        CompanyDetails.fromApiJson({
          'uuid': 'first',
          'billing': {'status': 'unpaid', 'is_in_trial': false},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.billingBannerText), findsOneWidget);
      expect(find.text(AppStrings.trialBannerText), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final skipProfileRefresh in [false, true]) {
    testWidgets(
      'resume refreshes organisations even when profile refresh is skipped ($skipProfileRefresh)',
      (tester) async {
        await http.runWithClient(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpWidget(const MyApp());
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          AppRouter.navigatorKey.currentState!.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
          );
          await tester.pumpAndSettle();
          await AppPreference.setAuthToken('access');
          await AppPreference.setRefreshToken('refresh');
          AppManager.instance.updateCurrentUser(User(uuid: 'user'));
          if (skipProfileRefresh) {
            AppManager.instance.skipNextResumeSessionRefresh();
          }

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(requests.first, endsWith(ApiEndPoints.organizations));
          expect(requests, hasLength(skipProfileRefresh ? 1 : 4));
          expect(AppPreference.getSelectedOrganization()?.id, 'first');

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(
            requests.where((path) => path.endsWith(ApiEndPoints.organizations)),
            hasLength(2),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }
}
