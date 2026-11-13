import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_bar_gradient_action.dart';
import '../../../../core/widgets/app_share_button.dart';
import '../controllers/training_module_controller.dart';
import '../controllers/training_share_controller.dart';
import 'training_share_dialogue.dart';

class TrainingShareAction extends StatelessWidget {
  const TrainingShareAction({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final shareController = context.watch<TrainingShareController>();
    return ListenableBuilder(
      listenable: AppManager.instance,
      builder: (context, _) {
        final canShare =
            shareController.canManage &&
            !controller.isLoading &&
            (shareController.link != null || controller.modules.isNotEmpty);
        if (!canShare) return const SizedBox.shrink();
        void onShare() => showTrainingShareDialogue(
          context,
          controller: shareController,
          lessons: controller.modules,
        );
        return iconOnly
            ? AppBarGradientAction(
                label: AppStrings.shareAction,
                icon: Icons.share_outlined,
                endPadding: 0,
                compact: true,
                onTap: onShare,
              )
            : AppShareButton(onTap: onShare);
      },
    );
  }
}
