import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../navigation/app_menu_type.dart';
import 'app_text_view.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.name,
    required this.currentOrganizationName,
    required this.isSandboxMode,
    this.image,
    this.imageUrl,
    required this.selectedMenu,
    this.onProfileTap,
    this.onComplianceTap,
    this.onSeatProfilesTap,
    this.onPaygradesTap,
    this.onDepartmentsTap,
    this.onKaizenGptTap,
    this.onSettingTap,
    this.onDrawerHeaderTap,
    this.onOrganizationTap,
    this.onLogoutTap,
  });

  final String name;
  final String currentOrganizationName;
  final bool isSandboxMode;
  final String? image;
  final String? imageUrl;
  final AppMenuType? selectedMenu;
  final VoidCallback? onProfileTap;
  final VoidCallback? onComplianceTap;
  final VoidCallback? onSeatProfilesTap;
  final VoidCallback? onPaygradesTap;
  final VoidCallback? onDepartmentsTap;
  final VoidCallback? onKaizenGptTap;
  final VoidCallback? onSettingTap;
  final VoidCallback? onDrawerHeaderTap;
  final VoidCallback? onOrganizationTap;
  final VoidCallback? onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceDark,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._buildModuleItems(context),
                      const SizedBox(height: 8),
                      _buildOrganizationRow(context),
                    ],
                  ),
                ),
              ],
            ),

            Align(alignment: Alignment.bottomCenter, child: _buildLogoutSection(context)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModuleItems(BuildContext context) {
    if (isSandboxMode) {
      return [
        _buildDrawerItem(
          context,
          icon: Icons.event_seat_outlined,
          title: AppStrings.homeSeatProfiles,
          isSelected: selectedMenu == AppMenuType.seatProfiles,
          onTap: onSeatProfilesTap,
        ),
        _buildDrawerItem(
          context,
          icon: Icons.payments_outlined,
          title: AppStrings.homePaygrades,
          isSelected: selectedMenu == AppMenuType.paygrades,
          onTap: onPaygradesTap,
        ),
        _buildDrawerItem(
          context,
          icon: Icons.account_tree_outlined,
          title: AppStrings.homeDepartments,
          isSelected: selectedMenu == AppMenuType.departments,
          onTap: onDepartmentsTap,
        ),
      ];
    }

    return [
      // _buildDrawerItem(
      //   context,
      //   icon: Icons.auto_awesome_outlined,
      //   title: AppStrings.homeAi,
      //   isSelected: selectedMenu == AppMenuType.kaizenGpt,
      //   onTap: onKaizenGptTap,
      // ),
      _buildDrawerItem(
        context,
        icon: Icons.folder_open_outlined,
        title: AppStrings.homeDocumentCenter,
        isSelected: selectedMenu == AppMenuType.compliance,
        onTap: onComplianceTap,
      ),
      _buildDrawerItem(
        context,
        icon: Icons.event_seat_outlined,
        title: AppStrings.homeSeatProfiles,
        isSelected: selectedMenu == AppMenuType.seatProfiles,
        onTap: onSeatProfilesTap,
      ),
      _buildDrawerItem(
        context,
        icon: Icons.payments_outlined,
        title: AppStrings.homePaygrades,
        isSelected: selectedMenu == AppMenuType.paygrades,
        onTap: onPaygradesTap,
      ),
      _buildDrawerItem(
        context,
        icon: Icons.account_tree_outlined,
        title: AppStrings.homeDepartments,
        isSelected: selectedMenu == AppMenuType.departments,
        onTap: onDepartmentsTap,
      ),
    ];
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: GestureDetector(
        onTap: onDrawerHeaderTap,
        child: Row(
          children: [
            _ProfileAvatar(imagePath: image, imageUrl: imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: AppTextView.body1(
                name,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    Color? color,
    VoidCallback? onTap,
  }) {
    final resolvedColor = color ?? (isSelected ? AppColors.secondaryColor : AppColors.textPrimary);

    return ListTile(
      leading: Icon(icon, color: resolvedColor),
      title: AppTextView.body2(title, color: resolvedColor, fontWeight: FontWeight.w600),
      selected: isSelected,
      selectedTileColor: AppColors.secondaryColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
    );
  }

  Widget _buildLogoutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _buildDrawerItem(
        context,
        icon: Icons.logout_rounded,
        title: AppStrings.authLogout,
        isSelected: false,
        color: AppColors.red,
        onTap: onLogoutTap,
      ),
    );
  }

  Widget _buildOrganizationRow(BuildContext context) {
    final organizationName = currentOrganizationName.trim().isEmpty
        ? AppStrings.organizationsNoActiveOrganization
        : currentOrganizationName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: AppColors.textPrimary.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          Material(
            color: AppColors.surfaceDark3.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).pop();
                onOrganizationTap?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_outlined, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextView.body4(
                            AppStrings.organizationsCurrentLabel,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                          const SizedBox(height: 4),
                          AppTextView.body2(
                            organizationName,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppTextView.body4(
                      AppStrings.organizationsChangeAction,
                      color: AppColors.secondaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImageProvider();

    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark3,
        border: Border.all(color: AppColors.secondaryColor, width: 2),
        image: provider == null ? null : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary, size: 48)
          : null,
    );
  }

  ImageProvider<Object>? _resolveImageProvider() {
    final candidates = [imagePath, imageUrl];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      if (value.startsWith('http')) {
        return CachedNetworkImageProvider(value);
      }

      final file = File(value);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    return null;
  }
}
