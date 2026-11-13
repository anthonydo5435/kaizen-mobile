import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/seat_description_audit_report_comments.dart';
import '../../domain/entities/seat_description_final_audit_report.dart';
import 'check_in_controller.dart';

enum FinalCheckInReportTimeRange {
  selectedQuarter(AppStrings.finalCheckInReportCurrentQuarterYear, null),
  thisQuarter(AppStrings.performanceReportThisQuarter, 'current_quarter'),
  lastFourQuarters(
    AppStrings.finalCheckInReportLastFourQuarters,
    'last_four_quarters',
  ),
  allTime(AppStrings.finalCheckInReportAllTime, 'all_time');

  const FinalCheckInReportTimeRange(this.label, this.apiValue);

  final String label;
  final String? apiValue;

  bool get usesQuarterLayout => this == lastFourQuarters || this == allTime;
}

typedef _ReportLoader<T> =
    Future<T> Function({
      required String flowFirstId,
      String? profileUuid,
      required String descriptionId,
      int? quarter,
      int? year,
      String? timeRange,
    });

/// Owns report requests and display data, leaving navigation and layout to widgets.
class SeatDescriptionFinalCheckInReportController extends ChangeNotifier {
  SeatDescriptionFinalCheckInReportController({
    required CheckInController checkInController,
    required this.flowFirstId,
    required this.profileUuid,
    required this.descriptionId,
    required this.quarter,
    required this.year,
    AppManager? appManager,
  }) : _checkInController = checkInController,
       _appManager = appManager ?? AppManager.instance {
    ready = refresh();
  }

  final CheckInController _checkInController;
  final AppManager _appManager;
  final String flowFirstId;
  final String? profileUuid;
  final String descriptionId;
  final int quarter;
  final int year;
  final commentsSearchController = TextEditingController();
  late final Future<void> ready;

  FinalCheckInReportTimeRange _timeRange =
      FinalCheckInReportTimeRange.selectedQuarter;
  SeatDescriptionFinalAuditReport? _report;
  List<SeatDescriptionFinalAuditProfile> _profiles = const [];
  List<SeatDescriptionAuditReportComment> _comments = const [];
  FinalCheckInReportTrendData _trendData = FinalCheckInReportTrendData.empty();
  String _commentsQuery = '';
  bool _isLoading = true;
  bool _isLoadingComments = true;
  bool _hasLoadError = false;
  bool _isDisposed = false;
  int _loadGeneration = 0;

  FinalCheckInReportTimeRange get timeRange => _timeRange;
  bool get isLoading => _isLoading;
  bool get isLoadingComments => _isLoadingComments;
  bool get hasLoadError => _hasLoadError;
  bool get hasReport => _report != null;
  bool get hasComments => _comments.isNotEmpty;
  FinalCheckInReportTrendData get trendData => _trendData;
  String get seatTitle => _displayValue(_report?.job.title ?? '');
  String get auditFactorLabel {
    final value = _report?.auditFactorType ?? '';
    return value.isEmpty
        ? AppStrings.finalCheckInReportMissingValue
        : '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String get seatTypeLabel => _report?.isOpenSeat == true
      ? AppStrings.finalCheckInReportOpenSeat
      : AppStrings.finalCheckInReportAssignedSeat;
  String get description => _detailText(
    _report?.description ?? '',
    AppStrings.finalCheckInReportDescription,
  );
  String get specifics => _detailText(
    _report?.jobSpecifics ?? '',
    AppStrings.finalCheckInReportSpecifics,
  );
  String get confidenceLevel => AppStrings.finalCheckInReportPercentageValue(
    _report?.summaryData.stats.confidenceLevel ?? 0,
  );
  String get performancePercentage =>
      AppStrings.finalCheckInReportPercentageValue(
        _report?.summaryData.stats.totalPercentage ?? 0,
      );

  String get profileNames {
    final names = _profiles
        .map((profile) => profile.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return AppStrings.finalCheckInReportMissingValue;
    if (names.length == 1) return names.first;
    return AppStrings.finalCheckInReportProfileNames(
      names[0],
      names[1],
      names.length - 2,
    );
  }

  List<FinalCheckInReportRatingData> get ratings {
    final stats = _report?.summaryData.stats;
    final great = stats?.totalGreat ?? 0;
    final almostThere = stats?.totalAlmostThere ?? 0;
    final needsImprovement = stats?.totalNeedsImprovement ?? 0;
    final total = great + almostThere + needsImprovement;
    return [
      FinalCheckInReportRatingData(
        AuditRating.great,
        AppStrings.auditRatingGreat,
        great,
        total,
      ),
      FinalCheckInReportRatingData(
        AuditRating.almostThere,
        AppStrings.auditRatingAlmostThere,
        almostThere,
        total,
      ),
      FinalCheckInReportRatingData(
        AuditRating.needsImprovement,
        AppStrings.auditRatingNeedsImprovement,
        needsImprovement,
        total,
      ),
    ];
  }

  List<FinalCheckInReportCommentData> get comments => _comments
      .where(
        (comment) =>
            _commentsQuery.isEmpty ||
            comment.comment.toLowerCase().contains(_commentsQuery) ||
            (comment.type ?? '').toLowerCase().contains(_commentsQuery),
      )
      .map(FinalCheckInReportCommentData.fromComment)
      .toList(growable: false);

  SeatDescriptionTrainingRoute? get trainingRoute {
    final route = _report?.trainingRoute;
    return route != null &&
            route.job.trim().isNotEmpty &&
            route.description.trim().isNotEmpty
        ? route
        : null;
  }

  bool get canManageTraining =>
      _appManager.canCurrentUserManageTrainingForSeatProfile(
        seatProfileId: trainingRoute?.job ?? '',
        additionalSeatProfileIds: [_report?.job.uuid ?? ''],
      );

  void updateCommentsQuery(String value) {
    final query = value.trim().toLowerCase();
    if (_isDisposed || query == _commentsQuery) return;
    _commentsQuery = query;
    notifyListeners();
  }

  Future<void> selectTimeRange(FinalCheckInReportTimeRange? value) async {
    if (_isDisposed || value == null || value == _timeRange) return;
    _timeRange = value;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isDisposed) return;
    final generation = ++_loadGeneration;
    final range = _timeRange;
    _isLoading = true;
    _isLoadingComments = true;
    _hasLoadError = false;
    _report = null;
    _profiles = const [];
    _comments = const [];
    notifyListeners();
    // Attach handlers immediately, including to ancillary requests that may
    // finish before the report itself. A range change invalidates all three.
    await Future.wait([
      _loadReport(generation, range),
      _loadComments(generation, range),
      _loadProfiles(generation, range),
    ]);
  }

  Future<T> _load<T>(
    _ReportLoader<T> loader,
    FinalCheckInReportTimeRange range,
  ) => loader(
    flowFirstId: flowFirstId,
    profileUuid: profileUuid,
    descriptionId: descriptionId,
    quarter: range.apiValue == null ? quarter : null,
    year: range.apiValue == null ? year : null,
    timeRange: range.apiValue,
  );

  Future<void> _loadReport(
    int generation,
    FinalCheckInReportTimeRange range,
  ) async {
    try {
      final report = await _load(
        _checkInController.loadSeatDescriptionFinalAuditReport,
        range,
      );
      if (!_isCurrent(generation)) return;
      _report = report;
      _trendData = FinalCheckInReportTrendData.fromTrends(
        report.summaryData.trends,
        range,
      );
    } catch (_) {
      if (_isCurrent(generation)) _hasLoadError = true;
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadComments(
    int generation,
    FinalCheckInReportTimeRange range,
  ) async {
    try {
      final response = await _load(
        _checkInController.loadSeatDescriptionAuditReportComments,
        range,
      );
      if (!_isCurrent(generation)) return;
      _comments = response.items;
    } catch (_) {
      // Preserve the existing empty state when comments are unavailable.
      if (_isCurrent(generation)) _comments = const [];
    } finally {
      if (_isCurrent(generation)) {
        _isLoadingComments = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadProfiles(
    int generation,
    FinalCheckInReportTimeRange range,
  ) async {
    try {
      final profiles = await _load(
        _checkInController.loadSeatDescriptionAuditReportProfiles,
        range,
      );
      if (!_isCurrent(generation)) return;
      _profiles = profiles;
    } catch (_) {
      // Profile lookup failure must not hide the rest of the report.
      if (_isCurrent(generation)) _profiles = const [];
    } finally {
      if (_isCurrent(generation)) notifyListeners();
    }
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _loadGeneration;
  static String _displayValue(String value) =>
      value.isEmpty ? AppStrings.finalCheckInReportMissingValue : value;
  static String _detailText(String value, String title) =>
      value.isEmpty ? AppStrings.auditNoStatusAvailable(title) : value;

  @override
  void dispose() {
    _isDisposed = true;
    commentsSearchController.dispose();
    super.dispose();
  }
}

class FinalCheckInReportRatingData {
  const FinalCheckInReportRatingData(
    this.rating,
    this.label,
    this.count,
    this.total,
  );

  final AuditRating rating;
  final String label;
  final int count;
  final int total;
  double get ratio => total == 0 ? 0 : (count / total).clamp(0.0, 1.0);
  String get percentageLabel =>
      AppStrings.finalCheckInReportPercentageValue((ratio * 100).round());
}

class FinalCheckInReportCommentData {
  FinalCheckInReportCommentData.fromComment(
    SeatDescriptionAuditReportComment comment,
  ) : text = comment.comment.trim().isEmpty
          ? AppStrings.noComment
          : comment.comment,
      media = AuditDescriptionMedia(
        uuid: comment.uuid,
        media: comment.media ?? '',
        type: comment.type ?? '',
        comment: comment.comment,
        unreadCount: 0,
      ),
      thumbnailUrl = comment.thumbnailUrl?.trim().isNotEmpty == true
          ? comment.thumbnailUrl
          : null,
      isVideo = const [
        'screen_recording',
        'video',
      ].contains(comment.type?.trim().toLowerCase()),
      hasMedia =
          const [
            'image',
            'video',
            'screen_recording',
          ].contains(comment.type?.trim().toLowerCase()) &&
          comment.media?.trim().isNotEmpty == true;

  final String text;
  final AuditDescriptionMedia media;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool hasMedia;
  bool get canOpenComments => media.uuid.trim().isNotEmpty;
}

/// Numeric and label data for the chart; rendering geometry stays in the UI.
class FinalCheckInReportTrendData {
  const FinalCheckInReportTrendData({
    required this.usesQuarterLayout,
    required this.points,
    required this.bars,
    required this.maxY,
    required this.interval,
  });

  factory FinalCheckInReportTrendData.empty() =>
      const FinalCheckInReportTrendData(
        usesQuarterLayout: false,
        points: [],
        bars: [],
        maxY: 100,
        interval: 10,
      );

  factory FinalCheckInReportTrendData.fromTrends(
    List<SeatDescriptionFinalAuditTrend> trends,
    FinalCheckInReportTimeRange range,
  ) {
    final quarterly = range.usesQuarterLayout;
    final valid =
        trends
            .where(
              (trend) => quarterly
                  ? (trend.quarter ?? '').isNotEmpty && trend.year != null
                  : trend.week > 0,
            )
            .toList(growable: false)
          ..sort((a, b) {
            if (!quarterly) return a.week.compareTo(b.week);
            final year = (a.year ?? 0).compareTo(b.year ?? 0);
            return year != 0
                ? year
                : _quarterOrder(a.quarter).compareTo(_quarterOrder(b.quarter));
          });
    final points = valid.indexed
        .map((entry) {
          final (index, trend) = entry;
          return FinalCheckInReportTrendPoint(
            x: quarterly ? index : trend.week,
            label: quarterly
                ? AppStrings.finalCheckInReportQuarter(
                    trend.quarter!,
                    trend.year!,
                  )
                : AppStrings.finalCheckInReportWeek(trend.week),
            great: trend.great.toDouble(),
            almostThere: trend.almostThere.toDouble(),
            needsImprovement: trend.needsImprovement.toDouble(),
            profileImages: trend.profiles
                .map(
                  (profile) => CustomFunctions.resolveImageUrl(profile.image),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    final byWeek = {for (final point in points) point.x: point};
    final maxTotal = points.fold<double>(
      0,
      (current, point) => math.max(current, point.total),
    );
    final maxY = maxTotal <= 100 ? 100 : ((maxTotal.toInt() + 19) ~/ 20) * 20;
    return FinalCheckInReportTrendData(
      usesQuarterLayout: quarterly,
      points: points,
      bars: quarterly
          ? points
          : List.generate(
              13,
              (index) =>
                  byWeek[index + 1] ??
                  FinalCheckInReportTrendPoint(
                    x: index + 1,
                    label: AppStrings.finalCheckInReportWeek(index + 1),
                    great: 0,
                    almostThere: 0,
                    needsImprovement: 0,
                    profileImages: const [],
                  ),
              growable: false,
            ),
      maxY: maxY.toDouble(),
      interval: maxY <= 40
          ? 5
          : maxY <= 100
          ? 10
          : maxY <= 200
          ? 20
          : 25,
    );
  }

  final bool usesQuarterLayout;
  final List<FinalCheckInReportTrendPoint> points;
  final List<FinalCheckInReportTrendPoint> bars;
  final double maxY;
  final double interval;

  String axisLabel(int x) {
    for (final bar in bars) {
      if (bar.x == x) return bar.label;
    }
    return '';
  }

  static int _quarterOrder(String? quarter) => switch (quarter?.toUpperCase()) {
    'Q1' => 1,
    'Q2' => 2,
    'Q3' => 3,
    'Q4' => 4,
    _ => 0,
  };
}

class FinalCheckInReportTrendPoint {
  const FinalCheckInReportTrendPoint({
    required this.x,
    required this.label,
    required this.great,
    required this.almostThere,
    required this.needsImprovement,
    required this.profileImages,
  });

  final int x;
  final String label;
  final double great;
  final double almostThere;
  final double needsImprovement;
  final List<String?> profileImages;
  double get almostThereEnd => great + almostThere;
  double get total => almostThereEnd + needsImprovement;
}
