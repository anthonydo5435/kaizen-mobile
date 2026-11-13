import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_audit_report_comments.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_final_audit_report.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_media_comments_bottom_sheet.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/seat_description_final_check_in_report.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/seat_description_final_check_in_report_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

import '../../support/final_check_in_report_fixtures.dart';

void main() {
  late FinalCheckInReportRepository repository;
  late CheckInController checkIn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    repository = FinalCheckInReportRepository();
    checkIn = finalReportCheckInController(repository);
  });
  tearDown(() {
    checkIn.dispose();
    AppManager.instance.resetSessionState();
  });

  Widget screen({double scale = 1, String descriptionId = 'description'}) =>
      ChangeNotifierProvider<CheckInController>.value(
        value: checkIn,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SeatDescriptionFinalCheckInReportScreen(
            flowFirstId: 'flow',
            profileUuid: 'profile',
            descriptionId: descriptionId,
            quarter: 3,
            year: 2026,
          ),
        ),
      );

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(scale: scale));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'rendered report retains cards, chart, search and range selection ($scale)',
      (tester) async {
        repository.report = finalCheckInReport(
          trends: [finalReportTrend(week: 3, great: 7)],
        );
        repository.profiles = [
          finalReportProfile('Alice'),
          finalReportProfile('Bob'),
        ];
        repository.comments = [
          finalReportComment(text: 'Safety verified'),
          finalReportComment(
            id: 'video',
            text: 'Video evidence',
            type: 'video',
          ),
        ];
        await mount(tester, scale: scale);
        expect(find.text('Alice, Bob'), findsOneWidget);
        expect(find.text('Observation'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        final chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups, hasLength(13));
        expect(chart.data.barGroups[2].barRods.single.toY, 7);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), ' SAFETY ');
        await tester.pumpAndSettle();
        expect(find.text('Safety verified'), findsOneWidget);
        expect(find.text('Video evidence'), findsNothing);
        await tester.enterText(find.byType(TextField), 'unmatched');
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.finalCheckInReportNoComments),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'video');
        await tester.pumpAndSettle();
        repository.report = finalCheckInReport(
          trends: [finalReportTrend(year: 2026, quarter: 'Q3', great: 9)],
        );
        await tester.tap(
          find.byType(DropdownButton<FinalCheckInReportTimeRange>),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(AppStrings.finalCheckInReportLastFourQuarters).last,
        );
        await tester.pumpAndSettle();
        expect(repository.requests.last.timeRange, 'last_four_quarters');
        expect(repository.requests.last.quarter, isNull);
        expect(repository.requests.last.year, isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'video',
        );
        expect(find.text('Safety verified'), findsNothing);
        expect(find.text('Video evidence'), findsOneWidget);
        final quarterlyChart = tester.widget<BarChart>(find.byType(BarChart));
        expect(quarterlyChart.data.barGroups.single.barRods.single.toY, 9);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'report loading, failure and retry use the existing feedback flow',
    (tester) async {
      final response = Completer<SeatDescriptionFinalAuditReport>();
      repository.pendingReports.add(response.future);
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      response.completeError(StateError('Failed'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.finalCheckInReportLoadError), findsOneWidget);
      await tester.tap(find.text(AppStrings.finalCheckInReportTryAgain));
      await tester.pumpAndSettle();
      expect(find.text('Operator'), findsOneWidget);
      expect(repository.requests, hasLength(6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comments can finish after the report and closing cancels notifications',
    (tester) async {
      final comments = Completer<SeatDescriptionAuditReportComments>();
      repository.pendingComments.add(comments.future);
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.text('Operator'), findsOneWidget);
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      comments.complete(
        SeatDescriptionAuditReportComments(items: [finalReportComment()]),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing report inputs reloads the owning controller', (
    tester,
  ) async {
    await mount(tester);
    repository.report = finalCheckInReport(title: 'Another seat');
    await tester.pumpWidget(screen(descriptionId: 'another-description'));
    await tester.pumpAndSettle();
    expect(find.text('Another seat'), findsOneWidget);
    expect(repository.requests.last.descriptionId, 'another-description');
    expect(repository.requests, hasLength(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment taps keep the original media UUID and read-only sheet', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'uuid': 'audit-media',
          'comments': [],
          'total_comments': 0,
        }),
        200,
      ),
    );
    addTearDown(client.close);
    repository.comments = [
      finalReportComment(id: 'audit-media', text: 'Open evidence'),
    ];
    await http.runWithClient(() async {
      await mount(tester);
      await tester.ensureVisible(find.text('Open evidence'));
      await tester.tap(find.text('Open evidence'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<CheckInMediaCommentsBottomSheet>(
        find.byType(CheckInMediaCommentsBottomSheet),
      );
      expect(sheet.selectedMedia.uuid, 'audit-media');
      expect(sheet.mediaList.single.uuid, 'audit-media');
      expect(sheet.isReadOnly, isTrue);
      expect(sheet.canReply, isFalse);
      expect(sheet.canDelete, isFalse);
      expect(find.text(AppStrings.auditMediaUploadPrompt), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets(
    'View Trainings keeps its route, selected lesson and editing permission',
    (tester) async {
      final navigator = GlobalKey<_RouteRecordingNavigatorState>();
      AppManager.instance.updateCurrentUser(User(isOwner: true));
      await tester.pumpWidget(
        ChangeNotifierProvider<CheckInController>.value(
          value: checkIn,
          child: MaterialApp(
            home: _RouteRecordingNavigator(
              key: navigator,
              home: const SeatDescriptionFinalCheckInReportScreen(
                flowFirstId: 'flow',
                descriptionId: 'description',
                quarter: 3,
                year: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.text(AppStrings.seatProfileViewTrainings);
      await tester.ensureVisible(action);
      await tester.tap(action);
      final route =
          navigator.currentState!.pushedRoute! as MaterialPageRoute<void>;
      final training =
          route.builder(tester.element(action)) as EditTrainingScreen;
      expect(training.trainingRoute.job, 'seat');
      expect(training.trainingRoute.description, 'description');
      expect(training.initialModuleId, 'lesson');
      expect(training.canManageTraining, isTrue);
      expect(training.useNonBlockingVideoUpload, isTrue);
      route.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

// Capture navigation without initializing an unrelated native training player.
class _RouteRecordingNavigator extends Navigator {
  _RouteRecordingNavigator({super.key, required Widget home})
    : super(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => home),
      );

  @override
  NavigatorState createState() => _RouteRecordingNavigatorState();
}

class _RouteRecordingNavigatorState extends NavigatorState {
  Route<Object?>? pushedRoute;

  @override
  Future<T?> push<T extends Object?>(Route<T> route) {
    pushedRoute = route;
    return Future<T?>.value();
  }
}
