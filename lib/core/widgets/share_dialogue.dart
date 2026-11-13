import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'app_gradient_action_button.dart';
import 'app_overlay_close_button.dart';
import 'app_dialog_style.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

/// Presents public-link state supplied by the owning feature. Link operations
/// stay in that feature's controller and are exposed through the callbacks.
class ShareDialogue extends StatelessWidget {
  const ShareDialogue({
    super.key,
    required this.contentLabel,
    this.link,
    this.onCreateLink,
    this.onRevokeLink,
    this.onCopyLink,
    this.isWorking = false,
    this.isLoading = false,
    this.onRetry,
    this.errorMessage,
    this.showRevokeAction = true,
    this.onClose,
  });

  final String contentLabel;
  final String? link;
  final VoidCallback? onCreateLink;
  final VoidCallback? onRevokeLink;
  final VoidCallback? onCopyLink;
  final bool isWorking;
  final bool isLoading;
  final VoidCallback? onRetry;
  final String? errorMessage;
  final bool showRevokeAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final publicLink = link?.trim() ?? '';
    final hasLink = publicLink.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.cardBg, AppColors.hex111317],
            ),
            borderRadius: BorderRadius.circular(16),
            border: AppDialogStyle.border,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppTextView.title1(
                        AppStrings.sharePublicLinkTitle,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onClose != null) ...[
                      const SizedBox(width: 12),
                      AppOverlayCloseButton(onTap: isWorking ? null : onClose),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                AppTextView.body(
                  isLoading
                      ? AppStrings.shareLoadingLink
                      : hasLink
                      ? AppStrings.sharePublicLinkDescription(contentLabel)
                      : AppStrings.shareCreateLinkDescription(contentLabel),
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
                if (hasLink && !isLoading) ...[
                  const SizedBox(height: 20),
                  SharePublicLinkRow(
                    link: publicLink,
                    onCopy: isWorking ? null : onCopyLink,
                  ),
                ],
                if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppTextView.body2(errorMessage!, color: AppColors.red1),
                ],
                if (isLoading ||
                    onRetry != null ||
                    !hasLink ||
                    showRevokeAction) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: isLoading
                        ? const SizedBox(
                            height: 44,
                            child: FastCircularProgressIndicator(),
                          )
                        : onRetry != null
                        ? TextButton(
                            onPressed: onRetry,
                            child: const AppTextView.body(
                              AppStrings.actionRetry,
                              color: AppColors.secondaryColor,
                            ),
                          )
                        : hasLink
                        ? _RevokeLinkAction(
                            isWorking: isWorking,
                            onTap: onRevokeLink,
                          )
                        : AppGradientActionButton(
                            label: AppStrings.shareCreateLinkAction,
                            icon: Icons.link_rounded,
                            onTap: onCreateLink,
                            isLoading: isWorking,
                            borderRadius: 12,
                            minHeight: 44,
                            textSize: 14,
                            iconSpacing: 8,
                            boxShadows: const <BoxShadow>[],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SharePublicLinkRow extends StatelessWidget {
  const SharePublicLinkRow({
    super.key,
    required this.link,
    required this.onCopy,
  });

  final String link;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.trainingLessonActionSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.fieldBorder.withValues(alpha: 0.15),
              ),
            ),
            child: AppTextView.body(
              link,
              color: AppColors.textPrimary,
              fontSize: 14,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: AppStrings.shareCopyLinkAction,
          onPressed: onCopy,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.trainingLessonActionSurface,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size.square(44),
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.copy_outlined, size: 22),
        ),
      ],
    );
  }
}

class _RevokeLinkAction extends StatelessWidget {
  const _RevokeLinkAction({required this.isWorking, required this.onTap});

  final bool isWorking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isWorking ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red1,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      icon: SizedBox.square(
        dimension: 22,
        child: Center(
          child: isWorking
              ? const FastCircularProgressIndicator(
                  width: 14,
                  height: 14,
                  color: AppColors.red1,
                )
              : const Icon(Icons.link_off_rounded, size: 22),
        ),
      ),
      label: const AppTextView.body(
        AppStrings.shareRevokeLinkAction,
        color: AppColors.red1,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
