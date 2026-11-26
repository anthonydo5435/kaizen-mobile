import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_billing_details.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/performance_report_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/performance_snapshot_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_report_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_snapshot_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../support/performance_report_fixtures.dart';

void main() {
  testWidgets('returning from certification silently refreshes the listing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    addTearDown(AppManager.instance.resetSessionState);
    AppManager.instance.saveBillingDetails(
      CompanyBillingDetails.fromApiJson({'can_use_paid_features': true}),
    );
    ApiCallExecutor.clearGetCache();
    final user = User(uuid: 'owner', isOwner: true);
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
    await AppPreference.setAuthToken('test-token');
    final repository = ReportRepository();
    final audit = reportAuditController(repository);
    final controller = PerformanceReportController(checkInController: audit);
    addTearDown(audit.dispose);
    addTearDown(controller.dispose);
    await controller.loadAccess();
    await audit.initializePerformanceReport(reportProfile);
    final bytes = (await rootBundle.load(
      AppStrings.dummyProfileImagePath,
    )).buffer.asUint8List();
    await audit.saveFacilitatorSignature(bytes);
    repository.certification = Completer<String?>()..complete('certified');

    final requests = <http.Request>[];
    final responseGate = Completer<void>();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        endsWith(ApiEndPoints.quarterlyAuditPerformanceSnapshot),
      );
      requests.add(request);
      final isCertified = repository.certificationPayload != null;
      if (isCertified) await responseGate.future;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'uuid': 'employee',
              'profile_uuid': 'employee',
              'profile_job': 'profile-job',
              'name': 'Employee One',
              'job_title': 'Engineer',
              'overall_score': isCertified ? 96 : 80,
            },
          ],
        }),
        200,
      );
    });
    addTearDown(client.close);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: MaterialApp(
            home: const PerformanceSnapshotScreen(),
            onGenerateRoute: (settings) {
              expect(settings.name, AppRouter.reports);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider<CheckInController>.value(
                      value: audit,
                    ),
                    ChangeNotifierProvider<PerformanceReportController>.value(
                      value: controller,
                    ),
                  ],
                  child: const PerformanceReportView(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byType(PerformanceSnapshotCard);
      double cardScore() =>
          tester.widget<PerformanceSnapshotCard>(card).member.overallScore;
      final snapshot = tester
          .element(find.byType(ListView).first)
          .read<PerformanceSnapshotController>();
      expect(card, findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Employee');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      snapshot.setSelectedJobTitle('Engineer');
      await tester.pumpAndSettle();
      final requestsBeforeCertification = requests.length;
      expect(cardScore(), 80);

      await tester.tap(find.text(AppStrings.view));
      await tester.pumpAndSettle();
      final certify = find.widgetWithText(FilledButton, AppStrings.certify);
      await tester.ensureVisible(certify);
      await tester.tap(certify);
      await tester.pumpAndSettle();
      expect(audit.state.performanceReport?.isCertified, isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(requests, hasLength(requestsBeforeCertification + 1));
      expect(requests.last.url.queryParameters['search'], 'Employee');
      expect(find.byType(FastCircularProgressIndicator), findsNothing);
      expect(cardScore(), 80);
      responseGate.complete();
      await tester.pumpAndSettle();
      expect(cardScore(), 96);
      expect(snapshot.selectedJobTitle, 'Engineer');
      expect(snapshot.searchController.text, 'Employee');

      // The real certification POST clears the HTTP cache.
      ApiCallExecutor.clearGetCache();
      await snapshot.resetSearch();
      await tester.pumpAndSettle();
      expect(cardScore(), 96);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
