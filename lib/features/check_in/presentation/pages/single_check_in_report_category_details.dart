import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/audit_list.dart';
import '../../domain/entities/single_audit_report_category_details.dart';
import '../providers/check_in_controller.dart';
import 'check_in_year_quarter_filter_sheet.dart';
import 'seat_description_final_check_in_report.dart';

class SingleCheckInReportCategoryDetailsScreen extends StatefulWidget {
  const SingleCheckInReportCategoryDetailsScreen({
    super.key,
    required this.profileJobId,
    this.categoryId,
    this.categoryTitle,
    this.quarter,
    this.year,
  });

  final String profileJobId;
  final String? categoryId;
  final String? categoryTitle;
  final int? quarter;
  final int? year;

  @override
  State<SingleCheckInReportCategoryDetailsScreen> createState() =>
      _SingleCheckInReportCategoryDetailsScreenState();
}

class _SingleCheckInReportCategoryDetailsScreenState
    extends State<SingleCheckInReportCategoryDetailsScreen> {
  late int _selectedYear;
  late int _selectedQuarter;
  bool _isLoadingCategories = true;
  Object? _categoriesError;
  List<AuditList> _categories = const <AuditList>[];
  String? _selectedCategoryId;
  String? _selectedCategoryTitle;
  Future<List<SingleAuditReportCategoryDetails>>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    _selectedYear = widget.year ?? currentYearQuarter.year;
    _selectedQuarter = widget.quarter ?? currentYearQuarter.quarter;
    _selectedCategoryId = widget.categoryId;
    _selectedCategoryTitle = widget.categoryTitle;
    _loadCategories();
  }

  @override
  void didUpdateWidget(
    covariant SingleCheckInReportCategoryDetailsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileJobId != widget.profileJobId) {
      _selectedCategoryId = widget.categoryId;
      _selectedCategoryTitle = widget.categoryTitle;
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 18),
              _buildQuarterYearSelector(context),
              const SizedBox(height: 18),
              _buildCategoriesSection(),
              const SizedBox(height: 16),
              Expanded(child: _buildDetailsSection()),
            ],
          ),
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
          AppTextView.body(
            AppStrings.checkInTitle,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterYearSelector(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openQuarterYearPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextView.body2(
                    'Quarter - Year',
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 6),
                  AppTextView.body1(
                    'Q$_selectedQuarter - $_selectedYear',
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    if (_isLoadingCategories) {
      return SizedBox(
        height: 132,
        child: Center(child: FastCircularProgressIndicator()),
      );
    }

    if (_categoriesError != null) {
      return _CategoryDetailsFeedback(
        title: 'Unable to load report categories.',
        actionLabel: 'Try Again',
        onAction: _loadCategories,
      );
    }

    if (_categories.isEmpty) {
      return _CategoryDetailsFeedback(
        title: 'No seat categories found.',
        actionLabel: 'Refresh',
        onAction: _loadCategories,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body1(
          'Seat Categories',
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _categories[index];
              final isSelected = item.uuid == _selectedCategoryId;
              return _CheckInCategorySelectorCard(
                item: item,
                isSelected: isSelected,
                onTap: () => _selectCategory(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    if (_isLoadingCategories) {
      return const SizedBox.shrink();
    }

    if (_categoriesError != null || _categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final detailsFuture = _detailsFuture;
    if (detailsFuture == null) {
      return _CategoryDetailsFeedback(
        title: 'No category selected.',
        actionLabel: 'Refresh',
        onAction: _loadCategories,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body1(
          _selectedCategoryTitle ?? '',
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 6),
        AppTextView.body2(
          'Quarter $_selectedQuarter - $_selectedYear',
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<SingleAuditReportCategoryDetails>>(
            future: detailsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: FastCircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _CategoryDetailsFeedback(
                  title: 'Unable to load category report.',
                  actionLabel: 'Try Again',
                  onAction: _refreshSelectedCategory,
                );
              }

              final items =
                  snapshot.data ?? const <SingleAuditReportCategoryDetails>[];
              if (items.isEmpty) {
                return _CategoryDetailsFeedback(
                  title: 'No category details found.',
                  actionLabel: 'Refresh',
                  onAction: _refreshSelectedCategory,
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _CategoryDetailsCard(
                    item: items[index],
                    onTap: () => _openFinalReport(items[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openQuarterYearPicker() async {
    final options = _yearQuarterOptions();
    final selectedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInYearQuarterFilterSheet(
        options: options,
        initialValue: '$_selectedYear - Q$_selectedQuarter',
      ),
    );

    if (!mounted || selectedValue == null || selectedValue.trim().isEmpty) {
      return;
    }

    final parts = selectedValue.split('-');
    if (parts.length < 2) {
      return;
    }

    final year = int.tryParse(parts.first.trim());
    final quarter = int.tryParse(
      parts.last.trim().toUpperCase().replaceFirst('Q', ''),
    );
    if (year == null || quarter == null) {
      return;
    }

    if (year == _selectedYear && quarter == _selectedQuarter) {
      return;
    }

    setState(() {
      _selectedYear = year;
      _selectedQuarter = quarter;
    });
    await _loadCategories();
  }

  List<String> _yearQuarterOptions() {
    final currentYear = CustomFunctions.currentYearQuarter().year;
    final years = [currentYear - 1, currentYear, currentYear + 1];
    return years
        .expand(
          (year) => List<String>.generate(
            4,
            (index) => '$year - Q${index + 1}',
            growable: false,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      final categories = await context
          .read<CheckInController>()
          .loadAuditReport(
            quarter: _selectedQuarter,
            year: _selectedYear,
            profileJobId: widget.profileJobId,
          );

      final selectedCategory =
          _resolveSelectedCategory(categories) ??
          (categories.isNotEmpty ? categories.first : null);

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        _selectedCategoryId = selectedCategory?.uuid;
        _selectedCategoryTitle = selectedCategory?.categoryTitle;
        _detailsFuture = selectedCategory == null
            ? null
            : _loadDetailsForCategory(selectedCategory.uuid);
      });
    } catch (error) {
      setState(() {
        _isLoadingCategories = false;
        _categoriesError = error;
        _categories = const <AuditList>[];
        _detailsFuture = null;
      });
    }
  }

  AuditList? _resolveSelectedCategory(List<AuditList> categories) {
    final targetId = _selectedCategoryId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      for (final category in categories) {
        if (category.uuid == targetId) {
          return category;
        }
      }
    }

    final widgetCategoryId = widget.categoryId?.trim();
    if (widgetCategoryId != null && widgetCategoryId.isNotEmpty) {
      for (final category in categories) {
        if (category.uuid == widgetCategoryId) {
          return category;
        }
      }
    }

    return null;
  }

  void _selectCategory(AuditList item) {
    if (_selectedCategoryId == item.uuid) {
      return;
    }

    setState(() {
      _selectedCategoryId = item.uuid;
      _selectedCategoryTitle = item.categoryTitle;
      _detailsFuture = _loadDetailsForCategory(item.uuid);
    });
  }

  Future<List<SingleAuditReportCategoryDetails>> _loadDetailsForCategory(
    String categoryId,
  ) {
    return context.read<CheckInController>().loadAuditReportCategoryDetails(
      categoryId: categoryId,
      quarter: _selectedQuarter,
      year: _selectedYear,
    );
  }

  void _refreshSelectedCategory() {
    final categoryId = _selectedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      _loadCategories();
      return;
    }

    setState(() {
      _detailsFuture = _loadDetailsForCategory(categoryId);
    });
  }

  Future<void> _openFinalReport(SingleAuditReportCategoryDetails item) {
    final auditController = context.read<CheckInController>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CheckInController>.value(
          value: auditController,
          child: SeatDescriptionFinalCheckInReportScreen(
            flowFirstId: widget.profileJobId,
            descriptionId: item.jobDescriptionUuid,
            quarter: _selectedQuarter,
            year: _selectedYear,
          ),
        ),
      ),
    );
  }
}

class _CheckInCategorySelectorCard extends StatelessWidget {
  const _CheckInCategorySelectorCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final AuditList item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondaryColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondaryColor
                    : AppColors.grey1.withValues(alpha: 0.8),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppTextView.body1(
                  '${item.categoryTitle} (${item.weightPercent.toStringAsFixed(1)}%)',
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDetailsCard extends StatelessWidget {
  const _CategoryDetailsCard({required this.item, required this.onTap});

  final SingleAuditReportCategoryDetails item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextView.body1(
                item.description,
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CategoryStatText(
                      label: 'Confidence',
                      value: '${item.confidenceLevel}%',
                    ),
                  ),
                  Expanded(
                    child: _CategoryStatText(
                      label: 'Performance Percentage',
                      value: '${item.stats.totalPercentage}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AppTextView.body1(
                    'Ratings',
                    color: AppColors.grey1,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(width: 10),
                  _buildRatingBadge(
                    value: item.stats.totalGreat,
                    color: AppColors.green1,
                  ),
                  const SizedBox(width: 10),
                  _buildRatingBadge(
                    value: item.stats.totalAlmostThere,
                    color: AppColors.orange1,
                  ),
                  const SizedBox(width: 10),
                  _buildRatingBadge(
                    value: item.stats.totalNeedsImprovement,
                    color: AppColors.red1,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextView.body2(
                          AppStrings.view,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.north_east, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildRatingBadge({required int value, required Color color}) {
  return Container(
    alignment: Alignment.center,
    width: 30,
    height: 27,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: AppTextView.body2(
      '$value',
      color: AppColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _CategoryStatText extends StatelessWidget {
  const _CategoryStatText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body2(
          label,
          color: AppColors.grey1,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        const SizedBox(height: 6),
        AppTextView.body1(
          value,
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

class _CategoryDetailsFeedback extends StatelessWidget {
  const _CategoryDetailsFeedback({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextView.body1(
            title,
            color: AppColors.textPrimary,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
