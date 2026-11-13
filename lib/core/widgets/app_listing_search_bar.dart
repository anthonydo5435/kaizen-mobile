import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'fast_circular_progress.dart';

/// The search field and filter sizing used by the main LMS listing.
class AppListingSearchBar extends StatelessWidget {
  const AppListingSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onFilterTap,
    this.onClearTap,
    this.filterTooltip = AppStrings.auditFiltersTitle,
    this.showClearButton = true,
    this.isSearchLoading = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClearTap;
  final String filterTooltip;
  final bool showClearButton;
  final bool isSearchLoading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.textScalerOf(context).scale(14) * 1.2 + 18).clamp(
      40.0,
      double.infinity,
    );

    return Row(
      children: [
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.grey1, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: AppColors.textPrimary,
                    cursorHeight: 15,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.2),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(color: AppColors.grey1),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (showClearButton)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      if (value.text.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      if (isSearchLoading) {
                        return SizedBox(
                          width: 32,
                          height: 38,
                          child: Center(
                            child: FastCircularProgressIndicator(width: 18, height: 18),
                          ),
                        );
                      }
                      return IconButton(
                        tooltip: AppStrings.clearSearch,
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 32, height: 38),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      );
                    },
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: filterTooltip,
            child: Material(
              color: AppColors.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onFilterTap,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.tune_rounded, color: AppColors.textPrimary, size: 23),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _clearSearch() {
    controller.clear();
    if (onClearTap != null) {
      onClearTap!();
    } else {
      onChanged?.call('');
    }
  }
}
