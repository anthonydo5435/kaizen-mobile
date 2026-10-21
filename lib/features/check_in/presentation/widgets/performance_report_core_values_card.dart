import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';
import '../pages/performance_report_dialogs.dart';
import '../providers/check_in_controller.dart';

class PerformanceReportCoreValuesCard extends StatelessWidget {
  const PerformanceReportCoreValuesCard({
    super.key,
    required this.values,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<PerformanceReportCoreValue> values;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CheckInController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Expanded(
                    child: AppTextView.body2(
                      AppStrings.performanceReportCoreValuesTitle,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _ExpandChevronBadge(isExpanded: isExpanded),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : 0.0;
                  if (maxWidth <= 10) {
                    return const SizedBox.shrink();
                  }

                  final itemWidth = (maxWidth - 10) / 2;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List<Widget>.generate(values.length, (index) {
                      final value = values[index];
                      final visualSpec = controller
                          .resolvePerformanceReportCoreValueVisualSpec(value);

                      return SizedBox(
                        width: itemWidth,
                        child: _CoreValuePill(
                          coreValue: value,
                          visualSpec: visualSpec,
                          fillWidth: true,
                          onTap: () => showPerformanceReportCoreValueDialog(
                            context,
                            coreValue: value,
                            icon: visualSpec.icon,
                            accentColor: visualSpec.color,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _CoreValuePill extends StatelessWidget {
  const _CoreValuePill({
    required this.coreValue,
    required this.visualSpec,
    required this.onTap,
    this.fillWidth = false,
  });

  final PerformanceReportCoreValue coreValue;
  final PerformanceReportCoreValueVisualSpec visualSpec;
  final VoidCallback onTap;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: fillWidth ? double.infinity : null,
        constraints: fillWidth
            ? null
            : const BoxConstraints(minWidth: 148, maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visualSpec.color, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: visualSpec.color.withValues(alpha: 0.12),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visualSpec.color,
              ),
              child: Icon(
                visualSpec.icon,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextView.body1(
                coreValue.title,
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandChevronBadge extends StatelessWidget {
  const _ExpandChevronBadge({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.28),
          ),
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
