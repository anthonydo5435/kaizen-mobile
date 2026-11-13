import 'package:flutter/material.dart';
import 'package:sparrowkaizen/core/widgets/liquid_glass_nav_bar.dart';

import '../constants/app_strings.dart';
import '../navigation/app_bottom_nav_item.dart';
import '../navigation/app_menu_type.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedMenu,
    required this.onSelected,
    this.isVisible = true,
  });

  final AppMenuType? selectedMenu;
  final ValueChanged<AppMenuType> onSelected;
  final bool isVisible;

  static const _destinations = [
    (
      menu: AppMenuType.library,
      label: AppStrings.trainingLibraryTitle,
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
    ),
    (
      menu: AppMenuType.audits,
      label: AppStrings.checkInTitle,
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
    ),
    (
      menu: AppMenuType.performanceSnapshot,
      label: AppStrings.bottomNavPerformance,
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
    ),
    (
      menu: AppMenuType.learningTracks,
      label: AppStrings.bottomNavLtc,
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Swap the design function here to try another style with the same tabs.
    return IgnorePointer(
      ignoring: !isVisible,
      child: ExcludeSemantics(
        excluding: !isVisible,
        child: AnimatedSlide(
          offset: isVisible ? Offset.zero : const Offset(0, 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: liquidGlassNavBar(items: _items),
        ),
      ),
    );
  }

  List<AppBottomNavItem> get _items => _destinations.map((destination) {
    return AppBottomNavItem(
      label: destination.label,
      icon: destination.icon,
      selectedIcon: destination.selectedIcon,
      isSelected: selectedMenu == destination.menu,
      selectionHorizontalPadding:
          destination.menu == AppMenuType.performanceSnapshot ? 8 : 0,
      onTap: () => onSelected(destination.menu),
    );
  }).toList();
}
