import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/app_dot_divider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/managers/app_manager.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog_style.dart';
import '../../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../../core/widgets/fast_circular_progress.dart';
import '../../../../check_in/presentation/widgets/upgrade_plan_dialog.dart';
import '../../../domain/entities/compliance_document.dart';
import '../../../domain/repositories/compliance_document_media_repository.dart';
import '../../../domain/usecases/pick_compliance_document_file_usecase.dart';
import '../../../domain/usecases/upload_compliance_document_usecase.dart';
import '../../providers/compliance_document_expiry_controller.dart';
import '../../providers/compliance_document_media_controller.dart';
import '../../providers/compliance_document_upload_controller.dart';
import 'compliance_document_full_screen_image.dart';

class ComplianceDocumentUploadSheet extends StatefulWidget {
  const ComplianceDocumentUploadSheet({
    super.key,
    required this.document,
    required this.uploadComplianceDocumentUseCase,
    required this.pickComplianceDocumentFileUseCase,
  });

  final ComplianceDocument document;
  final UploadComplianceDocumentUseCase uploadComplianceDocumentUseCase;
  final PickComplianceDocumentFileUseCase pickComplianceDocumentFileUseCase;

  @override
  State<ComplianceDocumentUploadSheet> createState() =>
      _ComplianceDocumentUploadSheetState();
}

class _ComplianceDocumentUploadSheetState
    extends State<ComplianceDocumentUploadSheet> {
  static const double _uploadPanelHeight = 260;
  static const double _uploadPanelExpandedHeight = 340;

  late final ComplianceDocumentExpiryController _expiryController;
  late final ComplianceDocumentMediaController _mediaController;
  late final ComplianceDocumentUploadController _uploadController;
  final _expiryFieldKey = GlobalKey();

  bool get _isUploading => _uploadController.isUploading;
  double get _uploadProgress => _uploadController.uploadProgress;

  @override
  void initState() {
    super.initState();
    _expiryController = ComplianceDocumentExpiryController(
      initialExpiryDate: widget.document.latestDocumentExpiryDate,
    );
    _mediaController = ComplianceDocumentMediaController(
      widget.pickComplianceDocumentFileUseCase,
    );
    _uploadController = ComplianceDocumentUploadController(
      document: widget.document,
      uploadUseCase: widget.uploadComplianceDocumentUseCase,
      mediaController: _mediaController,
      expiryController: _expiryController,
    );
  }

  @override
  void dispose() {
    _uploadController.dispose();
    _expiryController.dispose();
    _mediaController.dispose();
    super.dispose();
  }

  File? get _selectedFile => _mediaController.selectedFile;
  String get _selectedFileName => _mediaController.selectedFileName ?? '';
  bool get _isPickingMedia => _mediaController.isPicking;

  Future<void> _pickDocument(ComplianceDocumentFileSource source) async {
    if (_isPickingMedia || _isUploading || !_canUploadDocument) {
      return;
    }
    await _mediaController.pickFile(source);
    if (!mounted) {
      return;
    }
    final errorMessage = _mediaController.errorMessage;
    if (errorMessage != null) {
      await CustomFunctions.showCustomAlert(
        context,
        AppStrings.complianceMediaSelectionFailedTitle,
        errorMessage,
      );
    }
  }

  Future<void> _showUploadOptions() async {
    if (_isPickingMedia || _isUploading || !_canUploadDocument) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (optionsContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                _UploadOptionTile(
                  icon: Icons.camera_alt_outlined,
                  title: AppStrings.complianceCamera,
                  subtitle: AppStrings.complianceCameraDescription,
                  onTap: () async {
                    Navigator.of(optionsContext).pop();
                    await _pickDocument(ComplianceDocumentFileSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                _UploadOptionTile(
                  icon: Icons.image_outlined,
                  title: AppStrings.complianceSelectImage,
                  subtitle: AppStrings.complianceSelectImageDescription,
                  onTap: () async {
                    Navigator.of(optionsContext).pop();
                    await _pickDocument(ComplianceDocumentFileSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _UploadOptionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: AppStrings.complianceSelectPdf,
                  subtitle: AppStrings.complianceSelectPdfDescription,
                  onTap: () async {
                    Navigator.of(optionsContext).pop();
                    await _pickDocument(ComplianceDocumentFileSource.pdf);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitUpload() async {
    if (_selectedFile == null || _isUploading || !_canUploadDocument) return;
    if (context.read<AppManager>().showBillingBanner) {
      await showDialog<void>(
        context: context,
        builder: (_) => const UpgradePlanDialog(),
        barrierDismissible: false,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final didUpload = await _uploadController.submit();
    if (!mounted) return;
    if (didUpload) {
      Navigator.of(context).pop(true);
    } else if (_uploadController.errorMessage != null) {
      await CustomFunctions.showCustomAlert(
        context,
        AppStrings.complianceDocumentUploadFailedTitle,
        _uploadController.errorMessage!,
      );
    }
  }

  Future<void> _openFullScreenImage() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null || !_isSelectedFileImage) {
      return;
    }

    final shouldReupload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplianceDocumentFullScreenImage(
          title: widget.document.title,
          image: selectedFile,
        ),
      ),
    );

    if (!mounted || shouldReupload != true) {
      return;
    }

    await _showUploadOptions();
  }

  Future<void> _pickExpiryDate() async {
    if (_isUploading || !_canUploadDocument) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final today = _expiryController.today;
    final selectedDate = _expiryController.selectedDate;
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate != null && !selectedDate.isBefore(today)
          ? selectedDate
          : today,
      firstDate: today,
      lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.secondaryColor,
            brightness: Brightness.dark,
          ).copyWith(surface: AppColors.surfaceDark),
          datePickerTheme: DatePickerThemeData(
            shape: AppDialogStyle.shape(radius: 28),
            dayShape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
              (states) => states.contains(WidgetState.selected)
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
            ),
            dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.secondaryColor
                  : null,
            ),
            dayForegroundColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.textPrimary
                  : null,
            ),
            todayBackgroundColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.secondaryColor
                  : null,
            ),
            todayForegroundColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.textPrimary
                  : null,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (mounted && date != null) {
      _expiryController.selectDate(date);
    }
  }

  bool get _hasSelectedFile => _selectedFile != null;
  bool get _canUploadDocument => !_isPendingApproval;
  bool get _hasRejectionReason => !_hasSelectedFile && _rejectionReason != null;
  bool get _showExpiryField => widget.document.hasExpiry;
  double get _resolvedUploadPanelHeight {
    final height = _hasRejectionReason
        ? _uploadPanelHeight
        : _uploadPanelExpandedHeight;
    return _hasSelectedFile
        ? (_isSelectedFileImage ? 200 : _uploadPanelHeight)
        : height + 48;
  }

  bool get _isSelectedFileImage => _mediaController.isSelectedFileImage;

  bool get _isPendingApproval {
    final latestStatus = widget.document.latestDocumentStatus;
    if (latestStatus == null || latestStatus.trim().isEmpty) {
      return false;
    }

    return CustomFunctions.isPendingApprovalStatus(latestStatus);
  }

  String? get _rejectionReason {
    if (!widget.document.hasLatestDocument) {
      return null;
    }

    final reason = widget.document.latestDocumentReason?.trim();
    if (reason == null || reason.isEmpty) {
      return null;
    }

    return reason;
  }

  Future<void> _showRejectionReasonDialog() async {
    final reason = _rejectionReason;
    if (reason == null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RejectionReasonDialog(
        reason: reason,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _uploadController,
      builder: (context, _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final uploadContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (_hasRejectionReason) ...[
          const AppTextView.title1(
            AppStrings.rejectionReasonTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          const SizedBox(height: 8),
          _RejectionReasonCard(
            reason: _rejectionReason!,
            onShowMore: _showRejectionReasonDialog,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: _resolvedUploadPanelHeight,
          child: _hasSelectedFile
              ? _isUploading
                    ? _UploadProgressPanel(
                        fileName: _selectedFileName,
                        fileSizeLabel: CustomFunctions.formatFileSize(
                          _selectedFile!.lengthSync(),
                        ),
                        progress: _uploadProgress,
                      )
                    : _SelectedDocumentPreview(
                        key: const ValueKey(
                          'compliance-selected-document-preview',
                        ),
                        file: _selectedFile!,
                        fileName: _selectedFileName,
                        isImage: _isSelectedFileImage,
                        onTap: _isSelectedFileImage
                            ? _openFullScreenImage
                            : null,
                      )
              : _UploadDropZone(
                  enabled: _canUploadDocument,
                  isPickingMedia: _isPickingMedia,
                  onTap: _showUploadOptions,
                ),
        ),
        if (_hasSelectedFile) ...[
          if (_canUploadDocument) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isUploading || _isPickingMedia
                    ? null
                    : _showUploadOptions,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryColor,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(48, 36),
                ),
                child: const Text(AppStrings.complianceChangeFile),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const AppDotDivider(),
          const SizedBox(height: 16),
          _DocumentMetadataFields(
            controller: _uploadController,
            enabled: !_isUploading && _canUploadDocument,
          ),
        ],
        if (_showExpiryField && keyboardOpen) ...[
          const SizedBox(height: 24),
          _ExpiryDateField(
            key: _expiryFieldKey,
            controller: _expiryController,
            enabled: !_isUploading && _canUploadDocument,
            onPickDate: _pickExpiryDate,
          ),
        ],
      ],
    );
    return SafeArea(
      top: false,
      bottom: false,
      minimum: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedSize(
          key: const ValueKey('compliance-document-upload-sheet'),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.9),
            child: SizedBox(
              height: _hasSelectedFile ? constraints.maxHeight * 0.9 : null,
              child: _UploadSheetSurface(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const _SheetHeader(),
                      const SizedBox(height: 16),
                      const AppDotDivider(),
                      Flexible(
                        fit: _hasSelectedFile ? FlexFit.tight : FlexFit.loose,
                        child: SingleChildScrollView(child: uploadContent),
                      ),
                      if (_showExpiryField && !keyboardOpen) ...[
                        const SizedBox(height: 24),
                        _ExpiryDateField(
                          key: _expiryFieldKey,
                          controller: _expiryController,
                          enabled: !_isUploading && _canUploadDocument,
                          onPickDate: _pickExpiryDate,
                        ),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        text: _hasSelectedFile
                            ? AppStrings.submit
                            : AppStrings.cancelUpload,
                        onPressed:
                            _hasSelectedFile &&
                                !_isUploading &&
                                !_isPickingMedia &&
                                _canUploadDocument
                            ? _submitUpload
                            : null,
                        isLoading: _isUploading,
                        backgroundColor: _hasSelectedFile
                            ? AppColors.secondaryColor
                            : AppColors.grey1,
                        textColor: _hasSelectedFile
                            ? AppColors.textPrimary
                            : AppColors.grey2,
                        minimumHeight: 40,
                        textSize: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadSheetSurface extends StatelessWidget {
  const _UploadSheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppKeyboardBottomSheetSurface(
      color: AppColors.mainBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }
}

class _DocumentMetadataFields extends StatelessWidget {
  const _DocumentMetadataFields({
    required this.controller,
    required this.enabled,
  });

  final ComplianceDocumentUploadController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        _DocumentMetadataField(
          fieldKey: const ValueKey('compliance-document-name'),
          controller: controller.nameController,
          label: AppStrings.complianceDocumentName,
          maxLength: ComplianceDocumentUploadController.nameMaxLength,
          errorText: controller.nameError,
          enabled: enabled,
        ),
        const SizedBox(height: 16),
        _DocumentMetadataField(
          fieldKey: const ValueKey('compliance-document-description'),
          controller: controller.descriptionController,
          label: AppStrings.complianceDocumentDescription,
          maxLength: ComplianceDocumentUploadController.descriptionMaxLength,
          errorText: controller.descriptionError,
          hintText: AppStrings.complianceDocumentDescriptionHint,
          enabled: enabled,
          minLines: keyboardOpen ? 2 : 5,
          maxLines: keyboardOpen ? 3 : 5,
        ),
      ],
    );
  }
}

class _DocumentMetadataField extends StatelessWidget {
  const _DocumentMetadataField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.maxLength,
    this.hintText,
    this.errorText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int maxLength;
  final String? hintText;
  final String? errorText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: AppColors.fieldBorder.withValues(alpha: 0.28),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextView.body2(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 10),
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          cursorHeight: 16,
          keyboardType: maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.fieldFill,
            isDense: true,
            counterStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            errorText: errorText,
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(
                color: AppColors.secondaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AppOverlayCloseButton(
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const AppTextView.title1(
          AppStrings.uploadDocumentTitle,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 20,
        ),
      ],
    );
  }
}

class _RejectionReasonCard extends StatelessWidget {
  const _RejectionReasonCard({required this.reason, required this.onShowMore});

  final String reason;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    // Scale once so the inline action and measured preview use the same sizes.
    final reasonStyle = DefaultTextStyle.of(context).style.copyWith(
      color: AppColors.textPrimary,
      fontSize: textScaler.scale(14),
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
    final linkStyle = reasonStyle.copyWith(
      color: AppColors.secondaryColor,
      fontSize: textScaler.scale(12),
      fontWeight: FontWeight.w500,
    );
    return Container(
      height: (textScaler.scale(14) * 1.45 * 2 + 24)
          .clamp(72, double.infinity)
          .toDouble(),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => _buildPreview(
          context,
          width: constraints.maxWidth,
          reasonStyle: reasonStyle,
          linkStyle: linkStyle,
        ),
      ),
    );
  }

  // Reserve the inline action before truncating, so it stays on the last line.
  Widget _buildPreview(
    BuildContext context, {
    required double width,
    required TextStyle reasonStyle,
    required TextStyle linkStyle,
  }) {
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final previewPainter = TextPainter(
      text: TextSpan(text: reason, style: reasonStyle),
      textDirection: direction,
      locale: locale,
      maxLines: 2,
    )..layout(maxWidth: width);
    if (!previewPainter.didExceedMaxLines) {
      previewPainter.dispose();
      return Text(
        reason,
        style: reasonStyle,
        maxLines: 2,
        textScaler: TextScaler.noScaling,
      );
    }
    const suffix = AppStrings.complianceRejectionPreviewEllipsis;
    final suffixPainter = TextPainter(
      text: TextSpan(
        style: reasonStyle,
        text: suffix,
        children: [
          TextSpan(text: AppStrings.complianceShowMore, style: linkStyle),
        ],
      ),
      textDirection: direction,
      locale: locale,
    )..layout();
    final inlineAction = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(suffix, style: reasonStyle, textScaler: TextScaler.noScaling),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: onShowMore,
            child: Text(
              AppStrings.complianceShowMore,
              style: linkStyle,
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ],
    );

    TextSpan span(String text) => TextSpan(
      style: reasonStyle,
      text: text,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: inlineAction,
        ),
      ],
    );

    bool fits(String text) {
      previewPainter.text = span(text);
      previewPainter.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: suffixPainter.size,
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset: suffixPainter.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          ),
        ),
      ]);
      previewPainter.layout(maxWidth: width);
      return !previewPainter.didExceedMaxLines;
    }

    final characters = reason.characters.toList();
    var low = 0;
    var high = characters.length;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (fits(characters.take(middle).join().trimRight())) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    final preview = characters.take(low).join().trimRight();
    suffixPainter.dispose();
    previewPainter.dispose();
    return Text.rich(
      span(preview),
      maxLines: 2,
      textScaler: TextScaler.noScaling,
    );
  }
}

class _RejectionReasonDialog extends StatelessWidget {
  const _RejectionReasonDialog({required this.reason, required this.onDismiss});

  final String reason;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 16),
      title: Row(
        children: [
          const Expanded(
            child: AppTextView.body1(
              AppStrings.rejectionReasonTitle,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          AppOverlayCloseButton(onTap: onDismiss),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(
          child: AppTextView.body(
            reason,
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        AppButton(
          text: AppStrings.complianceRejectionReasonOk,
          onPressed: onDismiss,
          minimumHeight: (MediaQuery.textScalerOf(context).scale(16) * 1.5)
              .clamp(40, double.infinity)
              .toDouble(),
        ),
      ],
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({
    required this.enabled,
    required this.isPickingMedia,
    required this.onTap,
  });

  final bool enabled;
  final bool isPickingMedia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: enabled && !isPickingMedia ? onTap : null,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.fieldBorder.withValues(
              alpha: enabled ? 0.4 : 0.18,
            ),
            radius: 12,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: enabled
                            ? AppColors.secondaryColor
                            : AppColors.grey2,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: isPickingMedia
                          ? FastCircularProgressIndicator(width: 24, height: 24)
                          : SvgPicture.asset(
                              '${AppStrings.imagePath}upload.svg',
                              width: 24,
                              height: 24,
                            ),
                    ),
                    const SizedBox(height: 24),
                    AppTextView.title1(
                      AppStrings.clickToUploadDocument,
                      color: enabled ? AppColors.textPrimary : AppColors.grey1,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                    const SizedBox(height: 6),
                    const AppTextView.body2(
                      AppStrings.uploadFileFormat,
                      color: AppColors.grey1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    const AppTextView.body2(
                      AppStrings.uploadMaxFileSize,
                      color: AppColors.grey1,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadOptionTile extends StatelessWidget {
  const _UploadOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.fieldBorder.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body2(
                      subtitle,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDocumentPreview extends StatelessWidget {
  const _SelectedDocumentPreview({
    super.key,
    required this.file,
    required this.fileName,
    required this.isImage,
    this.onTap,
  });

  final File file;
  final String fileName;
  final bool isImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isImage) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: double.infinity, fit: BoxFit.contain),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            AppTextView.body(
              fileName,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            AppTextView.body2(
              CustomFunctions.formatFileSize(file.lengthSync()),
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressPanel extends StatelessWidget {
  const _UploadProgressPanel({
    required this.fileName,
    required this.fileSizeLabel,
    required this.progress,
  });

  final String fileName;
  final String fileSizeLabel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0, 1).toDouble();
    final progressLabel = AppStrings.complianceDocumentUploadPercentage(
      (safeProgress * 100).round(),
    );
    final displayFileName = _shortFileName(fileName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextView.body(
            displayFileName,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTextView.body2(
                fileSizeLabel,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(width: 5),
              AppTextView.body2(
                progressLabel,
                color: AppColors.progressColor,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 6,
              backgroundColor: AppColors.fieldBorder.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation(AppColors.progressColor),
            ),
          ),
        ],
      ),
    );
  }

  String _shortFileName(String value) {
    const maxBaseLength = 14;
    final name = value.trim();
    if (name.length <= maxBaseLength + 8) {
      return name;
    }

    final extensionIndex = name.lastIndexOf('.');
    if (extensionIndex <= 0 || extensionIndex == name.length - 1) {
      return '${name.substring(0, maxBaseLength)}...';
    }

    final extension = name.substring(extensionIndex);
    final baseName = name.substring(0, extensionIndex);
    if (baseName.length <= maxBaseLength) {
      return name;
    }

    return '${baseName.substring(0, maxBaseLength)}...$extension';
  }
}

class _ExpiryDateField extends StatelessWidget {
  const _ExpiryDateField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPickDate,
  });

  final ComplianceDocumentExpiryController controller;
  final bool enabled;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.focusNode]),
      builder: (context, _) => TextField(
        controller: controller.textController,
        focusNode: controller.focusNode,
        enabled: enabled,
        keyboardType: TextInputType.datetime,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [
          TextInputFormatter.withFunction(controller.formatEditUpdate),
        ],
        onTap: controller.selectSegmentAtCursor,
        onSubmitted: (_) => controller.validate(),
        cursorHeight: 16,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: AppStrings.enterExpiryDate,
          labelText:
              controller.focusNode.hasFocus ||
                  controller.textController.text.isNotEmpty
              ? AppStrings.enterExpirationDate
              : AppStrings.expirationDateWithFormat,
          floatingLabelStyle: const TextStyle(color: AppColors.secondaryColor),
          errorText: controller.errorText,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: AppStrings.selectExpiryDate,
            onPressed: enabled ? onPickDate : null,
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.secondaryColor,
            ),
          ),
          hintStyle: const TextStyle(color: AppColors.grey1, fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.secondaryColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 5.0;
    const dashSpace = 10.0;
    final path = Path()..addRRect(rect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
