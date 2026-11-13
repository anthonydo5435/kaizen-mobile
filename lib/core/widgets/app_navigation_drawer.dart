import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes/app_router.dart';
import '../constants/app_strings.dart';
import '../managers/app_manager.dart';
import '../navigation/app_menu_type.dart';
import '../utils/auth_controller.dart';
import '../utils/custom_functions.dart';
import 'app_confirmation_dialog.dart';
import 'app_drawer.dart';

/// Connects the same drawer actions to the shell and standalone screens.
class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.selectedMenu,
    this.image,
    this.imageUrl,
  });

  final AppMenuType? selectedMenu;
  final String? image;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppManager>(
      builder: (context, appManager, _) {
        final user = appManager.currentUser;
        return AppDrawer(
          name: CustomFunctions.resolveName(user),
          currentOrganizationName: appManager.isRefreshingOrganizationContext
              ? AppStrings.organizationsFetching
              : appManager.currentOrganizationName,
          isSandboxMode: appManager.usesParentApiEndpoints,
          selectedMenu: selectedMenu,
          onProfileTap: () =>
              _openPage(context, AppMenuType.profile, AppRouter.profile),
          onComplianceTap: () =>
              _openPage(context, AppMenuType.compliance, AppRouter.compliance),
          onSeatProfilesTap: () => _openPage(
            context,
            AppMenuType.seatProfiles,
            AppRouter.seatProfiles,
          ),
          onPaygradesTap: () =>
              _openPage(context, AppMenuType.paygrades, AppRouter.paygrades),
          onDepartmentsTap: () => _openPage(
            context,
            AppMenuType.departments,
            AppRouter.departments,
          ),
          onKaizenGptTap: () =>
              _openPage(context, AppMenuType.kaizenGpt, AppRouter.kaizenGpt),
          onSettingTap: () =>
              _openPage(context, AppMenuType.setting, AppRouter.onboarding),
          onDrawerHeaderTap: () =>
              _openPage(context, AppMenuType.profile, AppRouter.profile),
          onOrganizationTap: () => appManager.openOrganizationsScreen(),
          onLogoutTap: () => _showLogoutConfirmation(context),
          image: image ?? user?.image,
          imageUrl: imageUrl ?? user?.imageUrl,
        );
      },
    );
  }

  void _openPage(BuildContext context, AppMenuType menu, String routeName) {
    if (selectedMenu == menu) return;
    AppRouter.pushNamed<void>(context, routeName);
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppConfirmationDialog(
        title: AppStrings.authLogout,
        description: AppStrings.authLogoutConfirmationDescription,
        onCancelCallback: () async {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        },
        onConfirmCallback: () async {
          Navigator.of(dialogContext, rootNavigator: true).pop();
          await AuthController.logout();
        },
      ),
    );
  }
}
