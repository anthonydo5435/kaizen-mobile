import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_selection_sheet.dart';
import '../../../../core/widgets/app_text_view.dart';
import 'check_in_seat_profile_filter_sheet.dart';
import 'check_in_year_quarter_filter_sheet.dart';

class CheckInFilterResult {
  const CheckInFilterResult({this.yearQuarter, this.seatProfile});

  final String? yearQuarter;
  final String? seatProfile;
}

class CheckInFilterSheet extends StatefulWidget {
  const CheckInFilterSheet({
    super.key,
    required this.yearQuarterOptions,
    required this.seatProfileOptions,
    this.initialYearQuarter,
    this.initialSeatProfile,
    this.showSeatProfile = true,
  });

  final List<String> yearQuarterOptions;
  final List<String> seatProfileOptions;
  final String? initialYearQuarter;
  final String? initialSeatProfile;
  final bool showSeatProfile;

  @override
  State<CheckInFilterSheet> createState() => _CheckInFilterSheetState();
}

class _CheckInFilterSheetState extends State<CheckInFilterSheet> {
  late final ValueNotifier<CheckInFilterResult> _selection;

  @override
  void initState() {
    super.initState();
    _selection = ValueNotifier<CheckInFilterResult>(
      CheckInFilterResult(
        yearQuarter: widget.initialYearQuarter,
        seatProfile: widget.initialSeatProfile,
      ),
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ValueListenableBuilder<CheckInFilterResult>(
          valueListenable: _selection,
          builder: (context, selection, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFilterSheetHeader(
                  title: AppStrings.auditFiltersTitle,
                  centerTitle: true,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showSeatProfile) ...[
                        _FilterSelectionTile(
                          title: AppStrings.auditSeatProfile,
                          value: selection.seatProfile,
                          onTap: () => _openSeatProfileSheet(context),
                        ),
                        const SizedBox(height: 28),
                      ],
                      _FilterSelectionTile(
                        title: AppStrings.auditSelectYearQuarter,
                        value: selection.yearQuarter,
                        onTap: () => _openYearQuarterSheet(context),
                      ),
                      const SizedBox(height: 26),
                      const AppDotDivider(),
                      const SizedBox(height: 22),
                      AppButton(
                        text: AppStrings.auditApplyFilters,
                        onPressed: () {
                          Navigator.of(context).pop(selection);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSeatProfileSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CheckInSeatProfileFilterSheet(
        options: widget.seatProfileOptions,
        initialValue: _selection.value.seatProfile,
        compactSpacing: true,
        showCloseHeader: true,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _selection.value = CheckInFilterResult(
      yearQuarter: _selection.value.yearQuarter,
      seatProfile: result,
    );
  }

  Future<void> _openYearQuarterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CheckInYearQuarterFilterSheet(
        options: widget.yearQuarterOptions,
        initialValue: _selection.value.yearQuarter,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _selection.value = CheckInFilterResult(
      yearQuarter: result,
      seatProfile: _selection.value.seatProfile,
    );
  }
}

class _FilterSelectionTile extends StatelessWidget {
  const _FilterSelectionTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.grey1.withValues(alpha: 0.75),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTextView.body(
                  value ?? title,
                  color: value == null
                      ? AppColors.grey1
                      : AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textPrimary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
