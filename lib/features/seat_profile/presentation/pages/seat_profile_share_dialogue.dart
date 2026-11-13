import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/share_dialogue.dart';
import '../providers/seat_profile_share_controller.dart';

Future<void> showSeatProfileShareDialogue(
  BuildContext context,
  SeatProfileShareController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => ListenableBuilder(
      listenable: Listenable.merge([controller, AppManager.instance]),
      builder: (context, _) => ShareDialogue(
        contentLabel: AppStrings.shareSeatProfileContent,
        link: controller.link,
        isLoading: controller.isLoading,
        isWorking: controller.isWorking,
        onClose: () => Navigator.of(dialogContext).pop(),
        errorMessage: controller.errorMessage,
        onRetry:
            !controller.hasLoaded &&
                !controller.isLoading &&
                controller.canManage
            ? controller.loadLink
            : null,
        onCreateLink: controller.canCreate ? controller.createLink : null,
        onRevokeLink: controller.canRevoke ? controller.revokeLink : null,
        onCopyLink: controller.canManage
            ? () async {
                final copied = await controller.copyLink();
                if (!copied || !dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text(AppStrings.shareLinkCopied)),
                );
              }
            : null,
      ),
    ),
  );
}
