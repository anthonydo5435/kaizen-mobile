import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_selection_sheet.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../compliance/presentation/pages/document/full_screen_doc.dart';
import '../../domain/entities/performance_report.dart';
import '../providers/performance_report_history_controller.dart';
import '../widgets/performance_report_selectors.dart';
import 'performance_report_dialogs.dart';

Future<void> showPerformanceReportCertifiedReportsSheet(
  BuildContext context, {
  required String? value,
  required List<CertifiedReportOption> options,
  required DateTime minDate,
  required DateTime maxDate,
  required PerformanceReportHistoryLoader loadReports,
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
      minDate: minDate,
      maxDate: maxDate,
      loadReports: loadReports,
      isDownloading: isDownloading,
      onChanged: onChanged,
      onDownload: onDownload,
    ),
  );
}

class _CertifiedReportsSheetContent extends StatefulWidget {
  const _CertifiedReportsSheetContent({
    required this.value,
    required this.options,
    required this.minDate,
    required this.maxDate,
    required this.loadReports,
    required this.isDownloading,
    required this.onChanged,
    required this.onDownload,
  });

  final String? value;
  final List<CertifiedReportOption> options;
  final DateTime minDate;
  final DateTime maxDate;
  final PerformanceReportHistoryLoader loadReports;
  final bool Function(String uuid) isDownloading;
  final ValueChanged<String?> onChanged;
  final Future<String> Function(CertifiedReportOption option) onDownload;

  @override
  State<_CertifiedReportsSheetContent> createState() => _CertifiedReportsSheetContentState();
}

class _CertifiedReportsSheetContentState extends State<_CertifiedReportsSheetContent> {
  final _downloadingUuid = ValueNotifier<String?>(null);
  late final PerformanceReportHistoryController _historyController;

  @override
  void initState() {
    super.initState();
    _historyController = PerformanceReportHistoryController(
      initialOptions: widget.options,
      loadReports: widget.loadReports,
    );
    unawaited(_historyController.refresh());
  }

  @override
  void dispose() {
    _historyController.dispose();
    _downloadingUuid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _historyController,
      builder: (context, _) => _buildSheet(context, _historyController),
    );
  }

  Widget _buildSheet(BuildContext context, PerformanceReportHistoryController controller) {
    final mediaQuery = MediaQuery.of(context);
    final options = controller.options;
    return FractionallySizedBox(
      key: const ValueKey('performance-reports-sheet'),
      heightFactor: 0.75,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFilterSheetHeader(
              title: AppStrings.performanceReportHistoryTitle,
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: PerformanceReportTimeRangeSelector(
                key: const ValueKey('performance-report-history-date-filter'),
                label: controller.dateRangeLabel,
                backgroundColor: AppColors.cardBg,
                borderSide: BorderSide(color: AppColors.grey1.withValues(alpha: 0.3), width: 0.3),
                onTap: controller.isLoading ? null : _selectHistoryDates,
              ),
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppTextView.body3(controller.error!, color: AppColors.textSecondary),
              ),
            if (controller.isLoading)
              Expanded(child: Center(child: FastCircularProgressIndicator()))
            else
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _downloadingUuid,
                  builder: (context, downloadingUuid, _) => Scrollbar(
                    thumbVisibility: options.length > 4,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + mediaQuery.viewInsets.bottom),
                      physics: const BouncingScrollPhysics(),
                      itemCount: math.max(1, options.length),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (options.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: AppTextView.body3(
                              AppStrings.performanceReportHistoryEmpty,
                              color: AppColors.textSecondary,
                            ),
                          );
                        }
                        return _buildReportTile(context, options[index], downloadingUuid);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectHistoryDates() async {
    final localizations = MaterialLocalizations.of(context);
    final range = _historyController.dateRange;
    final result = await showPerformanceReportTimeRangeDialog(
      context,
      startDate: range?.start,
      endDate: range?.end,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      selectStartDateInitially: true,
      calendarOnly: true,
      allowClearDates: true,
      formatDate: localizations.formatShortDate,
    );
    if (!mounted) return;
    if (result == PerformanceReportTimeRangeDialogResult.clearDates) {
      await _historyController.clearDates();
    } else if (result is DateTimeRange) {
      await _historyController.applyDateRange(result);
    }
  }

  Widget _buildReportTile(
    BuildContext context,
    CertifiedReportOption option,
    String? downloadingUuid,
  ) {
    final isDownloading = downloadingUuid == option.uuid || widget.isDownloading(option.uuid);
    return _CertifiedReportSheetTile(
      key: ValueKey('performance-report-history-${option.uuid}'),
      title: option.displayName,
      subtitle: option.createdAt,
      isSelected: option.uuid == widget.value,
      trailing: Tooltip(
        message: AppStrings.performanceReportReadReport,
        child: Material(
          color: AppColors.secondaryColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: downloadingUuid != null || isDownloading ? null : () => _openPdf(option),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: isDownloading
                    ? FastCircularProgressIndicator(width: 18, height: 18)
                    : const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.secondaryColor,
                        size: 20,
                      ),
              ),
            ),
          ),
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        widget.onChanged(option.uuid);
      },
    );
  }

  Future<void> _openPdf(CertifiedReportOption option) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    _downloadingUuid.value = option.uuid;
    final pdfUrl = await widget.onDownload(option);
    if (!mounted) return;
    _downloadingUuid.value = null;
    if (pdfUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.performanceReportPdfUnavailable)),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ViewFullScreenDoc(title: option.displayName, imageUrl: pdfUrl),
      ),
    );
  }
}

class _CertifiedReportSheetTile extends StatelessWidget {
  const _CertifiedReportSheetTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.grey1.withValues(alpha: 0.3), width: 0.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppTextView.body3(
                      AppStrings.performanceReportHistoryItemTitle,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body3(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      color: isSelected ? AppColors.secondaryColor : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      AppTextView.body4(
                        AppStrings.performanceReportCreatedAt(subtitle!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ],
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
