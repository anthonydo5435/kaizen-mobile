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
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/performance_report.dart';
import 'package:sparrowkaizen/features/check_in/data/models/performance_report_model.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/seat_description_final_check_in_report.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/performance_report_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_report_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_report_commitment_card.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_report_persona_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

import '../../support/performance_report_fixtures.dart';

void main() {
  late ReportRepository repository;
  late CheckInController audit;
  late PerformanceReportController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    repository = ReportRepository();
    audit = reportAuditController(repository);
    controller = PerformanceReportController(
      checkInController: audit,
      loadUser: () async => User(isOwner: true),
    );
    await controller.loadAccess();
    await audit.initializePerformanceReport(reportProfile);
  });
  tearDown(() {
    controller.dispose();
    audit.dispose();
    AppManager.instance.resetSessionState();
  });

  Future<void> mount(WidgetTester tester, {bool isMyReport = false}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CheckInController>.value(value: audit),
          ChangeNotifierProvider<PerformanceReportController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp(home: PerformanceReportView(isMyReport: isMyReport)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'production screen wiring loads through the existing repository',
    (tester) async {
      final paths = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: PerformanceReportScreen(profile: reportProfile),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Daily delivery'), findsOneWidget);
          expect(
            paths,
            containsAll([
              ApiEndPoints.auditReportOverview('profile-job'),
              ApiEndPoints.auditReportCertifiedReports('profile-job'),
            ]),
          );
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          paths.add(request.url.path.replaceFirst('/api/v1/', ''));
          if (request.url.path.endsWith(
            ApiEndPoints.auditReportCertifiedReports('profile-job'),
          )) {
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'created_at': '2025-01-01',
              'selected_profile': {'uuid': 'employee', 'name': 'Employee One'},
              'job': {'title': 'Engineering'},
              'categories': [
                {
                  'uuid': 'category',
                  'category_title': 'Responsibilities',
                  'descriptions': [
                    {
                      'uuid': 'description',
                      'description': 'Daily delivery',
                      'great': 3,
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets('category and employee selectors update the displayed report', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(
      find.text(AppStrings.performanceReportSelectedCategoryTitle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collaboration'));
    await tester.pumpAndSettle();
    expect(find.text('Team support'), findsOneWidget);
    expect(find.text('Daily delivery'), findsNothing);
    await tester.tap(find.text('Employee Two'));
    await tester.pumpAndSettle();
    expect(repository.overviewProfiles.last.profileUuid, 'second');
    expect(find.text('Daily delivery'), findsOneWidget);
    expect(controller.selectedCategoryIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom dates apply from the existing calendar and quarter can be restored',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppStrings.performanceReportCustomDateRange).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose Date range'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.chevron_left_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(of: find.byType(Dialog), matching: find.text('1'))
            .first,
      );
      await tester.pump();
      await tester.tap(
        find
            .descendant(of: find.byType(Dialog), matching: find.text('2'))
            .first,
      );
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(repository.lastStart, DateTime(now.year, now.month - 1, 1));
      expect(repository.lastEnd, DateTime(now.year, now.month - 1, 2));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.performanceReportThisQuarter).last);
      await tester.pumpAndSettle();
      expect(repository.lastStart, isNull);
      expect(repository.lastQuarter, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('archived reports synchronize comments and remain read only', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(
      find.text(AppStrings.performanceReportSelectCertifiedReport),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.text('Certified Quarter'));
    await tester.pumpAndSettle();
    expect(repository.detailRequests, ['certified']);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(controller.commentsController.text, 'Certified commitment');
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text(AppStrings.performanceReportAddSignature), findsNothing);
  });

  testWidgets(
    'my report hides commitment while core value details remain available',
    (tester) async {
      await mount(tester, isMyReport: true);
      expect(find.byType(PerformanceReportCommitmentCard), findsNothing);
      await tester.ensureVisible(
        find.text(AppStrings.performanceReportCoreValuesTitle),
      );
      await tester.tap(find.text(AppStrings.performanceReportCoreValuesTitle));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ownership'));
      await tester.tap(find.text('Ownership'));
      await tester.pumpAndSettle();
      expect(find.text('Follow through'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('employee and facilitator actions open the signature dialog', (
    tester,
  ) async {
    await mount(tester);
    for (final title in [
      AppStrings.performanceReportEmployeeSignature,
      AppStrings.performanceReportFacilitatorSignature,
    ]) {
      final buttons = find.text(AppStrings.performanceReportAddSignature);
      final button = title == AppStrings.performanceReportEmployeeSignature
          ? buttons.first
          : buttons.last;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNWidgets(2));
      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      Navigator.of(tester.element(find.text('Draw'))).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'certification keeps its size and submits signatures and commitment in a child organisation',
    (tester) async {
      await http.runWithClient(
        () => AppManager.instance.fetchOrganizations(requireSuccess: true),
        () => MockClient(
          (_) async => http.Response(
            '[{"uuid":"child-org","name":"Child","type":"child"}]',
            200,
          ),
        ),
      );
      AppManager.instance.updateCurrentUser(
        User(isOwner: true, organizationUuid: 'child-org'),
      );
      expect(AppManager.instance.canCurrentOrganizationModifyContent, isFalse);
      await mount(tester);
      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      expect(tester.widget<TextField>(field).readOnly, isFalse);
      await tester.enterText(field, '  Deliver consistently  ');
      final bytes = (await rootBundle.load(
        AppStrings.dummyProfileImagePath,
      )).buffer.asUint8List();
      await audit.saveEmployeeSignature(bytes);
      await audit.saveFacilitatorSignature(bytes);
      await tester.pumpAndSettle();
      repository.certification = Completer<String?>();
      final button = find.widgetWithText(FilledButton, AppStrings.certify);
      await tester.ensureVisible(button);
      final before = tester.getSize(button);
      await tester.tap(button);
      await tester.pump();
      expect(tester.getSize(button), before);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(
        find.descendant(
          of: button,
          matching: find.byType(FastCircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(repository.certificationProfileJob, 'profile-job');
      expect(
        repository.certificationPayload,
        containsPair('commitment_comment', 'Deliver consistently'),
      );
      expect(
        repository.certificationPayload,
        containsPair('employee_signature_uuid', 'signature-1'),
      );
      expect(
        repository.certificationPayload,
        containsPair('facilitator_signature_uuid', 'signature-2'),
      );
      repository.certification!.complete('certified');
      await tester.pumpAndSettle();
      expect(audit.state.performanceReport!.isCertified, isTrue);
      expect(tester.widget<TextField>(field).readOnly, isTrue);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('certification validation feedback is retained', (tester) async {
    await mount(tester);
    final button = find.widgetWithText(FilledButton, AppStrings.certify);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Employee and Facilitator signatures are required before certifying.',
      ),
      findsOneWidget,
    );
    expect(repository.certificationPayload, isNull);
  });

  testWidgets(
    'generating remarks preserves button bounds and updates the ratings',
    (tester) async {
      repository.buildReport = (profile) =>
          reportFixture(profile: profile, hasPersonality: true);
      await audit.initializePerformanceReport(reportProfile);
      await mount(tester);
      final button = find.widgetWithText(
        OutlinedButton,
        AppStrings.performanceReportGenerateRemarks,
      );
      await tester.ensureVisible(button);
      final before = tester.getSize(button);
      final generating = audit.generatePerformanceReportRemarks();
      await tester.pump();
      await generating;
      await tester.pumpAndSettle();
      expect(tester.getSize(button), before);
      expect(find.byType(PerformanceReportPersonaCard), findsOneWidget);
      expect(find.text('Generated guidance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and unavailable states use the shared feedback', (
    tester,
  ) async {
    final pending = Completer<PerformanceReport>();
    repository.pendingOverview = pending.future;
    final loading = audit.initializePerformanceReport(reportProfile);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CheckInController>.value(value: audit),
          ChangeNotifierProvider<PerformanceReportController>.value(
            value: controller,
          ),
        ],
        child: const MaterialApp(home: PerformanceReportView()),
      ),
    );
    await tester.pump();
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('Unavailable'));
    await loading;
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.performanceReportUnavailable), findsOneWidget);
  });
  testWidgets(
    'description navigation retains profile, description and quarter context',
    (tester) async {
      await mount(tester);
      final go = find.byIcon(Icons.arrow_forward_ios_rounded);
      await tester.ensureVisible(go);
      await tester.tap(go);
      await tester.pumpAndSettle();
      final target = tester.widget<SeatDescriptionFinalCheckInReportScreen>(
        find.byType(SeatDescriptionFinalCheckInReportScreen),
      );
      final quarter = CustomFunctions.currentYearQuarter();
      expect(target.flowFirstId, 'profile-job');
      expect(target.profileUuid, 'employee');
      expect(target.descriptionId, 'description');
      expect(target.quarter, quarter.quarter);
      expect(target.year, quarter.year);
      expect(
        tester
            .element(find.byType(SeatDescriptionFinalCheckInReportScreen))
            .read<CheckInController>(),
        same(audit),
      );
    },
  );

  testWidgets(
    'PDF preview requests the existing controller and retains download errors',
    (tester) async {
      repository.pdfUrl = '';
      await mount(tester);
      await tester.tap(
        find.text(AppStrings.performanceReportSelectCertifiedReport),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(repository.pdfRequests, 1);
      expect(find.text('Unable to open certified report PDF.'), findsOneWidget);
      expect(find.text('Certified Reports'), findsOneWidget);
    },
  );

  testWidgets(
    'unassigned and message-only reports keep their dedicated feedback',
    (tester) async {
      repository.buildReport = (profile) => PerformanceReportModel.fromApiJson({
        'message': 'Unassigned seat',
      }, fallbackProfile: profile);
      await audit.initializePerformanceReport(reportProfile);
      await mount(tester);
      expect(
        find.text(AppStrings.performanceReportOpenSeatTitle),
        findsOneWidget,
      );
      expect(find.text('Unassigned seat'), findsOneWidget);
      expect(find.byType(PerformanceReportCommitmentCard), findsNothing);
      repository.buildReport = (profile) => reportFixture(
        profile: profile,
        snapshot: {
          'selected_profile': {'uuid': 'employee'},
          'categories': [],
          'message': 'No completed check-ins yet.',
        },
      );
      await audit.initializePerformanceReport(reportProfile);
      await tester.pumpAndSettle();
      expect(find.text('No completed check-ins yet.'), findsOneWidget);
      expect(
        find.text(AppStrings.performanceReportOpenSeatTitle),
        findsNothing,
      );
      expect(find.byType(PerformanceReportCommitmentCard), findsNothing);
    },
  );
}
