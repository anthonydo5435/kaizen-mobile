import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../core/widgets/app_seat_selection_tile.dart';
import '../../../../core/widgets/app_selection_sheet.dart';
import '../../../../core/widgets/app_text_view.dart';

class CheckInSeatProfileFilterSheet extends StatefulWidget {
  const CheckInSeatProfileFilterSheet({
    super.key,
    required this.options,
    this.initialValue,
    this.showAllOption = false,
    this.allOptionLabel = 'All Seat Profiles',
    this.title = AppStrings.auditSeatProfile,
    this.searchHint = AppStrings.auditSearchSeatProfile,
    this.compactSpacing = false,
    this.rowSpacing,
    this.showCloseHeader = false,
    this.centerTitle = false,
  });

  final List<String> options;
  final String? initialValue;
  final bool showAllOption;
  final String allOptionLabel;
  final String title;
  final String searchHint;
  final bool compactSpacing;
  final double? rowSpacing;
  final bool showCloseHeader;
  final bool centerTitle;

  @override
  State<CheckInSeatProfileFilterSheet> createState() =>
      _CheckInSeatProfileFilterSheetState();
}

class _CheckInSeatProfileFilterSheetState
    extends State<CheckInSeatProfileFilterSheet> {
  String? _selectedValue;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.showAllOption
        ? (widget.initialValue ?? '')
        : widget.initialValue;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacingScale = widget.compactSpacing ? 0.5 : 1.0;
    final rowSpacing = widget.rowSpacing ?? 18 * spacingScale;
    final filteredOptions = widget.options
        .where((option) {
          if (_searchQuery.trim().isEmpty) {
            return true;
          }

          return option.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          );
        })
        .toList(growable: false);

    return SafeArea(
      top: false,
      bottom: false,
      child: AppKeyboardBottomSheetSurface(
        height: MediaQuery.of(context).size.height * 0.78,
        color: AppColors.mainBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: EdgeInsets.only(bottom: 24 * spacingScale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showCloseHeader)
                AppFilterSheetHeader(
                  title: widget.title,
                  centerTitle: widget.centerTitle,
                  onClose: () => Navigator.of(context).pop(),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 24 * spacingScale, 20, 0),
                  child: Column(
                    children: [
                      _SelectionHeader(
                        title: widget.title,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(height: 22 * spacingScale),
                      const AppDotDivider(),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.showCloseHeader ? 4 : 24 * spacingScale,
                    20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SeatProfileSearchBar(
                        controller: _searchController,
                        hintText: widget.searchHint,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      SizedBox(height: 22 * spacingScale),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (widget.showAllOption)
                                Padding(
                                  padding: EdgeInsets.only(bottom: rowSpacing),
                                  child: AppSeatSelectionTile(
                                    title: widget.allOptionLabel,
                                    isSelected: _selectedValue == '',
                                    onTap: () {
                                      setState(() {
                                        _selectedValue = '';
                                      });
                                    },
                                  ),
                                ),
                              ...filteredOptions.map(
                                (option) => Padding(
                                  padding: EdgeInsets.only(bottom: rowSpacing),
                                  child: AppSeatSelectionTile(
                                    title: option,
                                    isSelected: _selectedValue == option,
                                    onTap: () {
                                      setState(() {
                                        _selectedValue = option;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * spacingScale),
                      const AppDotDivider(),
                      SizedBox(height: 22 * spacingScale),
                      AppButton(
                        text: AppStrings.done,
                        onPressed:
                            (!widget.showAllOption && _selectedValue == null)
                            ? null
                            : () => Navigator.of(context).pop(_selectedValue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatProfileSearchBar extends StatelessWidget {
  const _SeatProfileSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.75),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorHeight: 16,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        cursorColor: AppColors.textPrimary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: SvgPicture.asset(
            '${AppStrings.imagePath}back.svg',
            width: 24,
            height: 24,
          ),
        ),
        Expanded(
          child: AppTextView.title(
            title,
            color: AppColors.secondaryColor,
            fontSize: 20,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}
