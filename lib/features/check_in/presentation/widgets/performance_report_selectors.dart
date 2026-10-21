import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/performance_report.dart';
import '../pages/performance_report_dialogs.dart';

class PerformanceReportTimeRangeSelector extends StatelessWidget {
  const PerformanceReportTimeRangeSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.customRangeLabel,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? customRangeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textPrimary,
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option == AppStrings.performanceReportCustomDateRange &&
                            value ==
                                AppStrings.performanceReportCustomDateRange &&
                            customRangeLabel != null
                        ? customRangeLabel!
                        : option,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class PerformanceReportCertifiedReportsSelector extends StatelessWidget {
  const PerformanceReportCertifiedReportsSelector({
    super.key,
    required this.value,
    required this.options,
    required this.isDownloading,
    required this.onChanged,
    required this.onDownload,
  });

  final String? value;
  final List<CertifiedReportOption> options;
  final bool Function(String uuid) isDownloading;
  final ValueChanged<String?> onChanged;
  final Future<String> Function(CertifiedReportOption option) onDownload;

  @override
  Widget build(BuildContext context) {
    final selectedValue = options.any((item) => item.uuid == value)
        ? value
        : null;
    String? selectedLabel;
    for (final option in options) {
      if (option.uuid == selectedValue) {
        selectedLabel = option.displayName;
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCertifiedReportsSheet(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel ??
                    AppStrings.performanceReportSelectCertifiedReport,
                style: TextStyle(
                  color: selectedLabel == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
    );
  }

  Future<void> _showCertifiedReportsSheet(BuildContext context) async {
    await showPerformanceReportCertifiedReportsSheet(
      context,
      value: value,
      options: options,
      isDownloading: isDownloading,
      onChanged: onChanged,
      onDownload: onDownload,
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
