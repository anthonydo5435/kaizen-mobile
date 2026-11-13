import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';

class CheckInMediaCommentsComposer extends StatelessWidget {
  const CheckInMediaCommentsComposer({
    super.key,
    required this.controller,
    required this.replyingLabel,
    required this.isReplying,
    required this.isSending,
    required this.onSend,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final bool isReplying;
  final String replyingLabel;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(color: AppColors.grey2.withValues(alpha: 0.45)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReplying) ...[
              Row(
                children: [
                  Expanded(
                    child: AppTextView.body3(
                      replyingLabel,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: AppTextView.body3(
                        AppStrings.actionCancel,
                        color: AppColors.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.mainBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.fieldBorder.withValues(alpha: 0.75),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      cursorColor: AppColors.textPrimary,
                      cursorHeight: 16,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: isReplying
                            ? AppStrings.actionReply
                            : AppStrings.auditMediaSendMessage,
                        hintStyle: const TextStyle(
                          color: AppColors.grey1,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.secondaryColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isSending ? null : onSend,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: isSending
                          ? Padding(
                              padding: EdgeInsets.all(10),
                              child: FastCircularProgressIndicator(),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
