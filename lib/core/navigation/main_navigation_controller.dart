import 'package:flutter/widgets.dart';

import 'app_menu_type.dart';

class MainNavigationDestination {
  const MainNavigationDestination({
    required this.menu,
    required this.routeName,
    required this.builder,
  });

  final AppMenuType menu;
  final String routeName;
  final WidgetBuilder builder;
}

/// Owns the selected page and lazily mounts destinations for this app session.
class MainNavigationController extends ChangeNotifier {
  MainNavigationController({
    required List<MainNavigationDestination> destinations,
    required AppMenuType initialMenu,
    bool Function(AppMenuType)? canSelectMenu,
  }) : assert(
         destinations.any((destination) => destination.menu == initialMenu),
       ),
       destinations = List.unmodifiable(destinations),
       _selectedMenu = initialMenu,
       _visitedMenus = {initialMenu},
       _canSelectMenu = canSelectMenu;

  final List<MainNavigationDestination> destinations;
  final bool Function(AppMenuType)? _canSelectMenu;
  final Set<AppMenuType> _visitedMenus;
  final Set<AppMenuType> _menusWithHiddenNavigation = {};
  AppMenuType _selectedMenu;
  int _pageGeneration = 0;

  AppMenuType get selectedMenu => _selectedMenu;
  int get pageGeneration => _pageGeneration;
  int get selectedIndex => destinations.indexWhere(
    (destination) => destination.menu == _selectedMenu,
  );
  String get selectedRouteName => destinations[selectedIndex].routeName;
  bool get isBottomNavigationVisible =>
      !_menusWithHiddenNavigation.contains(_selectedMenu);

  void setNavigationBarsVisible(AppMenuType menu, bool visible) {
    final changed = visible
        ? _menusWithHiddenNavigation.remove(menu)
        : _menusWithHiddenNavigation.add(menu);
    if (changed && menu == _selectedMenu) {
      notifyListeners();
    }
  }

  bool hasVisited(AppMenuType menu) => _visitedMenus.contains(menu);

  /// Discards pages when the account or organization changes.
  void resetPages() {
    _menusWithHiddenNavigation.clear();
    _selectedMenu = destinations.first.menu;
    _visitedMenus
      ..clear()
      ..add(_selectedMenu);
    _pageGeneration++;
    notifyListeners();
  }

  void selectMenu(AppMenuType menu) {
    if (menu == _selectedMenu ||
        !destinations.any((destination) => destination.menu == menu) ||
        !(_canSelectMenu?.call(menu) ?? true)) {
      return;
    }

    _selectedMenu = menu;
    _visitedMenus.add(menu);
    notifyListeners();
  }
}
