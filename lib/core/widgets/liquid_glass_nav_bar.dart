import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../navigation/app_bottom_nav_item.dart';
import 'app_text_view.dart';

/// A floating glass design using the same tabs and callbacks as the other styles.
Widget liquidGlassNavBar({required List<AppBottomNavItem> items}) {
  return _LiquidGlassNavBar(items: items);
}

class _LiquidGlassNavBar extends StatelessWidget {
  const _LiquidGlassNavBar({required this.items});

  static const double _horizontalInset = 12;

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
      minimum: const EdgeInsets.fromLTRB(
        _horizontalInset,
        10,
        _horizontalInset,
        14,
      ),
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
        child: _GlassSurface(
          highContrast: highContrast,
          child: _GlassDestinations(items: items, duration: duration),
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.highContrast, required this.child});

  final bool highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(
      color: AppColors.textPrimary.withValues(alpha: highContrast ? 0.4 : 0.16),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        enabled: !highContrast,
        child: Material(
          color: AppColors.surfaceDark.withValues(
            alpha: highContrast ? 1 : 0.72,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.fromBorderSide(edge),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.textPrimary.withValues(alpha: 0.14),
                  AppColors.textPrimary.withValues(alpha: 0.025),
                  AppColors.secondaryColor.withValues(alpha: 0.08),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: Padding(padding: const EdgeInsets.all(4), child: child),
          ),
        ),
      ),
    );
  }
}

/// The row sets its own height so larger text can grow the glass surface.
class _GlassDestinations extends StatelessWidget {
  const _GlassDestinations({required this.items, required this.duration});

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
                  items.length == 1
                      ? 0
                      : -1 + 2 * selectedIndex / (items.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  child: _GlassSelectionLens(
                    horizontalPadding:
                        items[selectedIndex].selectionHorizontalPadding,
                  ),
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Expanded(
                  child: _GlassNavItem(item: item, duration: duration),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _GlassSelectionLens extends StatelessWidget {
  const _GlassSelectionLens({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(
      color: AppColors.textPrimary.withValues(alpha: 0.22),
    );

    return LayoutBuilder(
      builder: (context, constraints) => OverflowBox(
        minWidth: constraints.maxWidth + horizontalPadding * 2,
        maxWidth: constraints.maxWidth + horizontalPadding * 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(top: edge, left: edge, right: edge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.textPrimary.withValues(alpha: 0.2),
                AppColors.secondaryColor.withValues(alpha: 0.15),
                AppColors.textPrimary.withValues(alpha: 0.065),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({required this.item, required this.duration});

  final AppBottomNavItem item;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = item.onTap == null
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : item.isSelected
        ? AppColors.lightPurple1
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
                    fontWeight: item.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
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
