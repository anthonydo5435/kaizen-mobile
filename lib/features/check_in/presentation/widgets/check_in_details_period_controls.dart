import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../providers/check_in_controller.dart';

class CheckInDetailsPeriodControls extends StatelessWidget {
  const CheckInDetailsPeriodControls({
    super.key,
    required this.mode,
    required this.year,
    required this.quarter,
    required this.yearOptions,
    required this.dateRangeLabel,
    required this.onModeChanged,
    required this.onQuarterChanged,
    required this.onDateRangePressed,
  });

  final CheckInDetailsPeriodMode mode;
  final int year;
  final int quarter;
  final List<int> yearOptions;
  final String dateRangeLabel;
  final ValueChanged<CheckInDetailsPeriodMode> onModeChanged;
  final ValueChanged<String?> onQuarterChanged;
  final VoidCallback onDateRangePressed;

  @override
  Widget build(BuildContext context) {
    final toggle = _PeriodModeToggle(mode: mode, onChanged: onModeChanged);
    final selector = _buildSelector(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
        // Give the selector a full row when enlarged text needs more room.
        if (constraints.maxWidth < 260 * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: toggle),
              const SizedBox(height: 8),
              selector,
            ],
          );
        }
        return Row(
          children: [
            toggle,
            const SizedBox(width: 8),
            Expanded(child: selector),
          ],
        );
      },
    );
  }

  Widget _buildSelector(BuildContext context) {
    final isQuarter = mode == CheckInDetailsPeriodMode.quarter;
    final contentHeight = math.max(24.0, MediaQuery.textScalerOf(context).scale(12) * 1.4 + 6);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary),
    );
    final decoration = InputDecoration(
      labelText: isQuarter ? AppStrings.auditSelectYearQuarter : AppStrings.auditDateRange,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: border,
      enabledBorder: border,
    );
    final content = Row(
      children: [
        Expanded(
          child: AppTextView.body(
            isQuarter ? AppStrings.auditQuarterPeriodLabel(year, quarter) : dateRangeLabel,
            fontSize: 12,
            height: 1.4,
            color: AppColors.textPrimary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isQuarter ? Icons.arrow_drop_down : Icons.calendar_month_outlined,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ],
    );
    final field = InputDecorator(
      key: const ValueKey('check-in-details-period-selector'),
      decoration: decoration,
      child: SizedBox(height: contentHeight, child: content),
    );
    if (isQuarter) {
      return _QuarterSelectorMenu(
        year: year,
        quarter: quarter,
        yearOptions: yearOptions,
        onChanged: onQuarterChanged,
        child: field,
      );
    }
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('check-in-details-date-range'),
        onTap: onDateRangePressed,
        borderRadius: BorderRadius.circular(12),
        child: field,
      ),
    );
  }
}

class _QuarterSelectorMenu extends StatefulWidget {
  const _QuarterSelectorMenu({
    required this.year,
    required this.quarter,
    required this.yearOptions,
    required this.onChanged,
    required this.child,
  });

  final int year;
  final int quarter;
  final List<int> yearOptions;
  final ValueChanged<String?> onChanged;
  final Widget child;

  @override
  State<_QuarterSelectorMenu> createState() => _QuarterSelectorMenuState();
}

class _QuarterSelectorMenuState extends State<_QuarterSelectorMenu> {
  final MenuController _menuController = MenuController();
  late final ValueNotifier<({int year, bool choosingYear})> _selection;

  @override
  void initState() {
    super.initState();
    _selection = ValueNotifier((year: widget.year, choosingYear: false));
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<({int year, bool choosingYear})>(
        valueListenable: _selection,
        builder: (context, selection, _) => MenuAnchor(
          controller: _menuController,
          crossAxisUnconstrained: false,
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceDark3),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, double.infinity)),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          menuChildren: [
            MenuItemButton(
              key: const ValueKey('check-in-quarter-year-header'),
              closeOnActivate: false,
              style: _optionStyle(false, constraints.maxWidth),
              onPressed: () =>
                  _selection.value = (year: selection.year, choosingYear: !selection.choosingYear),
              trailingIcon: Icon(
                selection.choosingYear ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: AppColors.textPrimary,
                size: 20,
              ),
              child: AppTextView.body(
                '${selection.year}',
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Divider(height: 12, color: AppColors.fieldBorder.withValues(alpha: 0.35)),
            if (selection.choosingYear)
              ...widget.yearOptions.map(
                (year) => MenuItemButton(
                  key: ValueKey('check-in-quarter-year-$year'),
                  closeOnActivate: false,
                  style: _optionStyle(year == selection.year, constraints.maxWidth),
                  onPressed: () => _selection.value = (year: year, choosingYear: false),
                  child: AppTextView.body('$year', fontSize: 12, color: AppColors.textPrimary),
                ),
              )
            else
              ...List.generate(4, (index) {
                final quarter = index + 1;
                final selected = selection.year == widget.year && quarter == widget.quarter;
                return MenuItemButton(
                  key: ValueKey('check-in-quarter-option-${selection.year}-$quarter'),
                  style: _optionStyle(selected, constraints.maxWidth),
                  onPressed: () => widget.onChanged('${selection.year} - Q$quarter'),
                  child: AppTextView.body(
                    AppStrings.auditQuarterOptionLabel(quarter),
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }),
          ],
          builder: (context, controller, _) => Semantics(
            button: true,
            child: InkWell(
              key: const ValueKey('check-in-details-quarter-selector'),
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  _selection.value = (year: widget.year, choosingYear: false);
                  controller.open();
                }
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _optionStyle(bool selected, double menuWidth) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (selected) return AppColors.secondaryColor;
      if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
        return AppColors.surfaceDark1;
      }
      return Colors.transparent;
    }),
    minimumSize: WidgetStatePropertyAll(Size(menuWidth - 16, 40)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  );
}

class _PeriodModeToggle extends StatelessWidget {
  const _PeriodModeToggle({required this.mode, required this.onChanged});

  final CheckInDetailsPeriodMode mode;
  final ValueChanged<CheckInDetailsPeriodMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CheckInDetailsPeriodMode.values
            .map((value) {
              final selected = value == mode;
              final isQuarter = value == CheckInDetailsPeriodMode.quarter;
              return Semantics(
                selected: selected,
                inMutuallyExclusiveGroup: true,
                button: true,
                label: isQuarter ? AppStrings.auditQuarter : AppStrings.auditDateRange,
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: selected
                          ? const LinearGradient(
                              colors: [AppColors.secondaryColor, AppColors.purple1],
                            )
                          : null,
                    ),
                    child: InkWell(
                      onTap: () => onChanged(value),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: AppTextView.body(
                          isQuarter ? AppStrings.auditQuarterMode : AppStrings.auditDateRangeMode,
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
