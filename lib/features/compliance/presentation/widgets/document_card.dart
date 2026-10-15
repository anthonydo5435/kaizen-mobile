import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/compliance_document.dart';
import '../../domain/usecases/upload_compliance_document_usecase.dart';
import '../../domain/usecases/pick_compliance_document_file_usecase.dart';
import '../pages/document/compliance_document_upload_sheet.dart';
import '../pages/document/full_screen_doc.dart';
import '../providers/compliance_document_controller.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document});

  final ComplianceDocument document;

  @override
  Widget build(BuildContext context) {
    final latestDocumentStatus = CustomFunctions.displayStatus(
      document.latestDocumentStatus,
    );
    final expiryText = document.hasExpiry
        ? CustomFunctions.formatDate(document.latestDocumentExpiryDate)
        : 'No Expiry';
    final statusStyle = _resolveStatusStyle(document);
    final normalizedStatus = _normalizedDocumentStatus(document);
    final isUploadDisabled =
        CustomFunctions.isNoLongerNeededStatus(normalizedStatus) ||
        CustomFunctions.isPendingApprovalStatus(normalizedStatus);
    final uploadButtonText = normalizedStatus == 'compliant'
        ? AppStrings.reUpload
        : AppStrings.uploadDoc;
    final uploadButtonColor = isUploadDisabled
        ? AppColors.grey1
        : AppColors.secondaryColor;
    final uploadContentColor = isUploadDisabled
        ? AppColors.grey2
        : AppColors.textPrimary;
    final viewableDocumentUrl = _viewableDocumentUrl(document);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppTextView.body3(
                'Seat Profile',
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
              AppTextView.body2(
                document.category,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextView.body2(
                  document.title,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (viewableDocumentUrl != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openDocumentPreview(
                    context,
                    title: document.title,
                    imageUrl: viewableDocumentUrl,
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: AppColors.green1,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.green1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusStyle.borderColor, width: 1),
                ),
                child: AppTextView.body3(
                  statusStyle.label,
                  color: statusStyle.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              AppTextView.body2(
                document.hasExpiry ? 'Expires on ' : '',
                color: AppColors.grey1,
                fontSize: 11,
              ),
              AppTextView.body2(
                expiryText,
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ],
          ),
          if (latestDocumentStatus != null) ...[
            const SizedBox(height: 8),
            AppTextView.body3(
              'Latest Document: $latestDocumentStatus',
              color: AppColors.grey1,
              fontSize: 11,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppColors.fieldBorder.withValues(alpha: 0.20),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: isUploadDisabled
                ? null
                : () => _showUploadSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: uploadButtonColor,
              disabledBackgroundColor: uploadButtonColor,
              minimumSize: Size.fromHeight(30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  '${AppStrings.imagePath}upload.svg',
                  width: 24,
                  height: 15,
                  colorFilter: ColorFilter.mode(
                    uploadContentColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 9),
                AppTextView.body(
                  uploadButtonText,
                  color: uploadContentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _normalizedDocumentStatus(ComplianceDocument document) {
    return CustomFunctions.normalizedStatus(
      document.rawStatus ?? document.status,
    );
  }

  String? _viewableDocumentUrl(ComplianceDocument document) {
    final primaryUrl = document.latestDocumentUrl?.trim();
    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      return primaryUrl;
    }

    final thumbnailUrl = document.latestDocumentThumbnailUrl?.trim();
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    return null;
  }

  _DocumentStatusStyle _resolveStatusStyle(ComplianceDocument document) {
    final rawStatus = _normalizedDocumentStatus(document);
    if (rawStatus == 'compliant') {
      return const _DocumentStatusStyle(
        label: 'Compliant',
        backgroundColor: AppColors.hexe3f8f4,
        borderColor: AppColors.green1,
        textColor: AppColors.green1,
      );
    }

    if (rawStatus == 'pending submission') {
      return const _DocumentStatusStyle(
        label: 'Pending Submission',
        backgroundColor: AppColors.hexe8f2ff,
        borderColor: AppColors.hex2f80ed,
        textColor: AppColors.hex2f80ed,
      );
    }

    if (CustomFunctions.isNoLongerNeededStatus(rawStatus)) {
      return const _DocumentStatusStyle(
        label: 'No Longer Required',
        backgroundColor: AppColors.hexe4e7ec,
        borderColor: AppColors.grey1,
        textColor: AppColors.grey2,
      );
    }

    if (rawStatus == 'rejected') {
      return const _DocumentStatusStyle(
        label: 'Rejected',
        backgroundColor: AppColors.hexffe1e1,
        borderColor: AppColors.red,
        textColor: AppColors.red,
      );
    }

    return _DocumentStatusStyle(
      label: document.status,
      backgroundColor: AppColors.textPrimary,
      borderColor: AppColors.secondaryColor,
      textColor: AppColors.secondaryColor,
    );
  }

  Future<void> _showUploadSheet(BuildContext context) async {
    final uploadUseCase = context.read<UploadComplianceDocumentUseCase>();
    final pickFileUseCase = context.read<PickComplianceDocumentFileUseCase>();
    final didUpload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplianceDocumentUploadSheet(
        document: document,
        uploadComplianceDocumentUseCase: uploadUseCase,
        pickComplianceDocumentFileUseCase: pickFileUseCase,
      ),
    );
    if (!context.mounted || didUpload != true) {
      return;
    }

    await context.read<ComplianceDocumentController>().initialize(
      forceRefresh: true,
    );
  }

  Future<void> _openDocumentPreview(
    BuildContext context, {
    required String title,
    required String imageUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViewFullScreenDoc(title: title, imageUrl: imageUrl),
      ),
    );
  }
}

class _DocumentStatusStyle {
  const _DocumentStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
}
