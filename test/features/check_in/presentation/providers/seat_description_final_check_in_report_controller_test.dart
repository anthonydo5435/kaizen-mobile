import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_audit_report_comments.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_final_audit_report.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/seat_description_final_check_in_report_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user_hierarchy_membership.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';

import '../../support/final_check_in_report_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FinalCheckInReportRepository repository;
  late CheckInController checkIn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    repository = FinalCheckInReportRepository();
    checkIn = finalReportCheckInController(repository);
    AppManager.instance.resetSessionState();
  });
  tearDown(() {
    checkIn.dispose();
    AppManager.instance.resetSessionState();
  });

  SeatDescriptionFinalCheckInReportController create({
    String? profileUuid = 'profile',
  }) => SeatDescriptionFinalCheckInReportController(
    checkInController: checkIn,
    flowFirstId: 'flow',
    profileUuid: profileUuid,
    descriptionId: 'description',
    quarter: 3,
    year: 2026,
  );

  test(
    'all three endpoints retain quarter and range request contracts',
    () async {
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      for (final range in [
        FinalCheckInReportTimeRange.selectedQuarter,
        FinalCheckInReportTimeRange.thisQuarter,
        FinalCheckInReportTimeRange.lastFourQuarters,
        FinalCheckInReportTimeRange.allTime,
        FinalCheckInReportTimeRange.selectedQuarter,
      ]) {
        await controller.selectTimeRange(range);
        final calls = repository.requests
            .skip(repository.requests.length - 3)
            .toList();
        expect(calls.map((call) => call.endpoint), [
          'report',
          'comments',
          'profiles',
        ]);
        for (final call in calls) {
          expect(call.flowFirstId, 'flow');
          expect(call.profileUuid, 'profile');
          expect(call.descriptionId, 'description');
          expect(call.quarter, range.apiValue == null ? 3 : null);
          expect(call.year, range.apiValue == null ? 2026 : null);
          expect(call.timeRange, range.apiValue);
        }
      }
      final count = repository.requests.length;
      await controller.selectTimeRange(null);
      await controller.selectTimeRange(controller.timeRange);
      expect(repository.requests, hasLength(count));
      await controller.refresh();
      expect(repository.requests, hasLength(count + 3));
    },
  );

  test(
    'search matches text and media type and survives range changes',
    () async {
      repository.comments = [
        finalReportComment(id: 'text', text: 'Safety Verified'),
        finalReportComment(id: 'video', text: 'Evidence', type: 'Video'),
      ];
      final controller = create(profileUuid: null);
      addTearDown(controller.dispose);
      await controller.ready;
      expect(
        repository.requests.every((request) => request.profileUuid == null),
        isTrue,
      );
      controller.updateCommentsQuery('  SAFETY  ');
      expect(controller.comments.single.media.uuid, 'text');
      controller.updateCommentsQuery(' VIDEO ');
      expect(controller.comments.single.media.uuid, 'video');
      await controller.selectTimeRange(FinalCheckInReportTimeRange.allTime);
      expect(controller.comments.single.media.uuid, 'video');
      controller.updateCommentsQuery('no matches');
      expect(controller.comments, isEmpty);
      expect(controller.hasComments, isTrue);
      controller.updateCommentsQuery(' ');
      expect(controller.comments, hasLength(2));
    },
  );

  test(
    'identity, fallback and rating data preserve report display rules',
    () async {
      repository.profiles = [
        ' Alice ',
        ' ',
        'Bob',
        'Cara',
      ].map(finalReportProfile).toList();
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.profileNames, 'Alice, Bob +1');
      expect(controller.auditFactorLabel, 'Observation');
      expect(
        controller.seatTypeLabel,
        AppStrings.finalCheckInReportAssignedSeat,
      );
      expect(controller.confidenceLevel, '75%');
      expect(controller.performancePercentage, '85%');
      expect(controller.ratings.map((rating) => rating.ratio), [0.8, 0.1, 0.1]);
      repository.report = finalCheckInReport(
        title: '',
        description: '',
        specifics: '',
        auditFactor: '',
        isOpenSeat: true,
        stats: const SeatDescriptionFinalAuditStats(
          totalGreat: 0,
          totalAlmostThere: 0,
          totalNeedsImprovement: 0,
          totalPercentage: 0,
          confidenceLevel: 0,
        ),
      );
      repository.profiles = [];
      await controller.refresh();
      expect(controller.seatTitle, '-');
      expect(controller.profileNames, '-');
      expect(controller.auditFactorLabel, '-');
      expect(controller.description, 'No Description available.');
      expect(controller.specifics, 'No Specifics available.');
      expect(controller.seatTypeLabel, AppStrings.finalCheckInReportOpenSeat);
      expect(controller.ratings.every((rating) => rating.ratio == 0), isTrue);
      repository.profiles = [finalReportProfile(' Alice ')];
      await controller.refresh();
      expect(controller.profileNames, 'Alice');
      repository.profiles.add(finalReportProfile('Bob'));
      await controller.refresh();
      expect(controller.profileNames, 'Alice, Bob');
    },
  );

  test('weekly charts keep 13 slots, sorted valid data and stacked totals', () {
    final original = [
      finalReportTrend(
        week: 3,
        great: 191,
        almostThere: 10,
        needsImprovement: 1,
      ),
      finalReportTrend(week: 0, great: 999),
      finalReportTrend(week: 1, great: 2),
    ];
    final data = FinalCheckInReportTrendData.fromTrends(
      original,
      FinalCheckInReportTimeRange.thisQuarter,
    );
    expect(data.points.map((point) => point.x), [1, 3]);
    expect(original.first.week, 3);
    expect(data.bars, hasLength(13));
    expect(data.bars[1].total, 0);
    expect(data.bars[2].almostThereEnd, 201);
    expect(data.bars[2].total, 202);
    expect(data.axisLabel(13), 'w13');
    expect(data.axisLabel(0), '');
    expect(data.maxY, 220);
    expect(data.interval, 25);
  });

  test(
    'quarter charts sort by year then quarter and reject incomplete rows',
    () {
      final data = FinalCheckInReportTrendData.fromTrends([
        finalReportTrend(year: 2026, quarter: 'Q3'),
        finalReportTrend(year: 2025, quarter: 'Q4'),
        finalReportTrend(year: 2026, quarter: 'q1'),
        finalReportTrend(year: null, quarter: 'Q2', great: 900),
        finalReportTrend(year: 2025, quarter: '', great: 900),
      ], FinalCheckInReportTimeRange.lastFourQuarters);
      expect(data.usesQuarterLayout, isTrue);
      expect(data.bars.map((point) => point.label), [
        'Q4\n2025',
        'q1\n2026',
        'Q3\n2026',
      ]);
      expect(data.bars.map((point) => point.x), [0, 1, 2]);
      expect(data.maxY, 100);
      expect(data.interval, 10);
      expect(data.axisLabel(-1), '');
      expect(data.axisLabel(3), '');
      final medium = FinalCheckInReportTrendData.fromTrends([
        finalReportTrend(great: 101),
      ], FinalCheckInReportTimeRange.selectedQuarter);
      expect(medium.maxY, 120);
      expect(medium.interval, 20);
    },
  );

  test(
    'comment display keeps media types, thumbnail fallback and comment UUID',
    () {
      final video = FinalCheckInReportCommentData.fromComment(
        finalReportComment(
          id: 'audit-media',
          text: '  ',
          type: ' VIDEO ',
          media: 'video.mp4',
          thumbnail: 'thumb.jpg',
        ),
      );
      expect(video.isVideo, isTrue);
      expect(video.hasMedia, isTrue);
      expect(video.thumbnailUrl, 'thumb.jpg');
      expect(video.text, AppStrings.noComment);
      expect(video.canOpenComments, isTrue);
      expect(video.media.uuid, 'audit-media');
      expect(video.media.type, ' VIDEO ');
      expect(video.media.comment, '  ');
      expect(video.media.unreadCount, 0);
      final screen = FinalCheckInReportCommentData.fromComment(
        finalReportComment(type: 'screen_recording'),
      );
      expect(screen.isVideo, isTrue);
      expect(screen.thumbnailUrl, isNull);
      final text = FinalCheckInReportCommentData.fromComment(
        finalReportComment(id: ' ', thumbnail: ' '),
      );
      expect(text.canOpenComments, isFalse);
      expect(text.isVideo, isFalse);
      expect(text.hasMedia, isFalse);
      expect(text.thumbnailUrl, isNull);
      final image = FinalCheckInReportCommentData.fromComment(
        finalReportComment(type: 'image', media: 'image.jpg'),
      );
      expect(image.isVideo, isFalse);
      expect(image.hasMedia, isTrue);
    },
  );

  test(
    'ancillary failures before report completion do not hide the report',
    () async {
      final report = Completer<SeatDescriptionFinalAuditReport>();
      repository.pendingReports.add(report.future);
      repository.failComments = true;
      repository.failProfiles = true;
      final controller = create();
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isLoading, isTrue);
      expect(controller.isLoadingComments, isFalse);
      report.complete(finalCheckInReport());
      await controller.ready;
      expect(controller.hasReport, isTrue);
      expect(controller.hasLoadError, isFalse);
      expect(controller.comments, isEmpty);
      expect(controller.profileNames, '-');
    },
  );

  test(
    'report failures stop loading and retry reloads all endpoints',
    () async {
      repository.failReport = true;
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.isLoading, isFalse);
      expect(controller.hasLoadError, isTrue);
      repository.failReport = false;
      await controller.refresh();
      expect(controller.hasLoadError, isFalse);
      expect(controller.hasReport, isTrue);
      expect(repository.requests, hasLength(6));
    },
  );

  test(
    'late responses from an old range cannot overwrite the latest report',
    () async {
      final report = Completer<SeatDescriptionFinalAuditReport>();
      final comments = Completer<SeatDescriptionAuditReportComments>();
      final profiles = Completer<List<SeatDescriptionFinalAuditProfile>>();
      repository.pendingReports.add(report.future);
      repository.pendingComments.add(comments.future);
      repository.pendingProfiles.add(profiles.future);
      final controller = create();
      addTearDown(controller.dispose);
      repository.report = finalCheckInReport(title: 'Newest');
      repository.comments = [finalReportComment(text: 'Newest comment')];
      repository.profiles = [finalReportProfile('Newest profile')];
      await controller.selectTimeRange(FinalCheckInReportTimeRange.allTime);
      report.complete(finalCheckInReport(title: 'Old'));
      comments.complete(const SeatDescriptionAuditReportComments(items: []));
      profiles.complete([]);
      await controller.ready;
      expect(controller.timeRange, FinalCheckInReportTimeRange.allTime);
      expect(controller.seatTitle, 'Newest');
      expect(controller.profileNames, 'Newest profile');
      expect(controller.comments.single.text, 'Newest comment');
      expect(controller.trendData.usesQuarterLayout, isTrue);
    },
  );

  test(
    'disposing during requests prevents late notifications and data changes',
    () async {
      final report = Completer<SeatDescriptionFinalAuditReport>();
      repository.pendingReports.add(report.future);
      final controller = create();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      report.complete(finalCheckInReport());
      await controller.ready;
      expect(notifications, 0);
      expect(controller.hasReport, isFalse);
      await controller.refresh();
      expect(repository.requests, hasLength(3));
    },
  );

  test(
    'training validity and editing access remain separate decisions',
    () async {
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.trainingRoute?.initialModuleId, 'lesson');
      expect(controller.canManageTraining, isFalse);
      AppManager.instance.updateCurrentUser(User(isOwner: true));
      expect(controller.canManageTraining, isTrue);
      AppManager.instance.updateCurrentUser(User(hasSandboxAccess: true));
      expect(controller.canManageTraining, isFalse);
      AppManager.instance.updateCurrentUser(
        User(
          roles: const ['team_lead'],
          hierarchyMemberships: const [
            UserHierarchyMembership(
              nodeUuid: 'lead',
              role: 'team_lead',
              manageableSeatProfileIds: ['report-seat'],
            ),
          ],
        ),
      );
      expect(controller.canManageTraining, isTrue);
      repository.report = finalCheckInReport(
        route: const SeatDescriptionTrainingRoute(
          job: ' ',
          category: 'category',
          description: 'description',
        ),
      );
      await controller.refresh();
      expect(controller.trainingRoute, isNull);
      repository.report = finalCheckInReport(
        route: const SeatDescriptionTrainingRoute(
          job: 'seat',
          category: '',
          description: 'description',
        ),
      );
      await controller.refresh();
      expect(controller.trainingRoute, isNotNull);
    },
  );
}
