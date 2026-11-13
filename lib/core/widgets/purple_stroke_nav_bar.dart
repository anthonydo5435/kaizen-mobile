import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../navigation/app_bottom_nav_item.dart';
import 'app_text_view.dart';

/// Builds the purple stroke design using the caller's tabs and tap callbacks.
Widget purpleStrokeNavBar({required List<AppBottomNavItem> items}) {
  final borderSide = BorderSide(color: AppColors.secondaryColor.withValues(alpha: 0.4));

  return DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(top: borderSide, left: borderSide, right: borderSide),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Expanded(
                  child: _PurpleStrokeNavItem(
                    label: item.label,
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    isSelected: item.isSelected,
                    onTap: item.onTap,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}

class _PurpleStrokeNavItem extends StatelessWidget {
  const _PurpleStrokeNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppColors.textSecondary.withValues(alpha: 0.38)
        : isSelected
        ? AppColors.secondaryColor
        : AppColors.textPrimary;

    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.secondaryColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isSelected ? selectedIcon : icon, size: 23, color: color),
                ),
                const SizedBox(height: 1),
                AppTextView.body3(
                  label,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  textAlign: TextAlign.center,
                  height: 1.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
