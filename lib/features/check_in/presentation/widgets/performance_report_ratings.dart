import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';

class PerformanceReportRatings extends StatelessWidget {
  const PerformanceReportRatings({
    super.key,
    required this.rows,
    required this.categoryTabs,
    required this.onDescriptionGo,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  final List<PerformanceReportRatingRow> rows;
  final List<PerformanceReportCategoryTab> categoryTabs;
  final ValueChanged<PerformanceReportRatingRow> onDescriptionGo;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryTabs.isNotEmpty) ...[
            _PerformanceReportCategorySelectorCard(
              categoryTabs: categoryTabs,
              selectedCategoryIndex: selectedCategoryIndex,
              onCategorySelected: onCategorySelected,
            ),
            const SizedBox(height: 16),
          ],
          if (rows.isEmpty)
            const AppTextView.body3(
              AppStrings.performanceReportNoCategoryDescriptions,
              color: AppColors.textSecondary,
            )
          else
            Column(
              children: List<Widget>.generate(rows.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == rows.length - 1 ? 0 : 12,
                  ),
                  child: _DescriptionRatingCard(
                    row: rows[index],
                    onGo: () => onDescriptionGo(rows[index]),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _PerformanceReportCategorySelectorCard extends StatelessWidget {
  const _PerformanceReportCategorySelectorCard({
    required this.categoryTabs,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  final List<PerformanceReportCategoryTab> categoryTabs;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  PerformanceReportCategoryTab get _selectedCategory {
    if (categoryTabs.isEmpty) {
      return const PerformanceReportCategoryTab(
        label: '',
        score: 0,
        rows: <PerformanceReportRatingRow>[],
      );
    }

    final resolvedIndex = selectedCategoryIndex.clamp(
      0,
      categoryTabs.length - 1,
    );
    return categoryTabs[resolvedIndex];
  }

  Future<void> _showCategorySheet(BuildContext context) async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      isScrollControlled: true,
      builder: (_) => _PerformanceReportCategorySheet(
        categoryTabs: categoryTabs,
        selectedCategoryIndex: selectedCategoryIndex,
      ),
    );

    if (!context.mounted ||
        selectedIndex == null ||
        selectedIndex == selectedCategoryIndex) {
      return;
    }

    onCategorySelected(selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final category = _selectedCategory;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showCategorySheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppTextView.body3(
                    AppStrings.performanceReportSelectedCategoryTitle,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 4),
                  AppTextView.body2(
                    '${category.label} (${category.score.toStringAsFixed(1)})',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceReportCategorySheet extends StatelessWidget {
  const _PerformanceReportCategorySheet({
    required this.categoryTabs,
    required this.selectedCategoryIndex,
  });

  final List<PerformanceReportCategoryTab> categoryTabs;
  final int selectedCategoryIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 620),
          decoration: const BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: AppTextView.body1(
                          AppStrings.performanceReportCategoriesTitle,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppOverlayCloseButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const AppTextView.body3(
                    AppStrings.performanceReportSelectCategoryDescription,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                  const SizedBox(height: 18),
                  ...List<Widget>.generate(
                    categoryTabs.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == categoryTabs.length - 1 ? 0 : 12,
                      ),
                      child: _PerformanceReportCategorySheetItem(
                        category: categoryTabs[index],
                        isSelected: index == selectedCategoryIndex,
                        onTap: () => Navigator.of(context).pop(index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceReportCategorySheetItem extends StatelessWidget {
  const _PerformanceReportCategorySheetItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final PerformanceReportCategoryTab category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.14)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.secondaryColor
                : AppColors.fieldBorder.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextView.body2(
                    category.label,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 4),
                  AppTextView.body3(
                    '${AppStrings.performanceReportPercentageLabel} ${category.score.toStringAsFixed(1)}%',
                    color: isSelected
                        ? AppColors.secondaryColor
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.secondaryColor
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionRatingCard extends StatelessWidget {
  const _DescriptionRatingCard({required this.row, required this.onGo});

  final PerformanceReportRatingRow row;
  final VoidCallback onGo;

  bool get _canOpenDetail {
    return row.passCount > 0 || row.partialCount > 0 || row.failCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextView.body1(
                  row.title,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppTextView.body3(
                    AppStrings.performanceReportRatings,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(width: 6),
                  AppTextView.body2(
                    '${row.ratingPercent}%',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppTextView.body3(
                AppStrings.performanceReportRatings,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 8),
              _RatingBadge(value: row.passCount, color: AppColors.lightGreen1),
              const SizedBox(width: 8),
              _RatingBadge(value: row.partialCount, color: AppColors.orange1),
              const SizedBox(width: 8),
              _RatingBadge(value: row.failCount, color: AppColors.orange2),
              if (_canOpenDetail) ...[
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onGo,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (row.remarks != null && row.remarks!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const AppTextView.body3(
              AppStrings.performanceReportRemarks,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            AppTextView.body3(
              row.remarks!,
              color: AppColors.textPrimary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppTextView.body4(
        '$value',
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
