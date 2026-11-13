part of '../pages/seat_description_final_check_in_report.dart';

class _PerformanceTrendCard extends StatelessWidget {
  const _PerformanceTrendCard({required this.data});

  final FinalCheckInReportTrendData data;

  @override
  Widget build(BuildContext context) {
    final usesQuarterLayout = data.usesQuarterLayout;
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
            AppStrings.finalCheckInReportTrends,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 14),
          if (data.points.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: AppTextView.body2(
                  AppStrings.finalCheckInReportNoTrends,
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
                      _TrendLegendItem(
                        label: AppStrings.auditRatingGreat,
                        color: AppColors.green1,
                      ),
                      _TrendLegendItem(
                        label: AppStrings.auditRatingAlmostThere,
                        color: AppColors.orange1,
                      ),
                      _TrendLegendItem(
                        label: AppStrings.auditRatingNeedsImprovement,
                        color: AppColors.red1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _TrendChartWithProfiles(
                      trends: data.points,
                      usesQuarterLayout: usesQuarterLayout,
                      chartData: _trendChartData(),
                      maxY: data.maxY,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  BarChartData _trendChartData() {
    final usesQuarterLayout = data.usesQuarterLayout;
    final maxY = data.maxY;
    final interval = data.interval;
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
              final text = data.axisLabel(value.toInt());

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
      barGroups: data.bars
          .map((point) {
            final great = point.great;
            final almostThere = point.almostThere;
            final needsImprovement = point.needsImprovement;
            final greatEnd = great;
            final almostThereEnd = point.almostThereEnd;
            final total = point.total;

            return BarChartGroupData(
              x: point.x,
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
          })
          .toList(growable: false),
      groupsSpace: usesQuarterLayout ? 18 : 8,
      barTouchData: BarTouchData(enabled: true),
      alignment: usesQuarterLayout
          ? BarChartAlignment.center
          : BarChartAlignment.spaceBetween,
    );
  }
}
