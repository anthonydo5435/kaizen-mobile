import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/performance_report.dart';
import '../providers/performance_report_controller.dart';
import 'performance_report_commitment_card.dart';

class PerformanceReportCommitmentSection extends StatelessWidget {
  const PerformanceReportCommitmentSection({
    super.key,
    required this.controller,
    required this.report,
    required this.onEmployeeSignature,
    required this.onFacilitatorSignature,
    required this.onCertify,
  });

  final PerformanceReportController controller;
  final PerformanceReport report;
  final VoidCallback onEmployeeSignature;
  final VoidCallback onFacilitatorSignature;
  final VoidCallback onCertify;

  @override
  Widget build(BuildContext context) {
    final auditController = controller.checkInController;
    return Column(
      children: [
        PerformanceReportCommitmentCard(
          controller: controller.commentsController,
          isReadOnly: controller.isCommitmentReadOnly,
          certifiedAt: report.certifiedAt,
          employeeSignatureUrl: report.selectedProfileSignatureUrl,
          employeeName: report.employeeSignatureName ?? report.profile.name,
          employeeSignatureBytes: controller.state.employeeSignatureBytes,
          facilitatorSignatureUrl: report.facilitatorSignatureUrl,
          facilitatorName: report.facilitatorName,
          facilitatorSignatureBytes: controller.state.facilitatorSignatureBytes,
          onChanged: controller.updateCommitment,
          onAddEmployeeSignature: onEmployeeSignature,
          onAddFacilitatorSignature: onFacilitatorSignature,
          onClearEmployeeSignature: auditController.clearEmployeeSignature,
          onClearFacilitatorSignature:
              auditController.clearFacilitatorSignature,
        ),
        if (!report.isCertified) ...[
          const SizedBox(height: 16),
          _CertifyButton(
            isLoading: controller.isCertifying,
            onPressed: onCertify,
          ),
        ],
      ],
    );
  }
}

class _CertifyButton extends StatelessWidget {
  const _CertifyButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondaryColor,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isLoading ? 0 : 1,
              child: const Text(AppStrings.certify),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: FastCircularProgressIndicator(width: 20, height: 20),
              ),
          ],
        ),
      ),
    );
  }
}
