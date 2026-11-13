import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';

bool _isUnavailablePaygradeDisplay(String value) =>
    value.trim() == AppStrings.paygradesUnavailableDisplay;

class PerformanceReportSummaryCard extends StatelessWidget {
  const PerformanceReportSummaryCard({super.key, required this.report});

  final PerformanceReport report;

  @override
  Widget build(BuildContext context) {
    final isUnavailablePaygrade = _isUnavailablePaygradeDisplay(
      report.currentPaygrade,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 13,
          child: Container(
            constraints: const BoxConstraints(minHeight: 172),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileSummaryAvatar(
                  imageUrl:
                      report.profile.imageUrl ?? report.profile.avatarImageUrl,
                  name: report.profile.name,
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextView.body3(
                      report.profile.seatProfile,
                      color: AppColors.secondaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body1(
                      report.profile.name,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const AppTextView.body3(
                          AppStrings.performanceReportPaygradeLabel,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        AppTextView.body3(
                          report.currentPaygrade,
                          color: isUnavailablePaygrade
                              ? AppColors.secondaryColor
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 10,
          child: Column(
            children: [
              _MetricCard(
                value: report.overallPerformanceScore.toStringAsFixed(1),
                label: AppStrings.performanceReportRunningScore,
                valueColor: AppColors.lightGreen1,
              ),
              const SizedBox(height: 8),
              _MetricCard(
                value:
                    '${report.confidenceLevel.toStringAsFixed(report.confidenceLevel.truncateToDouble() == report.confidenceLevel ? 0 : 1)}%',
                label: AppStrings.performanceReportConfidenceLevel,
                valueColor: AppColors.orange1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PerformanceReportOpenSeatView extends StatelessWidget {
  const PerformanceReportOpenSeatView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message?.trim().isNotEmpty == true
        ? message!.trim()
        : AppStrings.performanceReportOpenSeatMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.person_off_outlined,
            color: AppColors.secondaryColor,
            size: 34,
          ),
          const SizedBox(height: 12),
          AppTextView.body1(
            AppStrings.performanceReportOpenSeatTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AppTextView.body3(
            resolvedMessage,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryAvatar extends StatelessWidget {
  const _ProfileSummaryAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);
    if (resolvedImageUrl == null) {
      return _ProfileSummaryAvatarFallback(name: name);
    }

    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondaryColor, width: 1.5),
      ),
      child: ClipOval(
        child: Image.network(
          resolvedImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _ProfileSummaryAvatarFallback(name: name),
        ),
      ),
    );
  }
}

class _ProfileSummaryAvatarFallback extends StatelessWidget {
  const _ProfileSummaryAvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();

    return Container(
      width: 65,
      height: 65,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.grey2,
      ),
      child: AppTextView.title1(
        initial,
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 69),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextView.title1(
            value,
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 4),
          AppTextView.body4(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceDark,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
  );
}
