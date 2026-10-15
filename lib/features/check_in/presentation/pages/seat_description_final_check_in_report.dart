import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';
import '../../../training/presentation/pages/edit_training_screen.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/seat_description_audit_report_comments.dart';
import '../../domain/entities/seat_description_final_audit_report.dart';
import '../providers/check_in_controller.dart';
import '../widgets/check_in_media_preview.dart';
import 'check_in_media_comments_bottom_sheet.dart';

class SeatDescriptionFinalCheckInReportScreen extends StatefulWidget {
  const SeatDescriptionFinalCheckInReportScreen({
    super.key,
    required this.flowFirstId,
    this.profileUuid,
    required this.descriptionId,
    required this.quarter,
    required this.year,
  });

  final String flowFirstId;
  final String? profileUuid;
  final String descriptionId;
  final int quarter;
  final int year;

  @override
  State<SeatDescriptionFinalCheckInReportScreen> createState() =>
      _SeatDescriptionFinalCheckInReportScreenState();
}

class _SeatDescriptionFinalCheckInReportScreenState
    extends State<SeatDescriptionFinalCheckInReportScreen> {
  static const List<String> _timeRangeOptions = <String>[
    'Current Quarter Year',
    'This Quarter',
    'Last 4 Quarters',
    'All Time',
  ];

  late Future<SeatDescriptionFinalAuditReport> _reportFuture;
  late Future<SeatDescriptionAuditReportComments> _commentsFuture;
  late Future<List<SeatDescriptionFinalAuditProfile>> _profilesFuture;
  late final TextEditingController _commentsSearchController;
  String _selectedTimeRange = _timeRangeOptions.first;
  String _commentsQuery = '';

  @override
  void initState() {
    super.initState();
    _commentsSearchController = TextEditingController();
    _reportFuture = _loadReport();
    _commentsFuture = _loadComments();
    _profilesFuture = _loadProfiles();
  }

  @override
  void dispose() {
    _commentsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _TimeRangeDropdown(
                value: _selectedTimeRange,
                items: _timeRangeOptions,
                onChanged: (value) {
                  if (value == null || value == _selectedTimeRange) {
                    return;
                  }

                  setState(() {
                    _selectedTimeRange = value;
                    _reportFuture = _loadReport();
                    _commentsFuture = _loadComments();
                    _profilesFuture = _loadProfiles();
                  });
                },
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<SeatDescriptionFinalAuditReport>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(child: FastCircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _FinalReportFeedback(
                      title: 'Unable to load final audit report.',
                      actionLabel: 'Try Again',
                      onAction: _refresh,
                    );
                  }

                  final report = snapshot.data;
                  if (report == null) {
                    return _FinalReportFeedback(
                      title: 'No final audit report found.',
                      actionLabel: 'Refresh',
                      onAction: _refresh,
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    child:
                        FutureBuilder<List<SeatDescriptionFinalAuditProfile>>(
                          future: _profilesFuture,
                          builder: (context, profilesSnapshot) {
                            final profiles = profilesSnapshot.data ?? const [];
                            return Column(
                              children: [
                                _ReportIdentityCard(
                                  report: report,
                                  profiles: profiles,
                                ),
                                const SizedBox(height: 16),
                                _ConfidenceLevelCard(
                                  stats: report.summaryData.stats,
                                ),
                                const SizedBox(height: 16),
                                _DetailTextCard(
                                  title: 'Description',
                                  body: report.description,
                                  bottomActionLabel:
                                      _canOpenTraining(report.trainingRoute)
                                      ? AppStrings.seatProfileViewTrainings
                                      : null,
                                  onBottomActionTap:
                                      _canOpenTraining(report.trainingRoute)
                                      ? () => _openTrainingEditor(
                                          context,
                                          report.trainingRoute,
                                          additionalSeatProfileIds: <String>[
                                            report.job.uuid,
                                          ],
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _DetailTextCard(
                                  title: 'Specifics',
                                  body: report.jobSpecifics,
                                ),
                                const SizedBox(height: 16),
                                _PerformanceTrendCard(
                                  selectedTimeRange: _selectedTimeRange,
                                  trends: report.summaryData.trends,
                                ),
                                const SizedBox(height: 16),

                                FutureBuilder<
                                  SeatDescriptionAuditReportComments
                                >(
                                  future: _commentsFuture,
                                  builder: (context, commentsSnapshot) {
                                    final allComments =
                                        commentsSnapshot.data?.items ??
                                        const [];
                                    return _CommentsCard(
                                      comments: _filterComments(allComments),
                                      hasComments: allComments.isNotEmpty,
                                      isLoading:
                                          commentsSnapshot.connectionState !=
                                          ConnectionState.done,
                                      searchController:
                                          _commentsSearchController,
                                      onSearchChanged: (value) {
                                        setState(() {
                                          _commentsQuery = value
                                              .trim()
                                              .toLowerCase();
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                child: SvgPicture.asset(
                  '${AppStrings.imagePath}back.svg',
                  height: 24,
                  width: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const AppTextView.body(
            'Final Audit Report',
            color: AppColors.secondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Future<SeatDescriptionFinalAuditReport> _loadReport() {
    final timeRange = _resolvedTimeRangeApiValue();
    return context
        .read<CheckInController>()
        .loadSeatDescriptionFinalAuditReport(
          flowFirstId: widget.flowFirstId,
          profileUuid: widget.profileUuid,
          descriptionId: widget.descriptionId,
          quarter: timeRange == null ? widget.quarter : null,
          year: timeRange == null ? widget.year : null,
          timeRange: timeRange,
        );
  }

  Future<SeatDescriptionAuditReportComments> _loadComments() {
    final timeRange = _resolvedTimeRangeApiValue();
    return context
        .read<CheckInController>()
        .loadSeatDescriptionAuditReportComments(
          flowFirstId: widget.flowFirstId,
          profileUuid: widget.profileUuid,
          descriptionId: widget.descriptionId,
          quarter: timeRange == null ? widget.quarter : null,
          year: timeRange == null ? widget.year : null,
          timeRange: timeRange,
        );
  }

  Future<List<SeatDescriptionFinalAuditProfile>> _loadProfiles() {
    final timeRange = _resolvedTimeRangeApiValue();
    return context
        .read<CheckInController>()
        .loadSeatDescriptionAuditReportProfiles(
          flowFirstId: widget.flowFirstId,
          profileUuid: widget.profileUuid,
          descriptionId: widget.descriptionId,
          quarter: timeRange == null ? widget.quarter : null,
          year: timeRange == null ? widget.year : null,
          timeRange: timeRange,
        );
  }

  String? _resolvedTimeRangeApiValue() {
    return switch (_selectedTimeRange) {
      'Current Quarter Year' => null,
      'This Quarter' => 'current_quarter',
      'Last 4 Quarters' => 'last_four_quarters',
      'All Time' => 'all_time',
      _ => null,
    };
  }

  List<SeatDescriptionAuditReportComment> _filterComments(
    List<SeatDescriptionAuditReportComment> comments,
  ) {
    final query = _commentsQuery;
    if (query.isEmpty) {
      return comments;
    }

    return comments
        .where((comment) {
          final text = comment.comment.toLowerCase();
          final type = (comment.type ?? '').toLowerCase();
          return text.contains(query) || type.contains(query);
        })
        .toList(growable: false);
  }

  void _refresh() {
    setState(() {
      _reportFuture = _loadReport();
      _commentsFuture = _loadComments();
      _profilesFuture = _loadProfiles();
    });
  }

  bool _canOpenTraining(SeatDescriptionTrainingRoute trainingRoute) {
    return trainingRoute.job.trim().isNotEmpty &&
        trainingRoute.description.trim().isNotEmpty;
  }

  Future<void> _openTrainingEditor(
    BuildContext context,
    SeatDescriptionTrainingRoute trainingRoute, {
    List<String> additionalSeatProfileIds = const <String>[],
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditTrainingScreen(
          trainingRoute: trainingRoute,
          initialModuleId: trainingRoute.initialModuleId,
          canManageTraining: AppManager.instance
              .canCurrentUserManageTrainingForSeatProfile(
                seatProfileId: trainingRoute.job,
                additionalSeatProfileIds: additionalSeatProfileIds,
              ),
          useNonBlockingVideoUpload: true,
        ),
      ),
    );
  }
}

class _ReportIdentityCard extends StatelessWidget {
  const _ReportIdentityCard({required this.report, required this.profiles});

  final SeatDescriptionFinalAuditReport report;
  final List<SeatDescriptionFinalAuditProfile> profiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(label: 'Seat', value: report.job.title),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: 'Name',
                  value: _resolveProfileName(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(
                  label: 'Audit Factor',
                  value: _capitalize(report.auditFactorType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: 'Seat Type',
                  value: report.isOpenSeat ? 'Open Seat' : 'Assigned Seat',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return '-';
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _resolveProfileName() {
    final names = profiles
        .map((profile) => profile.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    if (names.isEmpty) {
      return '-';
    }

    if (names.length == 1) {
      return names.first;
    }

    if (names.length == 2) {
      return '${names[0]}, ${names[1]}';
    }

    return '${names[0]}, ${names[1]} +${names.length - 2}';
  }
}

class _ReportMetaItem extends StatelessWidget {
  const _ReportMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body3(
          label,
          color: AppColors.grey1,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 6),
        AppTextView.body1(
          value.isEmpty ? '-' : value,
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

class _ConfidenceLevelCard extends StatelessWidget {
  const _ConfidenceLevelCard({required this.stats});

  final SeatDescriptionFinalAuditStats stats;

  @override
  Widget build(BuildContext context) {
    final totalCount =
        stats.totalGreat + stats.totalAlmostThere + stats.totalNeedsImprovement;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(
                  label: 'Confidence Level',
                  value: '${stats.confidenceLevel}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: 'Performance Percentage',
                  value: '${stats.totalPercentage}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppTextView.body1(
            'Rating',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 16),
          _RatingBarRow(
            label: 'Great',
            value: stats.totalGreat,
            total: totalCount,
            color: AppColors.green1,
          ),
          const SizedBox(height: 12),
          _RatingBarRow(
            label: 'Almost There',
            value: stats.totalAlmostThere,
            total: totalCount,
            color: AppColors.orange1,
          ),
          const SizedBox(height: 12),
          _RatingBarRow(
            label: 'Needs Improvement',
            value: stats.totalNeedsImprovement,
            total: totalCount,
            color: AppColors.red1,
          ),
        ],
      ),
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextView.body2(
                label,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppTextView.body2(
              '$value',
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DetailTextCard extends StatelessWidget {
  const _DetailTextCard({
    required this.title,
    required this.body,
    this.bottomActionLabel,
    this.onBottomActionTap,
  });

  final String title;
  final String body;
  final String? bottomActionLabel;
  final VoidCallback? onBottomActionTap;

  @override
  Widget build(BuildContext context) {
    final resolvedActionLabel = bottomActionLabel?.trim() ?? '';
    final showBottomAction =
        resolvedActionLabel.isNotEmpty && onBottomActionTap != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            title,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          AppTextView.body(
            body.isEmpty ? 'No $title available.' : body,
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          if (showBottomAction) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onBottomActionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    resolvedActionLabel,
                    style: const TextStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.secondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerformanceTrendCard extends StatelessWidget {
  const _PerformanceTrendCard({
    required this.selectedTimeRange,
    required this.trends,
  });

  final String selectedTimeRange;
  final List<SeatDescriptionFinalAuditTrend> trends;

  @override
  Widget build(BuildContext context) {
    final usesQuarterLayout = _usesQuarterLayout;
    final validTrends =
        (usesQuarterLayout
              ? trends
                    .where(
                      (item) =>
                          (item.quarter ?? '').isNotEmpty && item.year != null,
                    )
                    .toList(growable: false)
              : trends.where((item) => item.week > 0).toList(growable: false))
          ..sort(
            usesQuarterLayout
                ? _compareQuarterTrends
                : (a, b) => a.week.compareTo(b.week),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppTextView.body1(
            'Performance Trends',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 14),
          if (validTrends.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: AppTextView.body2(
                  'No trend data found.',
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            SizedBox(
              height: usesQuarterLayout ? 320 : 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _TrendLegendItem(label: 'Great', color: AppColors.green1),
                      _TrendLegendItem(
                        label: 'Almost There',
                        color: AppColors.orange1,
                      ),
                      _TrendLegendItem(
                        label: 'Needs Improvement',
                        color: AppColors.red1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _TrendChartWithProfiles(
                      trends: validTrends,
                      usesQuarterLayout: usesQuarterLayout,
                      chartData: _trendChartData(validTrends),
                      maxY: _chartMaxY(
                        validTrends.fold<int>(0, (currentMax, trend) {
                          final total =
                              trend.great +
                              trend.almostThere +
                              trend.needsImprovement;
                          return math.max(currentMax, total);
                        }),
                      ).toDouble(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _usesQuarterLayout =>
      selectedTimeRange == 'Last 4 Quarters' || selectedTimeRange == 'All Time';

  int _compareQuarterTrends(
    SeatDescriptionFinalAuditTrend a,
    SeatDescriptionFinalAuditTrend b,
  ) {
    final yearCompare = (a.year ?? 0).compareTo(b.year ?? 0);
    if (yearCompare != 0) {
      return yearCompare;
    }

    return _quarterOrder(a.quarter).compareTo(_quarterOrder(b.quarter));
  }

  int _quarterOrder(String? quarter) {
    return switch (quarter?.toUpperCase()) {
      'Q1' => 1,
      'Q2' => 2,
      'Q3' => 3,
      'Q4' => 4,
      _ => 0,
    };
  }

  BarChartData _trendChartData(List<SeatDescriptionFinalAuditTrend> trends) {
    final usesQuarterLayout = _usesQuarterLayout;
    final trendsByWeek = {
      for (final trend in trends.where(
        (item) => item.week >= 1 && item.week <= 13,
      ))
        trend.week: trend,
    };
    final maxTotal = trends.fold<int>(0, (currentMax, trend) {
      final total = trend.great + trend.almostThere + trend.needsImprovement;
      return math.max(currentMax, total);
    });
    final maxY = _chartMaxY(maxTotal);
    final interval = _yAxisInterval(maxY);
    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval.toDouble(),
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.white10, strokeWidth: 1, dashArray: [1, 1]),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: usesQuarterLayout ? 42 : 22,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final text = usesQuarterLayout
                  ? _quarterAxisLabel(value.toInt(), trends)
                  : _weekAxisLabel(value.toInt());

              if (text.isEmpty) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                space: 1,
                child: AppTextView.body2(
                  text,
                  color: Colors.white54,
                  fontSize: 12,
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval.toDouble(),
            getTitlesWidget: (value, meta) {
              if (value < 0 ||
                  value > maxY ||
                  value % interval.toDouble() != 0) {
                return const SizedBox.shrink();
              }

              return AppTextView.body2(
                value.toInt().toString(),
                color: Colors.white54,
                fontSize: usesQuarterLayout ? 10 : null,
              );
            },
            reservedSize: usesQuarterLayout ? 24 : 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY.toDouble(),
      barGroups: List<BarChartGroupData>.generate(
        usesQuarterLayout ? trends.length : 13,
        (index) {
          final trend = usesQuarterLayout
              ? trends[index]
              : trendsByWeek[index + 1];
          final great = (trend?.great ?? 0).toDouble();
          final almostThere = (trend?.almostThere ?? 0).toDouble();
          final needsImprovement = (trend?.needsImprovement ?? 0).toDouble();
          final greatEnd = great;
          final almostThereEnd = great + almostThere;
          final total = great + almostThere + needsImprovement;

          return BarChartGroupData(
            x: usesQuarterLayout ? index : index + 1,
            barsSpace: 0,
            barRods: [
              BarChartRodData(
                toY: total,
                width: usesQuarterLayout ? 24 : 12,
                borderRadius: BorderRadius.circular(12),
                color: total == 0 ? Colors.white12 : AppColors.green1,
                rodStackItems: total == 0
                    ? const <BarChartRodStackItem>[]
                    : [
                        if (great > 0)
                          BarChartRodStackItem(0, greatEnd, AppColors.green1),
                        if (almostThere > 0)
                          BarChartRodStackItem(
                            greatEnd,
                            almostThereEnd,
                            AppColors.orange1,
                          ),
                        if (needsImprovement > 0)
                          BarChartRodStackItem(
                            almostThereEnd,
                            total,
                            AppColors.red1,
                          ),
                      ],
              ),
            ],
          );
        },
        growable: false,
      ),
      groupsSpace: usesQuarterLayout ? 18 : 8,
      barTouchData: BarTouchData(enabled: true),
      alignment: usesQuarterLayout
          ? BarChartAlignment.center
          : BarChartAlignment.spaceBetween,
    );
  }

  String _weekAxisLabel(int week) {
    return week >= 1 && week <= 13 ? 'w$week' : '';
  }

  String _quarterAxisLabel(
    int index,
    List<SeatDescriptionFinalAuditTrend> trends,
  ) {
    if (index < 0 || index >= trends.length) {
      return '';
    }

    final trend = trends[index];
    final quarter = trend.quarter ?? '';
    final year = trend.year?.toString() ?? '';
    if (quarter.isEmpty || year.isEmpty) {
      return '';
    }

    return '$quarter\n$year';
  }

  int _chartMaxY(int maxTotal) {
    if (maxTotal <= 0) {
      return 100;
    }
    if (maxTotal <= 100) {
      return 100;
    }

    return ((maxTotal + 19) ~/ 20) * 20;
  }

  int _yAxisInterval(int maxY) {
    if (maxY <= 40) {
      return 5;
    }
    if (maxY <= 100) {
      return 10;
    }
    if (maxY <= 200) {
      return 20;
    }
    return 25;
  }
}

class _TrendProfilesAvatarStack extends StatelessWidget {
  const _TrendProfilesAvatarStack({required this.profiles});

  final List<SeatDescriptionFinalAuditProfile> profiles;

  static double estimatedHeight(int profileCount) {
    if (profileCount <= 0) {
      return 0.0;
    }

    final visibleProfiles = math.min(profileCount, 3);
    final hasMoreBadge = profileCount > 3;
    final avatarSectionHeight = visibleProfiles * 18;
    final gapCount = visibleProfiles - 1 + (hasMoreBadge ? 1 : 0);
    final badgeHeight = hasMoreBadge ? 18 : 0;

    return (avatarSectionHeight + (gapCount * 4) + badgeHeight).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const SizedBox(height: 20);
    }

    final visibleProfiles = profiles.take(3).toList(growable: false);
    final remainingCount = profiles.length - visibleProfiles.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final profile in visibleProfiles) ...[
          _TrendProfileAvatar(imageUrl: profile.image),
        ],
        if (remainingCount > 0)
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 1),
            ),
            child: AppTextView.body3(
              '+$remainingCount',
              color: AppColors.textPrimary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _TrendChartWithProfiles extends StatelessWidget {
  const _TrendChartWithProfiles({
    required this.trends,
    required this.usesQuarterLayout,
    required this.chartData,
    required this.maxY,
  });

  final List<SeatDescriptionFinalAuditTrend> trends;
  final bool usesQuarterLayout;
  final BarChartData chartData;
  final double maxY;

  static const double _leftTitlesWidth = 30;
  static const double _bottomTitlesHeightQuarter = 42;
  static const double _bottomTitlesHeightDefault = 22;
  static const double _barWidthQuarter = 24;
  static const double _barWidthDefault = 12;
  static const double _groupsSpaceQuarter = 18;
  static const double _avatarSize = 18;
  static const double _quarterChartTopInset = 20;
  static const double _quarterChartBottomInset = 10;

  @override
  Widget build(BuildContext context) {
    final trendsWithProfiles = [
      for (var index = 0; index < trends.length; index++)
        if (trends[index].profiles.isNotEmpty) (index, trends[index]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final chartHeight = size.height;
        final chartWidth = size.width;
        final leftTitlesWidth = usesQuarterLayout ? 24.0 : _leftTitlesWidth;
        final bottomTitlesHeight = usesQuarterLayout
            ? _bottomTitlesHeightQuarter
            : _bottomTitlesHeightDefault;
        final chartTopInset = usesQuarterLayout ? _quarterChartTopInset : 0.0;
        final chartBottomInset = usesQuarterLayout
            ? _quarterChartBottomInset
            : 0.0;
        final plotHeight = math.max(
          0.0,
          chartHeight - bottomTitlesHeight - chartTopInset - chartBottomInset,
        );
        final plotWidth = math.max(0.0, chartWidth - leftTitlesWidth);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: chartTopInset,
                  bottom: chartBottomInset,
                ),
                child: BarChart(chartData),
              ),
            ),
            ...trendsWithProfiles.map((entry) {
              final index = entry.$1;
              final trend = entry.$2;
              final total =
                  trend.great + trend.almostThere + trend.needsImprovement;
              final markerHeight = _TrendProfilesAvatarStack.estimatedHeight(
                trend.profiles.length,
              );
              final barCenterX = _barCenterX(
                index: index,
                plotWidth: plotWidth,
                groupCount: trends.length,
              );
              final barEndY = total <= 0
                  ? chartTopInset + plotHeight
                  : chartTopInset + (plotHeight * (1 - (total / maxY)));
              final top = barEndY - markerHeight + (_avatarSize / 2);

              return Positioned(
                left: (leftTitlesWidth + barCenterX - 9).clamp(
                  0.0,
                  math.max(0.0, chartWidth - 18),
                ),
                top: usesQuarterLayout
                    ? 2
                    : top.clamp(
                        0.0,
                        math.max(0.0, chartHeight - bottomTitlesHeight - 18),
                      ),
                child: IgnorePointer(
                  child: _TrendProfilesAvatarStack(profiles: trend.profiles),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  double _barCenterX({
    required int index,
    required double plotWidth,
    required int groupCount,
  }) {
    if (groupCount <= 0) {
      return 0;
    }

    if (usesQuarterLayout) {
      final totalContentWidth =
          (groupCount * _barWidthQuarter) +
          ((groupCount - 1) * _groupsSpaceQuarter);
      final startX = math.max(0.0, (plotWidth - totalContentWidth) / 2);
      return startX +
          (index * (_barWidthQuarter + _groupsSpaceQuarter)) +
          (_barWidthQuarter / 2);
    }

    if (groupCount == 1) {
      return plotWidth / 2;
    }

    final totalSpacing = math.max(
      0.0,
      plotWidth - (groupCount * _barWidthDefault),
    );
    final spacing = totalSpacing / (groupCount - 1);
    return (index * (_barWidthDefault + spacing)) + (_barWidthDefault / 2);
  }
}

class _TrendProfileAvatar extends StatelessWidget {
  const _TrendProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1),
        image: DecorationImage(
          image: resolvedImageUrl == null
              ? const AssetImage('lib/assets/images/dumy_pic.png')
              : NetworkImage(resolvedImageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _TrendLegendItem extends StatelessWidget {
  const _TrendLegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 6, height: 1.3, color: color),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Container(width: 6, height: 1.3, color: color),
          ],
        ),
        const SizedBox(width: 6),
        AppTextView.body3(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }
}

class _TimeRangeDropdown extends StatelessWidget {
  const _TimeRangeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.mainBg,
          iconEnabledColor: AppColors.textPrimary,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: items
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.comments,
    required this.hasComments,
    required this.isLoading,
    required this.searchController,
    required this.onSearchChanged,
  });

  final List<SeatDescriptionAuditReportComment> comments;
  final bool hasComments;
  final bool isLoading;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppTextView.body1(
            'Comments',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          if (hasComments) ...[
            const SizedBox(height: 4),
            const AppTextView.body1(
              'All comments with the media evidence from the selected quarter',
              color: AppColors.grey1,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            const SizedBox(height: 12),
            _CommentsSearchBar(
              controller: searchController,
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),
          if (isLoading)
            SizedBox(
              height: 48,
              child: Center(child: FastCircularProgressIndicator()),
            )
          else if (comments.isEmpty)
            const AppTextView.body(
              'No check-in comments available.',
              color: AppColors.textSecondary,
              fontSize: 12,
            )
          else
            Column(
              children: comments
                  .map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CommentListTile(comment: comment),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _CommentsSearchBar extends StatelessWidget {
  const _CommentsSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            '${AppStrings.imagePath}search.svg',
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.textPrimary,
              cursorHeight: 18,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Search comments',
                hintStyle: TextStyle(
                  color: AppColors.grey1,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentListTile extends StatelessWidget {
  const _CommentListTile({required this.comment});

  final SeatDescriptionAuditReportComment comment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: comment.uuid.trim().isEmpty
            ? null
            : () => _openCommentsSheet(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CommentMediaPreview(
                mediaUrl: comment.media ?? '',
                thumbnailUrl: comment.thumbnailUrl,
                mediaType: comment.type,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextView.body2(
                  comment.comment.trim().isEmpty
                      ? AppStrings.noComment
                      : comment.comment,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCommentsSheet(BuildContext context) {
    final selectedMedia = AuditDescriptionMedia(
      uuid: comment.uuid,
      media: comment.media ?? '',
      type: comment.type ?? '',
      comment: comment.comment,
      unreadCount: 0,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInMediaCommentsBottomSheet(
        descriptionId: '',
        selectedMedia: selectedMedia,
        mediaList: [selectedMedia],
        onMediaChanged: () async {},
        isReadOnly: true,
      ),
    );
  }
}

class _CommentMediaPreview extends StatelessWidget {
  const _CommentMediaPreview({
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String? thumbnailUrl;
  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    final normalizedType = mediaType?.trim().toLowerCase();
    if (normalizedType == 'screen_recording' || normalizedType == 'video') {
      return _ScreenRecordingCommentPreview(thumbnailUrl: thumbnailUrl);
    }

    final hasMedia =
        (normalizedType == 'image' ||
            normalizedType == 'video' ||
            normalizedType == 'screen_recording') &&
        mediaUrl.trim().isNotEmpty;

    return CheckInMediaPreview(
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      width: 72,
      height: 72,
      borderRadius: 12,
      placeholder: hasMedia
          ? const _CommentMediaLoadingPlaceholder()
          : const CheckInTextCommentPlaceholder(),
    );
  }
}

class _ScreenRecordingCommentPreview extends StatelessWidget {
  const _ScreenRecordingCommentPreview({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return Stack(
        children: [
          CheckInMediaPreview(
            mediaUrl: thumbnailUrl,
            mediaType: 'image',
            width: 72,
            height: 72,
            borderRadius: 12,
            placeholder: const _CommentMediaLoadingPlaceholder(),
            showVideoOverlay: false,
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.hex14182a,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.secondaryColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CommentMediaLoadingPlaceholder extends StatelessWidget {
  const _CommentMediaLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppStrings.imagePath}no_image.png',
      fit: BoxFit.cover,
    );
  }
}

class _FinalReportFeedback extends StatelessWidget {
  const _FinalReportFeedback({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextView.body1(
              title,
              color: AppColors.textPrimary,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              child: AppTextView.body2(
                actionLabel,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
