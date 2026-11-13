import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../navigation/app_bottom_nav_item.dart';
import 'app_text_view.dart';

/// A floating purple-outlined capsule using the caller's tabs and callbacks.
Widget circularStrokeNavBar({required List<AppBottomNavItem> items}) {
  return SafeArea(
    top: false,
    bottom: false,
    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Material(
      color: AppColors.surfaceDark,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.secondaryColor.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: items
              .map((item) => Expanded(child: _CirularStrokeNavItem(item: item)))
              .toList(),
        ),
      ),
    ),
  );
}

class _CirularStrokeNavItem extends StatelessWidget {
  const _CirularStrokeNavItem({required this.item});

  final AppBottomNavItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.onTap == null
        ? AppColors.textSecondary.withValues(alpha: 0.38)
        : item.isSelected
        ? AppColors.secondaryColor
        : AppColors.textPrimary;

    return Semantics(
      label: item.label,
      button: true,
      selected: item.isSelected,
      enabled: item.onTap != null,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: ShapeDecoration(
          color: item.isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.16)
              : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: item.isSelected
                  ? AppColors.secondaryColor.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.isSelected ? item.selectedIcon : item.icon, size: 23, color: color),
                      const SizedBox(height: 3),
                      AppTextView.body3(
                        item.label,
                        color: color,
                        fontSize: 11,
                        fontWeight: item.isSelected ? FontWeight.w700 : FontWeight.w500,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        height: 1.2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
