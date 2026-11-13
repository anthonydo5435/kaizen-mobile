import 'package:flutter/material.dart';

import '../managers/app_manager.dart';
import '../widgets/main_navigation_shell.dart';
import 'app_menu_type.dart';
import 'main_navigation_controller.dart';

/// Keeps named-route reporting accurate while the shell switches pages in place.
class MainNavigationRoute extends MaterialPageRoute<dynamic> {
  factory MainNavigationRoute({
    required RouteSettings settings,
    required List<MainNavigationDestination> destinations,
    required AppMenuType initialMenu,
    bool Function(AppMenuType)? canSelectMenu,
    ValueChanged<String>? onRouteNameChanged,
  }) {
    final controller = MainNavigationController(
      destinations: destinations,
      initialMenu: initialMenu,
      canSelectMenu: canSelectMenu,
    );
    return MainNavigationRoute._(
      settings: settings,
      navigationController: controller,
      onRouteNameChanged: onRouteNameChanged,
    );
  }

  MainNavigationRoute._({
    required RouteSettings settings,
    required this.navigationController,
    required this.onRouteNameChanged,
  }) : super(
         settings: settings,
         builder: (_) => MainNavigationShell(controller: navigationController),
       ) {
    navigationController.addListener(_handleSelection);
    AppManager.instance.addListener(_handleSessionContext);
  }

  final MainNavigationController navigationController;
  final ValueChanged<String>? onRouteNameChanged;
  Object _sessionContext = _readSessionContext();

  static Object _readSessionContext() {
    final manager = AppManager.instance;
    return (
      manager.currentUser?.uuid,
      manager.currentOrganizationId,
      manager.usesParentApiEndpoints,
    );
  }

  void _handleSessionContext() {
    final nextContext = _readSessionContext();
    if (_sessionContext == nextContext) {
      return;
    }
    _sessionContext = nextContext;
    navigationController.resetPages();
  }

  @override
  RouteSettings get settings => RouteSettings(
    name: navigationController.selectedRouteName,
    arguments: super.settings.arguments,
  );

  void _handleSelection() {
    changedInternalState();
    if (isCurrent) {
      onRouteNameChanged?.call(navigationController.selectedRouteName);
    }
  }

  @override
  void dispose() {
    AppManager.instance.removeListener(_handleSessionContext);
    navigationController.removeListener(_handleSelection);
    navigationController.dispose();
    super.dispose();
  }
}
