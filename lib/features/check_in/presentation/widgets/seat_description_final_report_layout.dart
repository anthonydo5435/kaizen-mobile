part of '../pages/seat_description_final_check_in_report.dart';

class _TimeRangeDropdown extends StatelessWidget {
  const _TimeRangeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final FinalCheckInReportTimeRange value;
  final List<FinalCheckInReportTimeRange> items;
  final ValueChanged<FinalCheckInReportTimeRange?> onChanged;

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
        child: DropdownButton<FinalCheckInReportTimeRange>(
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
                (item) => DropdownMenuItem<FinalCheckInReportTimeRange>(
                  value: item,
                  child: Text(item.label),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
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

class _FinalReportHeader extends StatelessWidget {
  const _FinalReportHeader();

  @override
  Widget build(BuildContext context) {
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
            AppStrings.finalCheckInReportTitle,
            color: AppColors.secondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
