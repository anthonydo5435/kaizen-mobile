import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../navigation/app_bottom_nav_item.dart';
import 'app_text_view.dart';

//
/// An opaque dark capsule using the same tabs and callbacks as the other styles.
Widget circularDarkNavBar({required List<AppBottomNavItem> items}) {
  return _CircularDarkNavBar(items: items);
}

class _CircularDarkNavBar extends StatelessWidget {
  const _CircularDarkNavBar({required this.items});

  final List<AppBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _DarkSurface(
          highContrast: highContrast,
          child: _DarkDestinations(items: items, duration: duration),
        ),
      ),
    );
  }
}

class _DarkSurface extends StatelessWidget {
  const _DarkSurface({required this.highContrast, required this.child});

  final bool highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppColors.textPrimary.withValues(alpha: highContrast ? 0.4 : 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}

/// The row sets its own height so larger text can grow the dark surface.
class _DarkDestinations extends StatelessWidget {
  const _DarkDestinations({required this.items, required this.duration});

  final List<AppBottomNavItem> items;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.isSelected);

    return Stack(
      children: [
        if (selectedIndex >= 0)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: AlignmentDirectional(
                  items.length == 1 ? 0 : -1 + 2 * selectedIndex / (items.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  child: const _DarkSelectionPill(),
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Expanded(
                  child: _DarkNavItem(item: item, duration: duration),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DarkSelectionPill extends StatelessWidget {
  const _DarkSelectionPill();

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.22));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.purple2,
        borderRadius: BorderRadius.circular(24),
        border: Border(top: edge, left: edge, right: edge),
      ),
    );
  }
}

class _DarkNavItem extends StatelessWidget {
  const _DarkNavItem({required this.item, required this.duration});

  final AppBottomNavItem item;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = item.onTap == null
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : AppColors.textPrimary;

    return Semantics(
      label: item.label,
      button: true,
      selected: item.isSelected,
      enabled: item.onTap != null,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.12),
        highlightColor: AppColors.textPrimary.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: item.isSelected ? 1.05 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      item.isSelected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppTextView.body3(
                    item.label,
                    color: color,
                    fontWeight: item.isSelected ? FontWeight.w700 : FontWeight.w500,
                    textAlign: TextAlign.center,
                    height: 1.2,
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
