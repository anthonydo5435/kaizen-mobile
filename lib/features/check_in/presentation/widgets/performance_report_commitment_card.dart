import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';

class PerformanceReportCommitmentCard extends StatelessWidget {
  const PerformanceReportCommitmentCard({
    super.key,
    required this.controller,
    required this.isReadOnly,
    required this.certifiedAt,
    required this.onChanged,
    required this.employeeSignatureUrl,
    required this.employeeName,
    required this.employeeSignatureBytes,
    required this.facilitatorSignatureUrl,
    required this.facilitatorName,
    required this.facilitatorSignatureBytes,
    required this.onAddEmployeeSignature,
    required this.onAddFacilitatorSignature,
    required this.onClearEmployeeSignature,
    required this.onClearFacilitatorSignature,
  });

  final TextEditingController controller;
  final bool isReadOnly;
  final String? certifiedAt;
  final ValueChanged<String> onChanged;
  final String? employeeSignatureUrl;
  final String? employeeName;
  final Uint8List? employeeSignatureBytes;
  final String? facilitatorSignatureUrl;
  final String? facilitatorName;
  final Uint8List? facilitatorSignatureBytes;
  final VoidCallback onAddEmployeeSignature;
  final VoidCallback onAddFacilitatorSignature;
  final VoidCallback onClearEmployeeSignature;
  final VoidCallback onClearFacilitatorSignature;

  @override
  Widget build(BuildContext context) {
    final currentLength = controller.text.length;
    final hasCertifiedAt =
        certifiedAt != null && certifiedAt!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: AppColors.secondaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: AppTextView.body1(
                  AppStrings.performanceReportCommitmentTitle,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: _innerCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.comment_bank_outlined,
                      color: AppColors.secondaryColor,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    AppTextView.body1(
                      AppStrings.comments,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const AppTextView.body3(
                  AppStrings.performanceReportCommitmentHint,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 8,
                  onChanged: isReadOnly ? null : onChanged,
                  readOnly: isReadOnly,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorHeight: 14,
                  decoration: InputDecoration(
                    hintText: AppStrings.performanceReportEnterComments,
                    hintStyle: const TextStyle(
                      color: AppColors.grey1,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.fieldBorder.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.secondaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppTextView.body4(
                    AppStrings.performanceReportCommitmentCount(currentLength),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: _innerCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gesture_outlined,
                      color: AppColors.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    AppTextView.body1(
                      AppStrings.performanceReportSignature,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const AppTextView.body3(
                  AppStrings.performanceReportSignatureHint,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                _SignatureSection(
                  title: AppStrings.performanceReportEmployeeSignature,
                  signatureUrl: employeeSignatureUrl,
                  signerName: employeeName,
                  signatureBytes: employeeSignatureBytes,
                  isReadOnly: isReadOnly,
                  onAddSignature: onAddEmployeeSignature,
                  onClearSignature: onClearEmployeeSignature,
                ),
                _SignatureSection(
                  title: AppStrings.performanceReportFacilitatorSignature,
                  signatureUrl: facilitatorSignatureUrl,
                  signerName: facilitatorName,
                  signatureBytes: facilitatorSignatureBytes,
                  isReadOnly: isReadOnly,
                  onAddSignature: onAddFacilitatorSignature,
                  onClearSignature: onClearFacilitatorSignature,
                ),
                if (isReadOnly && hasCertifiedAt) ...[
                  const SizedBox(height: 14),
                  AppTextView.body3(
                    AppStrings.performanceReportCertifiedAt(
                      _formatCertifiedAt(certifiedAt),
                    ),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCertifiedAt(String? value) {
    final milliseconds = int.tryParse(value?.trim() ?? '');
    if (milliseconds == null) {
      return '--';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year | $hour:$minute $meridiem';
  }
}

class _SignatureSection extends StatelessWidget {
  const _SignatureSection({
    required this.title,
    required this.signatureUrl,
    required this.signerName,
    required this.signatureBytes,
    required this.isReadOnly,
    required this.onAddSignature,
    required this.onClearSignature,
  });

  final String title;
  final String? signatureUrl;
  final String? signerName;
  final Uint8List? signatureBytes;
  final bool isReadOnly;
  final VoidCallback onAddSignature;
  final VoidCallback onClearSignature;

  @override
  Widget build(BuildContext context) {
    final resolvedSignatureUrl = signatureUrl?.trim();
    final hasSignatureUrl =
        resolvedSignatureUrl != null && resolvedSignatureUrl.isNotEmpty;
    final hasSignature = signatureBytes != null || hasSignatureUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 19),
        AppTextView.body1(
          title,
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.fieldBorder.withValues(alpha: 0.15),
              width: 1.8,
            ),
          ),
          child: Column(
            children: [
              if (!hasSignature) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gesture_outlined,
                    color: AppColors.secondaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                const AppTextView.body2(
                  AppStrings.performanceReportNoSignature,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                const AppTextView.body3(
                  AppStrings.performanceReportAddSignatureHint,
                  color: AppColors.textSecondary,
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: signatureBytes != null
                      ? Image.memory(signatureBytes!, fit: BoxFit.contain)
                      : Image.network(
                          resolvedSignatureUrl!,
                          fit: BoxFit.contain,
                        ),
                ),
              ],
              if (signerName != null && signerName!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                AppTextView.body3(
                  signerName!.trim(),
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ],
              if (!isReadOnly) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (signatureBytes != null) ...[
                      OutlinedButton(
                        onPressed: onClearSignature,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.fieldBorder.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(AppStrings.auditMarkupClear),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: onAddSignature,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryColor,
                        side: const BorderSide(color: AppColors.secondaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        signatureBytes == null
                            ? Icons.edit_outlined
                            : Icons.refresh_rounded,
                        size: 16,
                      ),
                      label: Text(
                        signatureBytes == null
                            ? AppStrings.performanceReportAddSignature
                            : AppStrings.performanceReportRetakeSignature,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

BoxDecoration _innerCardDecoration() {
  return BoxDecoration(
    // color: AppColors.surfaceDark2,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.18)),
  );
}
