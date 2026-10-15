import 'package:flutter/material.dart';

/// Presentation data shared by bottom navigation designs.
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
    this.selectionHorizontalPadding = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;

  /// Additional space on each side of the selected capsule.
  final double selectionHorizontalPadding;

  /// A null callback renders a disabled destination.
  final VoidCallback? onTap;
}
