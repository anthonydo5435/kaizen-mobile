import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../compliance/presentation/pages/document/full_screen_doc.dart';
import '../../domain/entities/performance_report.dart';

Future<Object?> showPerformanceReportTimeRangeDialog(
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
  required DateTime minDate,
  required DateTime maxDate,
  required String Function(DateTime value) formatDate,
}) {
  return showDialog<Object>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _TimeRangeDialogContent(
      startDate: startDate,
      endDate: endDate,
      minDate: minDate,
      maxDate: maxDate,
      formatDate: formatDate,
    ),
  );
}

Future<void> showPerformanceReportCertifiedReportsSheet(
  BuildContext context, {
  required String? value,
  required List<CertifiedReportOption> options,
  required bool Function(String uuid) isDownloading,
  required ValueChanged<String?> onChanged,
  required Future<String> Function(CertifiedReportOption option) onDownload,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => _CertifiedReportsSheetContent(
      value: value,
      options: options,
      isDownloading: isDownloading,
      onChanged: onChanged,
      onDownload: onDownload,
    ),
  );
}

Future<void> showPerformanceReportSignatureDialog(
  BuildContext context, {
  required String title,
  required String? existingSignatureUrl,
  required Future<String?> Function(Uint8List bytes) onSaved,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Signature Dialog',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _SignatureDialogContent(
          title: title,
          existingSignatureUrl: existingSignatureUrl,
          onSaved: onSaved,
        ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scaleAnimation = Tween<double>(
        begin: 0.94,
        end: 1,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(scale: scaleAnimation, child: child),
      );
    },
  );
}

Future<void> showPerformanceReportCoreValueDialog(
  BuildContext context, {
  required PerformanceReportCoreValue coreValue,
  required IconData icon,
  required Color accentColor,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _CoreValueDialogContent(
      coreValue: coreValue,
      icon: icon,
      accentColor: accentColor,
    ),
  );
}

class _TimeRangeDialogContent extends StatefulWidget {
  const _TimeRangeDialogContent({
    required this.startDate,
    required this.endDate,
    required this.minDate,
    required this.maxDate,
    required this.formatDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime minDate;
  final DateTime maxDate;
  final String Function(DateTime value) formatDate;

  @override
  State<_TimeRangeDialogContent> createState() =>
      _TimeRangeDialogContentState();
}

class _CoreValueDialogContent extends StatelessWidget {
  const _CoreValueDialogContent({
    required this.coreValue,
    required this.icon,
    required this.accentColor,
  });

  final PerformanceReportCoreValue coreValue;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final description = coreValue.description?.trim();
    final detailCards = <Widget>[
      if (description?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CoreValueDetailCard(
            value: description!,
            accentColor: accentColor,
          ),
        ),
      ...coreValue.details.map(
        (detail) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CoreValueDetailCard(
            label: detail.label,
            value: detail.value,
            accentColor: accentColor,
          ),
        ),
      ),
    ];

    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: mediaQuery.size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                    child: Icon(icon, color: AppColors.textPrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextView.body1(
                      coreValue.title,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppOverlayCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.fieldBorder.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: detailCards.isEmpty
                      ? _CoreValueDetailCard(
                          value: AppStrings
                              .performanceReportCoreValueDetailsFallback,
                          accentColor: accentColor,
                        )
                      : Column(children: detailCards),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoreValueDetailCard extends StatelessWidget {
  const _CoreValueDetailCard({
    this.label,
    required this.value,
    required this.accentColor,
  });

  final String? label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label?.trim().isNotEmpty == true) ...[
            AppTextView.body4(
              label!.trim(),
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
          ],
          AppTextView.body3(
            value,
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.45,
          ),
        ],
      ),
    );
  }
}

class _TimeRangeDialogContentState extends State<_TimeRangeDialogContent> {
  late DateTime? _selectedStart;
  late DateTime? _selectedEnd;
  late DateTime _visibleMonth;
  late _RangeSelectionMode _selectionMode;
  _TimeRangeDialogStep _dialogStep = _TimeRangeDialogStep.customRange;

  @override
  void initState() {
    super.initState();
    final minDate = _dateOnly(widget.minDate);
    final maxDate = _dateOnly(widget.maxDate);
    _selectedStart = _clampDate(widget.startDate, minDate, maxDate);
    _selectedEnd = _clampDate(widget.endDate, minDate, maxDate);
    if (_selectedStart != null &&
        _selectedEnd != null &&
        _selectedEnd!.isBefore(_selectedStart!)) {
      _selectedEnd = _selectedStart;
    }
    _visibleMonth = DateTime(
      (_selectedStart ?? _selectedEnd ?? maxDate).year,
      (_selectedStart ?? _selectedEnd ?? maxDate).month,
    );
    _selectionMode = _selectedStart == null
        ? _RangeSelectionMode.start
        : _RangeSelectionMode.end;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: _dialogStep == _TimeRangeDialogStep.options
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextView.body1(
                    'Select Date range',
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 14),
                  _DialogOptionTile(
                    title: 'This Quarter',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pop(PerformanceReportTimeRangeDialogResult.thisQuarter);
                    },
                  ),
                  const SizedBox(height: 10),
                  _DialogOptionTile(
                    title: 'Custom Date Range',
                    onTap: () {
                      setState(() {
                        _dialogStep = _TimeRangeDialogStep.customRange;
                      });
                    },
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _dialogStep = _TimeRangeDialogStep.options;
                          });
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: AppTextView.body1(
                          AppStrings.performanceReportChooseDateRange,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DateSelectionChip(
                          label: 'Start',
                          value: _selectedStart == null
                              ? 'Select'
                              : widget.formatDate(_selectedStart!),
                          isSelected:
                              _selectionMode == _RangeSelectionMode.start,
                          onTap: () {
                            setState(() {
                              _selectionMode = _RangeSelectionMode.start;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateSelectionChip(
                          label: 'End',
                          value: _selectedEnd == null
                              ? 'Select'
                              : widget.formatDate(_selectedEnd!),
                          isSelected: _selectionMode == _RangeSelectionMode.end,
                          onTap: () {
                            setState(() {
                              _selectionMode = _RangeSelectionMode.end;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CustomRangeCalendar(
                    visibleMonth: _visibleMonth,
                    minDate: widget.minDate,
                    maxDate: widget.maxDate,
                    startDate: _selectedStart,
                    endDate: _selectedEnd,
                    onMonthChanged: (value) {
                      setState(() {
                        _visibleMonth = value;
                      });
                    },
                    onDateSelected: (value) {
                      setState(() {
                        if (_selectionMode == _RangeSelectionMode.start) {
                          _selectedStart = value;
                          if (_selectedEnd != null &&
                              _selectedEnd!.isBefore(value)) {
                            _selectedEnd = value;
                          }
                          _selectionMode = _RangeSelectionMode.end;
                        } else {
                          if (_selectedStart != null &&
                              value.isBefore(_selectedStart!)) {
                            _selectedStart = value;
                            _selectedEnd = value;
                          } else {
                            _selectedEnd = value;
                          }
                        }
                        _visibleMonth = DateTime(value.year, value.month);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _selectedStart == null || _selectedEnd == null
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                DateTimeRange(
                                  start: _selectedStart!,
                                  end: _selectedEnd!,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

DateTime? _clampDate(DateTime? value, DateTime minDate, DateTime maxDate) {
  if (value == null) {
    return null;
  }

  final normalizedValue = _dateOnly(value);
  if (normalizedValue.isBefore(minDate)) {
    return minDate;
  }
  if (normalizedValue.isAfter(maxDate)) {
    return maxDate;
  }
  return normalizedValue;
}

class _CertifiedReportsSheetContent extends StatefulWidget {
  const _CertifiedReportsSheetContent({
    required this.value,
    required this.options,
    required this.isDownloading,
    required this.onChanged,
    required this.onDownload,
  });

  final String? value;
  final List<CertifiedReportOption> options;
  final bool Function(String uuid) isDownloading;
  final ValueChanged<String?> onChanged;
  final Future<String> Function(CertifiedReportOption option) onDownload;

  @override
  State<_CertifiedReportsSheetContent> createState() =>
      _CertifiedReportsSheetContentState();
}

class _CertifiedReportsSheetContentState
    extends State<_CertifiedReportsSheetContent> {
  String? _downloadingUuid;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final estimatedContentHeight = 132.0 + ((widget.options.length + 1) * 58.0);
    final sheetHeight = math.min(
      mediaQuery.size.height * 0.76,
      math.max(260.0, estimatedContentHeight),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          20 + mediaQuery.viewInsets.bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: AppTextView.body1(
                  'Certified Reports',
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: widget.options.length > 4,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _CertifiedReportSheetTile(
                        title: 'Select Certified Report',
                        isSelected: widget.value == null,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onChanged(null);
                        },
                      ),
                      for (final option in widget.options)
                        _CertifiedReportSheetTile(
                          title: option.displayName,
                          isSelected: option.uuid == widget.value,
                          trailing: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap:
                                _downloadingUuid != null ||
                                    widget.isDownloading(option.uuid)
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final navigator = Navigator.of(context);
                                    setState(() {
                                      _downloadingUuid = option.uuid;
                                    });

                                    final pdfUrl = await widget.onDownload(
                                      option,
                                    );
                                    if (!mounted) {
                                      return;
                                    }

                                    setState(() {
                                      _downloadingUuid = null;
                                    });

                                    if (pdfUrl.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to open certified report PDF.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    navigator.pop();
                                    await navigator.push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ViewFullScreenDoc(
                                          title: option.displayName,
                                          imageUrl: pdfUrl,
                                        ),
                                      ),
                                    );
                                  },
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: Center(
                                child:
                                    _downloadingUuid == option.uuid ||
                                        widget.isDownloading(option.uuid)
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: FastCircularProgressIndicator(),
                                      )
                                    : const Icon(
                                        Icons.visibility_outlined,
                                        color: AppColors.secondaryColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onChanged(option.uuid);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureDialogContent extends StatefulWidget {
  const _SignatureDialogContent({
    required this.title,
    required this.existingSignatureUrl,
    required this.onSaved,
  });

  final String title;
  final String? existingSignatureUrl;
  final Future<String?> Function(Uint8List bytes) onSaved;

  @override
  State<_SignatureDialogContent> createState() =>
      _SignatureDialogContentState();
}

class _SignatureDialogContentState extends State<_SignatureDialogContent> {
  late final SignatureController _signatureController;
  late final TextEditingController _typedController;
  final ImagePicker _imagePicker = ImagePicker();
  _SignatureOption _selectedOption = _SignatureOption.draw;
  Uint8List? _uploadedBytes;
  String? _uploadedFileName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _signatureController =
        SignatureController(
          penStrokeWidth: 3,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white,
        )..addListener(() {
          if (mounted) {
            setState(() {});
          }
        });
    _typedController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _typedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    return SafeArea(
      child: Center(
        child: Dialog(
          backgroundColor: AppColors.surfaceDark,
          shape: AppDialogStyle.shape(radius: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextView.body1(
                  widget.title,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                const AppTextView.body3(
                  'Choose how you want to add this signature.',
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SignatureOptionChip(
                        label: 'My Signature',
                        isSelected:
                            _selectedOption == _SignatureOption.mySignature,
                        onTap: () {
                          setState(() {
                            _selectedOption = _SignatureOption.mySignature;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _SignatureOptionChip(
                        label: 'Draw',
                        isSelected: _selectedOption == _SignatureOption.draw,
                        onTap: () {
                          setState(() {
                            _selectedOption = _SignatureOption.draw;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _SignatureOptionChip(
                        label: 'Type',
                        isSelected: _selectedOption == _SignatureOption.type,
                        onTap: () {
                          setState(() {
                            _selectedOption = _SignatureOption.type;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _SignatureOptionChip(
                        label: 'Upload',
                        isSelected: _selectedOption == _SignatureOption.upload,
                        onTap: () {
                          setState(() {
                            _selectedOption = _SignatureOption.upload;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_selectedOption == _SignatureOption.mySignature)
                  _SignaturePreviewPanel(
                    backgroundColor: Colors.white,
                    child:
                        widget.existingSignatureUrl == null ||
                            widget.existingSignatureUrl!.trim().isEmpty
                        ? const Center(
                            child: AppTextView.body3(
                              'No saved signature available.',
                              color: AppColors.textSecondary,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.existingSignatureUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: AppTextView.body3(
                                  'Unable to load saved signature.',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                  ),
                if (_selectedOption == _SignatureOption.draw)
                  _SignaturePreviewPanel(
                    backgroundColor: Colors.white,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_selectedOption == _SignatureOption.type)
                  _SignaturePreviewPanel(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _typedController,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type your signature',
                              hintStyle: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.fieldBorder.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.secondaryColor,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed:
                                  _typedController.text.trim().isEmpty ||
                                      _isSubmitting
                                  ? null
                                  : () async {
                                      final pngBytes =
                                          await _buildTypedSignatureBytes(
                                            _typedController.text.trim(),
                                          );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      await _submitSignature(
                                        navigator,
                                        ScaffoldMessenger.of(context),
                                        pngBytes,
                                      );
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.secondaryColor,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: FastCircularProgressIndicator(),
                                    )
                                  : const Text('Use'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectedOption == _SignatureOption.upload)
                  _SignaturePreviewPanel(
                    backgroundColor: Colors.white,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _pickSignatureFromGallery,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.fieldBorder.withValues(
                              alpha: 0.55,
                            ),
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DottedBorderPainter(
                                  color: AppColors.fieldBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: _uploadedBytes == null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.file_upload_outlined,
                                          color: AppColors.secondaryColor,
                                          size: 28,
                                        ),
                                        SizedBox(height: 10),
                                        AppTextView.body2(
                                          'Tap to upload signature',
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        SizedBox(height: 4),
                                        AppTextView.body4(
                                          'Select from gallery',
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Image.memory(
                                              _uploadedBytes!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          AppTextView.body4(
                                            _uploadedFileName ?? 'Uploaded',
                                            color: AppColors.textSecondary,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          FilledButton(
                                            onPressed: _isSubmitting
                                                ? null
                                                : () async {
                                                    if (_uploadedBytes ==
                                                        null) {
                                                      return;
                                                    }
                                                    await _submitSignature(
                                                      navigator,
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ),
                                                      _uploadedBytes!,
                                                    );
                                                  },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.secondaryColor,
                                              foregroundColor:
                                                  AppColors.textPrimary,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: _isSubmitting
                                                ? SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        FastCircularProgressIndicator(),
                                                  )
                                                : const Text('Use'),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 10,
                  overflowSpacing: 8,
                  children: [
                    if (_selectedOption == _SignatureOption.draw)
                      TextButton(
                        onPressed: () {
                          _signatureController.clear();
                          setState(() {});
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => navigator.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(
                          color: AppColors.fieldBorder.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    if (_selectedOption == _SignatureOption.mySignature ||
                        _selectedOption == _SignatureOption.draw) ...[
                      FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : _selectedOption == _SignatureOption.mySignature
                            ? (widget.existingSignatureUrl == null ||
                                      widget.existingSignatureUrl!
                                          .trim()
                                          .isEmpty
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      setState(() {
                                        _isSubmitting = true;
                                      });
                                      final response = await http.get(
                                        Uri.parse(widget.existingSignatureUrl!),
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      if (response.statusCode >= 200 &&
                                          response.statusCode < 300) {
                                        final message = await widget.onSaved(
                                          response.bodyBytes,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        if (message == null ||
                                            message.trim().isEmpty) {
                                          navigator.pop();
                                          return;
                                        }

                                        setState(() {
                                          _isSubmitting = false;
                                        });
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        _isSubmitting = false;
                                      });
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to load saved signature.',
                                          ),
                                        ),
                                      );
                                    })
                            : _signatureController.isNotEmpty
                            ? () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final pngBytes = await _signatureController
                                    .toPngBytes();
                                if (!mounted || pngBytes == null) {
                                  return;
                                }
                                await _submitSignature(
                                  navigator,
                                  messenger,
                                  pngBytes,
                                );
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondaryColor,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: FastCircularProgressIndicator(),
                              )
                            : Text(
                                _selectedOption == _SignatureOption.mySignature
                                    ? 'Use'
                                    : 'Save',
                              ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSignature(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    Uint8List bytes,
  ) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final message = await widget.onSaved(bytes);
    if (!mounted) {
      return;
    }

    if (message == null || message.trim().isEmpty) {
      navigator.pop();
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickSignatureFromGallery() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (!mounted || pickedFile == null) {
      return;
    }
    final bytes = await pickedFile.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _uploadedBytes = bytes;
      _uploadedFileName = pickedFile.name;
    });
  }

  Future<Uint8List> _buildTypedSignatureBytes(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 700.0;
    const height = 240.0;
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 54,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: width - 40);

    final offset = Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}

class _DialogOptionTile extends StatelessWidget {
  const _DialogOptionTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.4),
          ),
        ),
        child: AppTextView.body2(
          title,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DateSelectionChip extends StatelessWidget {
  const _DateSelectionChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondaryColor.withValues(alpha: 0.18)
                : AppColors.surfaceDark2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondaryColor
                  : AppColors.fieldBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextView.body4(
                label,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 4),
              AppTextView.body3(
                value,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomRangeCalendar extends StatelessWidget {
  const _CustomRangeCalendar({
    required this.visibleMonth,
    required this.minDate,
    required this.maxDate,
    required this.startDate,
    required this.endDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final resolvedMinDate = _dateOnly(minDate);
    final resolvedMaxDate = _dateOnly(maxDate);
    final startOffset = firstDayOfMonth.weekday % 7;
    final gridStart = firstDayOfMonth.subtract(Duration(days: startOffset));
    final days = List<DateTime>.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
      growable: false,
    );
    final previousMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month - 1,
      1,
    );
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 1);
    final canGoPrevious = !_isMonthBefore(previousMonth, resolvedMinDate);
    final canGoNext = !_isMonthAfter(nextMonth, resolvedMaxDate);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: canGoPrevious
                  ? () => onMonthChanged(previousMonth)
                  : null,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: AppTextView.body2(
                MaterialLocalizations.of(context).formatMonthYear(visibleMonth),
                color: AppColors.textPrimary,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: canGoNext ? () => onMonthChanged(nextMonth) : null,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            _WeekdayLabel('S'),
            _WeekdayLabel('M'),
            _WeekdayLabel('T'),
            _WeekdayLabel('W'),
            _WeekdayLabel('T'),
            _WeekdayLabel('F'),
            _WeekdayLabel('S'),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final date = days[index];
            final isEnabled =
                !date.isBefore(resolvedMinDate) &&
                !date.isAfter(resolvedMaxDate);
            return _CalendarDayCell(
              date: date,
              isCurrentMonth: date.month == visibleMonth.month,
              isEnabled: isEnabled,
              isStart: _isSameDate(date, startDate),
              isEnd: _isSameDate(date, endDate),
              isInRange: _isInRange(date, startDate, endDate),
              onTap: isEnabled ? () => onDateSelected(date) : null,
            );
          },
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AppTextView.body4(
          label,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final bool isStart;
  final bool isEnd;
  final bool isInRange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = isStart || isEnd;
    final backgroundColor = !isEnabled
        ? AppColors.surfaceDark2.withValues(alpha: 0.45)
        : isSelected
        ? AppColors.secondaryColor
        : isInRange
        ? AppColors.secondaryColor.withValues(alpha: 0.18)
        : AppColors.surfaceDark2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !isEnabled
                  ? AppColors.fieldBorder.withValues(alpha: 0.08)
                  : isSelected
                  ? AppColors.secondaryColor
                  : AppColors.fieldBorder.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: AppTextView.body3(
            '${date.day}',
            color: !isEnabled
                ? AppColors.textSecondary.withValues(alpha: 0.45)
                : isCurrentMonth
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

bool _isMonthBefore(DateTime month, DateTime minDate) {
  return month.year < minDate.year ||
      (month.year == minDate.year && month.month < minDate.month);
}

bool _isMonthAfter(DateTime month, DateTime maxDate) {
  return month.year > maxDate.year ||
      (month.year == maxDate.year && month.month > maxDate.month);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDate(DateTime date, DateTime? other) {
  return other != null &&
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}

bool _isInRange(DateTime date, DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return false;
  }

  final current = DateTime(date.year, date.month, date.day);
  final resolvedStart = DateTime(start.year, start.month, start.day);
  final resolvedEnd = DateTime(end.year, end.month, end.day);

  return !current.isBefore(resolvedStart) && !current.isAfter(resolvedEnd);
}

class _CertifiedReportSheetTile extends StatelessWidget {
  const _CertifiedReportSheetTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.secondaryColor
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

enum _SignatureOption { mySignature, draw, type, upload }

class _SignatureOptionChip extends StatelessWidget {
  const _SignatureOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.secondaryColor),
          ),
          child: AppTextView.body4(
            label,
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.secondaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SignaturePreviewPanel extends StatelessWidget {
  const _SignaturePreviewPanel({
    required this.child,
    this.backgroundColor = Colors.white,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.45),
          width: 1.6,
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    void drawDashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = math.sqrt((dx * dx) + (dy * dy));
      final dashCount = (distance / (dashWidth + dashSpace)).floor();

      for (var i = 0; i <= dashCount; i++) {
        final t1 = (i * (dashWidth + dashSpace)) / distance;
        final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;
        if (t1 > 1) {
          break;
        }
        final p1 = Offset(start.dx + dx * t1, start.dy + dy * t1);
        final p2 = Offset(
          start.dx + dx * t2.clamp(0, 1),
          start.dy + dy * t2.clamp(0, 1),
        );
        canvas.drawLine(p1, p2, paint);
      }
    }

    final rect = Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4);
    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

enum _RangeSelectionMode { start, end }

enum _TimeRangeDialogStep { options, customRange }

enum PerformanceReportTimeRangeDialogResult { thisQuarter }
