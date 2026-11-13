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
import 'package:sparrowkaizen/core/constants/app_colors.dart';
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
import 'package:sparrowkaizen/features/check_in/presentation/pages/performance_report_certified_reports_sheet.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_report_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_report_commitment_card.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_report_persona_card.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/performance_report_selectors.dart';
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

  Future<void> mount(
    WidgetTester tester, {
    bool isMyReport = false,
    List<NavigatorObserver> observers = const [],
  }) async {
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
        child: MaterialApp(
          navigatorObservers: observers,
          home: PerformanceReportView(isMyReport: isMyReport),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<DateTimeRange> applyEarlierDates(WidgetTester tester) async {
    final quarter = controller.currentQuarterRange;
    final start = DateTime(quarter.start.year, quarter.start.month - 1, 1);
    final end = DateTime(start.year, start.month, 2);
    final requestsBefore = repository.overviewProfiles.length;
    await tester.tap(find.byType(PerformanceReportTimeRangeSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(start)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(end)));
    await tester.pump();
    expect(repository.overviewProfiles.length, requestsBefore);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repository.overviewProfiles.length, requestsBefore + 1);
    expect(repository.lastStart, start);
    expect(repository.lastEnd, end);
    return DateTimeRange(start: start, end: end);
  }

  Future<DateTimeRange> draftHistoryDates(
    WidgetTester tester, {
    DateTimeRange? selectedRange,
  }) async {
    await tester.tap(
      find.byKey(const ValueKey('performance-report-history-date-filter')),
    );
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    final apply = find.widgetWithText(FilledButton, 'Apply');
    if (selectedRange != null) {
      final localizations = MaterialLocalizations.of(tester.element(dialog));
      expect(
        find.text(localizations.formatShortDate(selectedRange.start)),
        findsWidgets,
      );
      expect(
        find.text(localizations.formatShortDate(selectedRange.end)),
        findsWidgets,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Select')),
        findsNothing,
      );
      expect(find.text(AppStrings.performanceReportClearDates), findsOneWidget);
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      for (
        var day = selectedRange.start;
        !day.isAfter(selectedRange.end);
        day = day.add(const Duration(days: 1))
      ) {
        final cell = find.byKey(ValueKey(day));
        final container = tester.widget<Container>(
          find.descendant(of: cell, matching: find.byType(Container)),
        );
        expect(
          (container.decoration as BoxDecoration).color,
          AppColors.secondaryColor,
        );
      }
      return selectedRange;
    }
    expect(find.text(AppStrings.performanceReportClearDates), findsNothing);
    expect(
      find.descendant(of: dialog, matching: find.text('Select')),
      findsNWidgets(2),
    );
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    final today = controller.currentQuarterRange.end;
    final start = DateTime(today.year, today.month, 1);
    final end = DateTime(today.year, today.month, today.day > 1 ? 2 : 1);
    await tester.tap(find.byKey(ValueKey(start)));
    await tester.pump();
    expect(find.text(AppStrings.performanceReportClearDates), findsOneWidget);
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await tester.tap(find.byKey(ValueKey(end)));
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
    return DateTimeRange(start: start, end: end);
  }

  testWidgets(
    'production history renders the paginated reports response without Current Report',
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
          await tester.tap(
            find.byTooltip(AppStrings.performanceReportAllReports),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(AppStrings.performanceReportHistoryTitle),
            findsOneWidget,
          );
          expect(
            find.text(AppStrings.performanceReportHistoryItemTitle),
            findsOneWidget,
          );
          expect(find.text('Oct 01, 2026 - Oct 16, 2026'), findsOneWidget);
          expect(
            find.text('Created at: Oct 16, 2026 08:06 PM'),
            findsOneWidget,
          );
          expect(find.text('Current Report'), findsNothing);
          expect(
            find.byTooltip(AppStrings.performanceReportReadReport),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          paths.add(request.url.path.replaceFirst('/api/v1/', ''));
          if (request.url.path.endsWith(
            ApiEndPoints.auditReportCertifiedReports('profile-job'),
          )) {
            expect(request.url.queryParameters, {
              'profile_uuid': 'employee',
              'page': '1',
            });
            return http.Response(
              jsonEncode({
                'count': 1,
                'next': null,
                'previous': null,
                'current': 1,
                'results': [
                  {
                    'uuid': '684668fc-6fad-417e-adfe-82e6bdd702f4',
                    'created_at': 'Oct 16, 2026 08:06 PM',
                    'date_range': 'Oct 01, 2026 - Oct 16, 2026',
                  },
                ],
              }),
              200,
            );
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

  testWidgets('the date control opens the preselected purple quarter range', (
    tester,
  ) async {
    await mount(tester);
    final range = controller.currentQuarterRange;
    expect(controller.dateRange, range);
    expect(find.text(controller.dateRangeLabel), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(
      find.text(AppStrings.performanceReportSelectCertifiedReport),
      findsNothing,
    );
    expect(
      tester
          .getTopLeft(find.byTooltip(AppStrings.performanceReportAllReports))
          .dx,
      greaterThan(
        tester.getTopRight(find.byType(PerformanceReportTimeRangeSelector)).dx,
      ),
    );
    final requestsBefore = repository.overviewProfiles.length;
    await tester.tap(find.byType(PerformanceReportTimeRangeSelector));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.performanceReportChooseDateRange),
      findsOneWidget,
    );
    expect(find.text(AppStrings.performanceReportThisQuarter), findsNothing);
    var month = range.start;
    while (!month.isAfter(range.end)) {
      final endOfMonth = DateTime(month.year, month.month + 1, 0);
      final last = endOfMonth.isBefore(range.end) ? endOfMonth : range.end;
      for (
        var day = month;
        !day.isAfter(last);
        day = day.add(const Duration(days: 1))
      ) {
        final cell = find.byKey(ValueKey(day));
        final container = tester.widget<Container>(
          find.descendant(of: cell, matching: find.byType(Container)),
        );
        expect(
          (container.decoration as BoxDecoration).color,
          AppColors.secondaryColor,
        );
      }
      month = DateTime(month.year, month.month + 1, 1);
      if (!month.isAfter(range.end)) {
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();
      }
    }
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(repository.overviewProfiles.length, requestsBefore);
    expect(controller.dateRange, range);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar changes apply on Apply and reopen with the selected dates',
    (tester) async {
      await mount(tester);
      final quarter = controller.currentQuarterRange;
      final start = DateTime(quarter.start.year, quarter.start.month - 1, 1);
      final end = DateTime(start.year, start.month, 2);
      await tester.tap(find.byType(PerformanceReportTimeRangeSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(start)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(end)));
      await tester.pump();
      expect(repository.lastStart, isNull);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.lastStart, start);
      expect(repository.lastEnd, end);
      expect(controller.dateRange, DateTimeRange(start: start, end: end));
      expect(find.text(controller.dateRangeLabel), findsOneWidget);
      await tester.tap(find.byType(PerformanceReportTimeRangeSelector));
      await tester.pumpAndSettle();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(Dialog)),
      );
      expect(find.text(localizations.formatShortDate(start)), findsOneWidget);
      expect(find.text(localizations.formatShortDate(end)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(quarter.start)));
      await tester.pump();
      var month = quarter.start.month;
      while (month < quarter.end.month) {
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();
        month++;
      }
      await tester.tap(find.byKey(ValueKey(quarter.end)));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.lastStart, isNull);
      expect(repository.lastQuarter, isNotNull);
      expect(controller.dateRange, quarter);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date and history controls fit a narrow screen with scaled text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: Row(
                  children: [
                    Expanded(
                      child: PerformanceReportTimeRangeSelector(
                        label: controller.dateRangeLabel,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) => PerformanceReportHistoryButton(
                        onPressed: () =>
                            showPerformanceReportCertifiedReportsSheet(
                              context,
                              value: null,
                              options: const [],
                              minDate: DateTime(2025),
                              maxDate: controller.currentQuarterRange.end,
                              loadReports: (_) async => [],
                              isDownloading: (_) => false,
                              onChanged: (_) {},
                              onDownload: (_) async => '',
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(PerformanceReportTimeRangeSelector)).height,
        greaterThan(45),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.performanceReportAllReports), findsOneWidget);
      expect(
        find.text(AppStrings.performanceReportHistoryTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.performanceReportHistoryEmpty),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history reopens applied dates with the range selected without changing the main report',
    (tester) async {
      await mount(tester);
      final report = controller.report;
      final mainRange = controller.dateRange;
      final overviewCount = repository.overviewProfiles.length;
      final pending = Completer<List<CertifiedReportOption>>();
      repository.pendingCertifiedReports = pending.future;
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.performanceReportHistoryTitle),
        findsOneWidget,
      );
      expect(find.text(AppStrings.performanceReportAllReports), findsOneWidget);
      expect(
        find.byKey(const ValueKey('performance-report-history-certified')),
        findsOneWidget,
      );
      final requestCount = repository.certifiedReportRequests.length;
      final range = await draftHistoryDates(tester);
      expect(repository.certifiedReportRequests.length, requestCount);
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(repository.certifiedReportRequests.length, requestCount + 1);
      final request = repository.certifiedReportRequests.last;
      expect(request.profile.profileUuid, 'employee');
      expect(request.profile.profileJob, 'profile-job');
      expect(request.start, range.start);
      expect(request.end, range.end);
      expect(request.forceRefresh, isTrue);
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('performance-report-history-date-filter')),
        findsOneWidget,
      );
      pending.complete(const [
        CertifiedReportOption(uuid: 'filtered', displayName: 'Filtered report'),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('performance-report-history-filtered')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('performance-report-history-certified')),
        findsNothing,
      );
      expect(controller.report, same(report));
      expect(controller.dateRange, mainRange);
      expect(repository.overviewProfiles.length, overviewCount);

      await draftHistoryDates(tester, selectedRange: range);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(repository.certifiedReportRequests.length, requestCount + 1);
      expect(
        find.byKey(const ValueKey('performance-report-history-filtered')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('performance-report-history-filtered')),
      );
      await tester.pumpAndSettle();
      expect(repository.detailRequests, ['filtered']);
      expect(controller.isCommitmentReadOnly, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history uses three quarters of the parent and silently refreshes on every open',
    (tester) async {
      await mount(tester);
      final requestCount = repository.certifiedReportRequests.length;
      final pending = Completer<List<CertifiedReportOption>>();
      repository.pendingCertifiedReports = pending.future;
      for (var opening = 1; opening <= 2; opening++) {
        await tester.tap(
          find.byTooltip(AppStrings.performanceReportAllReports),
        );
        await tester.pumpAndSettle();
        expect(
          repository.certifiedReportRequests.length,
          requestCount + opening,
        );
        final request = repository.certifiedReportRequests.last;
        expect(request.forceRefresh, isTrue);
        expect(request.start, isNull);
        expect(request.end, isNull);
        expect(find.byType(FastCircularProgressIndicator), findsNothing);
        expect(
          find.byKey(const ValueKey('performance-report-history-certified')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('performance-reports-sheet')))
              .height,
          closeTo(900 * 0.75, 0.1),
        );
        final readButton = find.byTooltip(
          AppStrings.performanceReportReadReport,
        );
        expect(readButton, findsOneWidget);
        expect(tester.getSize(readButton), const Size(40, 40));
        final material = tester.widget<Material>(
          find.descendant(of: readButton, matching: find.byType(Material)),
        );
        expect(
          material.color,
          AppColors.secondaryColor.withValues(alpha: 0.14),
        );
        if (opening == 1) {
          await tester.tap(find.byIcon(Icons.close_rounded));
          await tester.pumpAndSettle();
        }
      }
      pending.complete(const [
        CertifiedReportOption(uuid: 'fresh', displayName: 'Fresh report'),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('performance-report-history-fresh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('performance-report-history-certified')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Clear Dates dismisses the calendar and reloads the default history list',
    (tester) async {
      repository.buildCertifiedReports = (start, end) => [
        CertifiedReportOption(
          uuid: start == null ? 'all' : 'filtered',
          displayName: start == null ? 'All-time report' : 'Filtered report',
        ),
      ];
      await mount(tester);
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      final range = await draftHistoryDates(tester);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('performance-report-history-filtered')),
        findsOneWidget,
      );
      await draftHistoryDates(tester, selectedRange: range);
      final clear = find.text(AppStrings.performanceReportClearDates);
      expect(
        tester.getTopLeft(clear).dx,
        lessThan(tester.getTopLeft(find.text('Apply')).dx),
      );
      final requestsBefore = repository.certifiedReportRequests.length;
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(AppStrings.performanceReportAllReports), findsOneWidget);
      expect(
        find.byKey(const ValueKey('performance-report-history-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('performance-report-history-filtered')),
        findsNothing,
      );
      expect(repository.certifiedReportRequests.length, requestsBefore + 1);
      expect(repository.certifiedReportRequests.last.start, isNull);
      expect(repository.certifiedReportRequests.last.end, isNull);
      expect(repository.certifiedReportRequests.last.forceRefresh, isTrue);
      await draftHistoryDates(tester);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(repository.certifiedReportRequests.length, requestsBefore + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history keeps its date filter for empty and failed list requests',
    (tester) async {
      await mount(tester);
      repository.buildCertifiedReports = (_, __) => [];
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      final range = await draftHistoryDates(tester);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.performanceReportHistoryEmpty),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('performance-report-history-date-filter')),
        findsOneWidget,
      );
      repository.buildCertifiedReports = (_, __) =>
          throw StateError('Unavailable');
      await draftHistoryDates(tester, selectedRange: range);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.performanceReportHistoryLoadFailed),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.performanceReportHistoryEmpty),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('performance-report-history-date-filter')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('archived reports synchronize comments and remain read only', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(AppStrings.performanceReportReadReport),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('performance-report-history-certified')),
    );
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

  testWidgets(
    'date controls hide while loading and return for a failed report',
    (tester) async {
      await mount(tester);
      final pending = Completer<PerformanceReport>();
      repository.pendingOverview = pending.future;
      final loading = audit.initializePerformanceReport(reportProfile);
      await tester.pump();
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(find.byType(PerformanceReportTimeRangeSelector), findsNothing);
      expect(
        find.byTooltip(AppStrings.performanceReportAllReports),
        findsNothing,
      );
      pending.completeError(StateError('Unavailable'));
      await loading;
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.performanceReportUnavailable),
        findsOneWidget,
      );
      expect(find.byType(PerformanceReportTimeRangeSelector), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.performanceReportAllReports),
        findsOneWidget,
      );
      repository.pendingOverview = null;
      final range = await applyEarlierDates(tester);
      expect(controller.dateRange, range);
      expect(repository.overviewProfiles.last, reportProfile);
      expect(find.text('Daily delivery'), findsOneWidget);
      expect(find.text(AppStrings.performanceReportUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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

  testWidgets('reading a report keeps the filtered history sheet mounted', (
    tester,
  ) async {
    final observer = _ReportsNavigationObserver();
    await mount(tester, observers: [observer]);
    await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
    await tester.pumpAndSettle();
    await draftHistoryDates(tester);
    await tester.tap(find.text(AppStrings.performanceReportApply));
    await tester.pumpAndSettle();
    final sheetFinder = find.byKey(const ValueKey('performance-reports-sheet'));
    final filterFinder = find.byKey(
      const ValueKey('performance-report-history-date-filter'),
    );
    final sheet = tester.element(sheetFinder);
    final label = tester
        .widget<PerformanceReportTimeRangeSelector>(filterFinder)
        .label;
    final requestsBefore = repository.certifiedReportRequests.length;
    final historyRoute = observer.pushed
        .whereType<ModalBottomSheetRoute<void>>()
        .single;

    await tester.tap(find.byTooltip(AppStrings.performanceReportReadReport));
    // Inspect the navigation stack before the native PDF renderer is mounted.
    await tester.idle();
    expect(repository.pdfRequests, 1);
    expect(observer.popped, isNot(contains(historyRoute)));
    expect(observer.pushed.last, isA<MaterialPageRoute<void>>());
    expect(observer.pushed.last, isNot(same(historyRoute)));
    observer.navigator!.pop();
    await tester.pumpAndSettle();

    expect(tester.element(sheetFinder), same(sheet));
    expect(
      tester.widget<PerformanceReportTimeRangeSelector>(filterFinder).label,
      label,
    );
    expect(
      find.byKey(const ValueKey('performance-report-history-certified')),
      findsOneWidget,
    );
    expect(repository.certifiedReportRequests.length, requestsBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PDF preview requests the existing controller and retains download errors',
    (tester) async {
      repository.pdfUrl = '';
      await mount(tester);
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.performanceReportReadReport));
      await tester.pumpAndSettle();
      expect(repository.pdfRequests, 1);
      expect(find.text('Unable to open certified report PDF.'), findsOneWidget);
      expect(
        find.text(AppStrings.performanceReportHistoryTitle),
        findsOneWidget,
      );
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
      expect(find.byType(PerformanceReportTimeRangeSelector), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.performanceReportAllReports));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.performanceReportHistoryTitle),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
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
      expect(find.byType(PerformanceReportTimeRangeSelector), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.performanceReportAllReports),
        findsOneWidget,
      );
      repository.buildReport = (profile) => reportFixture(profile: profile);
      await applyEarlierDates(tester);
      expect(find.text('Daily delivery'), findsOneWidget);
      expect(find.text('No completed check-ins yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty responses retain the date row and request another range', (
    tester,
  ) async {
    repository.buildReport = (profile) =>
        PerformanceReportModel.fromApiJson({}, fallbackProfile: profile);
    await audit.initializePerformanceReport(reportProfile);
    await mount(tester);
    expect(find.byType(PerformanceReportTimeRangeSelector), findsOneWidget);
    expect(
      find.byTooltip(AppStrings.performanceReportAllReports),
      findsOneWidget,
    );
    repository.buildReport = (profile) => reportFixture(profile: profile);
    await applyEarlierDates(tester);
    expect(
      repository.overviewProfiles.last.profileUuid,
      reportProfile.profileUuid,
    );
    expect(find.text('Daily delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ReportsNavigationObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  final popped = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }
}
