import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_listing_tabs.dart';
import '../../domain/entities/audit_member_status.dart';

class CheckInStatusSwitcher extends StatelessWidget {
  const CheckInStatusSwitcher({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
    this.activeTitle = AppStrings.auditActive,
    this.deactivatedTitle = AppStrings.auditDeactivated,
    this.showDeactivated = true,
    this.onGeneralSeatsSelected,
    this.isGeneralSeatsSelected = false,
  });

  final AuditMemberStatus selectedStatus;
  final ValueChanged<AuditMemberStatus> onStatusSelected;
  final String activeTitle;
  final String deactivatedTitle;
  final bool showDeactivated;
  final VoidCallback? onGeneralSeatsSelected;
  final bool isGeneralSeatsSelected;

  @override
  Widget build(BuildContext context) {
    return AppListingTabs(
      tabs: [
        (
          title: activeTitle,
          isSelected:
              !isGeneralSeatsSelected &&
              selectedStatus == AuditMemberStatus.active,
          onTap: () => onStatusSelected(AuditMemberStatus.active),
        ),
        if (onGeneralSeatsSelected case final onTap?)
          (
            title: AppStrings.auditGeneralSeatsTab,
            isSelected: isGeneralSeatsSelected,
            onTap: onTap,
          ),
        if (showDeactivated)
          (
            title: deactivatedTitle,
            isSelected:
                !isGeneralSeatsSelected &&
                selectedStatus == AuditMemberStatus.deactivated,
            onTap: () => onStatusSelected(AuditMemberStatus.deactivated),
          ),
      ],
    );
  }
}
