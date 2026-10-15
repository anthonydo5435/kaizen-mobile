import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/organization.dart';

class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appManager = context.watch<AppManager>();
    final organizations = appManager.visibleOrganizations;
    final sandboxOrganizations = organizations
        .where(_isSandboxOrganization)
        .toList(growable: false);
    final otherOrganizations = organizations
        .where((organization) => !_isSandboxOrganization(organization))
        .toList(growable: false);
    final sandboxOrderedOrganizations = <Organization>[
      ...sandboxOrganizations,
      ...otherOrganizations,
    ];
    final primaryOrganizations = sandboxOrderedOrganizations
        .where((organization) => !_isChildOrganizationType(organization))
        .toList(growable: false);
    final childOrganizations = sandboxOrderedOrganizations
        .where(_isChildOrganizationType)
        .toList(growable: false);
    final orderedOrganizations = <Organization>[
      ...primaryOrganizations,
      ...childOrganizations,
    ];
    final selectedOrganizationId = appManager.currentOrganizationId;

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || !appManager.hasPendingOrganizationConflict) {
          return;
        }

        unawaited(appManager.resolveOrganizationConflictFromBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBg,
        appBar: AppBar(
          backgroundColor: AppColors.mainBg,
          foregroundColor: AppColors.textPrimary,
          title: AppTextView.title1(
            AppStrings.organizationsTitle,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextView.body2(
                  AppStrings.organizationsSandboxNote,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.left,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      appManager.isLoadingOrganizations && organizations.isEmpty
                      ? Center(child: FastCircularProgressIndicator())
                      : organizations.isEmpty
                      ? Center(
                          child: AppTextView.body(
                            AppStrings.organizationsNoItemsFound,
                            color: AppColors.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: orderedOrganizations.length,
                          itemBuilder: (context, index) {
                            final organization = orderedOrganizations[index];
                            final isLoading =
                                appManager.activatingOrganizationId ==
                                organization.id;
                            final isSelected =
                                organization.id == selectedOrganizationId;
                            final isLastItem =
                                index == orderedOrganizations.length - 1;
                            final showChildTypeDivider =
                                primaryOrganizations.isNotEmpty &&
                                childOrganizations.isNotEmpty &&
                                index == primaryOrganizations.length - 1;

                            return Column(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: appManager.isSettingActiveOrganization
                                      ? null
                                      : () => _handleOrganizationTap(
                                          context,
                                          appManager,
                                          organization.id,
                                        ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.secondaryColor.withValues(
                                              alpha: 0.20,
                                            )
                                          : AppColors.surfaceDark,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.lightPurple3.withValues(
                                                alpha: 0.85,
                                              )
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AppTextView.body2(
                                            organization.name,
                                            color: isSelected
                                                ? AppColors.textPrimary
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (isLoading)
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                FastCircularProgressIndicator(),
                                          )
                                        else if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.textPrimary,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (!isLastItem) ...[
                                  if (showChildTypeDivider) ...[
                                    const SizedBox(height: 12),
                                    const AppDotDivider(),
                                  ],
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSandboxOrganization(Organization organization) {
    return organization.name.trim().toLowerCase().contains('sandbox');
  }

  bool _isChildOrganizationType(Organization organization) {
    return organization.type.trim().toLowerCase().contains('child');
  }

  Future<void> _handleOrganizationTap(
    BuildContext context,
    AppManager appManager,
    String organizationId,
  ) async {
    final isSuccess = await appManager.setActiveOrganization(organizationId);
    if (isSuccess || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppTextView.body2(AppStrings.loginSomethingWentWrong),
        ),
      );
  }
}
