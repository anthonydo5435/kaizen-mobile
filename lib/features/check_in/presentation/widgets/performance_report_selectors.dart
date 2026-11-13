import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/performance_report.dart';

class PerformanceReportTimeRangeSelector extends StatelessWidget {
  const PerformanceReportTimeRangeSelector({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor = AppColors.surfaceDark,
    this.borderSide,
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final BorderSide? borderSide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            borderSide ??
            BorderSide(
              color: AppColors.grey1.withValues(alpha: 0.3),
              width: 0.3,
            ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: AppTextView.body3(
                    label,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PerformanceReportHistoryButton extends StatelessWidget {
  const PerformanceReportHistoryButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.performanceReportAllReports,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(45, 45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.grey1.withValues(alpha: 0.3),
            width: 0.3,
          ),
        ),
      ),
      icon: const Icon(Icons.history_rounded, size: 22),
      onPressed: onPressed,
    );
  }
}

class PerformanceReportProfileChips extends StatelessWidget {
  const PerformanceReportProfileChips({
    super.key,
    required this.report,
    required this.onProfileTap,
    this.showNoProfileChip = false,
    this.isLoading = false,
  });

  final PerformanceReport report;
  final ValueChanged<AuditMemberProfile> onProfileTap;
  final bool showNoProfileChip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final profiles = report.profile.profiles;

    if (profiles.isEmpty && !showNoProfileChip) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: showNoProfileChip
              ? const [
                  _ProfileNameChip(
                    label: AppStrings.noProfile,
                    isSelected: false,
                  ),
                ]
              : List<Widget>.generate(profiles.length, (index) {
                  final profile = profiles[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == profiles.length - 1 ? 0 : 8,
                    ),
                    child: _ProfileNameChip(
                      label: profile.name,
                      isSelected:
                          profile.uuid == report.profile.uuid ||
                          profile.uuid == report.profile.profileUuid,
                      onTap: isLoading ? null : () => onProfileTap(profile),
                    ),
                  );
                }),
        ),
      ),
    );
  }
}

class _ProfileNameChip extends StatelessWidget {
  const _ProfileNameChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.purple2 : AppColors.grey2,
              width: 1,
            ),
          ),
          child: AppTextView.body3(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
