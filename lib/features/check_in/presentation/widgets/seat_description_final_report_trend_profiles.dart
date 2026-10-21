part of '../pages/seat_description_final_check_in_report.dart';

class _TrendProfilesAvatarStack extends StatelessWidget {
  const _TrendProfilesAvatarStack({required this.profileImages});

  final List<String?> profileImages;

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
    if (profileImages.isEmpty) {
      return const SizedBox(height: 20);
    }

    final visibleProfiles = profileImages.take(3).toList(growable: false);
    final remainingCount = profileImages.length - visibleProfiles.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleProfiles.map((image) => _TrendProfileAvatar(imageUrl: image)),
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
              AppStrings.finalCheckInReportMoreProfiles(remainingCount),
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

  final List<FinalCheckInReportTrendPoint> trends;
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
        if (trends[index].profileImages.isNotEmpty) (index, trends[index]),
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
              final total = trend.total;
              final markerHeight = _TrendProfilesAvatarStack.estimatedHeight(
                trend.profileImages.length,
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
                  child: _TrendProfilesAvatarStack(
                    profileImages: trend.profileImages,
                  ),
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
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1),
        image: DecorationImage(
          image: imageUrl == null
              ? const AssetImage(AppStrings.dummyProfileImagePath)
              : NetworkImage(imageUrl!),
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
        Flexible(
          child: AppTextView.body3(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
