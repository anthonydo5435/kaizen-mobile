import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/main_navigation_controller.dart';
import 'app_bottom_nav_bar.dart';
import 'app_navigation_drawer.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.controller});

  final MainNavigationController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MainNavigationController>.value(
      value: controller,
      child: const _MainNavigationView(),
    );
  }
}

class _MainNavigationView extends StatelessWidget {
  const _MainNavigationView();

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<MainNavigationController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      // Sharing the bar's Scaffold keeps the drawer and scrim above the bar.
      drawer: AppNavigationDrawer(selectedMenu: navigation.selectedMenu),
      body: _MainNavigationPages(navigation: navigation),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : AppBottomNavBar(
              isVisible: navigation.isBottomNavigationVisible,
              selectedMenu: navigation.selectedMenu,
              onSelected: navigation.selectMenu,
            ),
    );
  }
}

/// Visited pages keep their providers and scroll state; inactive tickers pause.
class _MainNavigationPages extends StatelessWidget {
  const _MainNavigationPages({required this.navigation});

  final MainNavigationController navigation;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: navigation.selectedIndex,
      children: navigation.destinations.map((destination) {
        final isSelected = destination.menu == navigation.selectedMenu;
        return TickerMode(
          key: ValueKey((navigation.pageGeneration, destination.menu)),
          enabled: isSelected,
          child: ExcludeFocus(
            excluding: !isSelected,
            child: navigation.hasVisited(destination.menu)
                ? Builder(builder: destination.builder)
                : const SizedBox.shrink(),
          ),
        );
      }).toList(),
    );
  }
}
