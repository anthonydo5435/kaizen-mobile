import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/app_permission_utils.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../providers/check_in_controller.dart';
import 'performance_report_dialogs.dart';
import 'performance_report_paygrade_pipeline_sheet.dart';
import 'seat_description_final_check_in_report.dart';

bool _isUnavailablePaygradeDisplay(String value) =>
    value.trim() == AppStrings.paygradesUnavailableDisplay;

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({
    super.key,
    required this.profile,
    this.isMyReport = false,
  });
  final AuditProfile profile;
  final bool isMyReport;
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(
          create: (_) => createAuditRemoteDataSource(),
        ),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) =>
              createGetAuditOverviewUseCase(repository),
        ),
        ChangeNotifierProvider<CheckInController>(
          create: (context) => CheckInController(
            context.read<GetAuditOverviewUseCase>(),
            null,
            null,
            null,
            null,
            null,
            null,
            context.read<AuditRepositoryImpl>(),
          )..initializePerformanceReport(profile),
        ),
      ],
      child: _PerformanceReportView(isMyReport: isMyReport),
    );
  }
}

class _PerformanceReportView extends StatefulWidget {
  const _PerformanceReportView({required this.isMyReport});

  final bool isMyReport;

  @override
  State<_PerformanceReportView> createState() => _PerformanceReportViewState();
}

class _PerformanceReportViewState extends State<_PerformanceReportView> {
  late final TextEditingController _commentsController;
  late final ValueNotifier<_PerformanceReportLocalState> _localStateNotifier;
  String _lastSyncedCommitment = '';
  bool _canGenerateRemarks = false;

  static const List<String> _timeRanges = <String>[
    'This Quarter',
    'Custom Date Range',
  ];

  @override
  void initState() {
    super.initState();
    _commentsController = TextEditingController();
    _localStateNotifier = ValueNotifier(const _PerformanceReportLocalState());
    _loadGenerateRemarksAccess();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _localStateNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadGenerateRemarksAccess() async {
    final user = await AppPreference.getUser();
    if (!mounted) {
      return;
    }

    setState(() {
      _canGenerateRemarks = AppPermissionUtils.canAccessAuditTeamMembers(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CheckInController>();
    final state = controller.state;
    final report = state.performanceReport;
    final reportViewData = controller.performanceReportViewData;

    if (_lastSyncedCommitment != state.performanceReportCommitment) {
      _lastSyncedCommitment = state.performanceReportCommitment;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _commentsController.text == _lastSyncedCommitment) {
          return;
        }

        _commentsController.value = TextEditingValue(
          text: _lastSyncedCommitment,
          selection: TextSelection.collapsed(
            offset: _lastSyncedCommitment.length,
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        leadingWidth: 40,
        title: AppTextView.title1(
          AppStrings.reportsScreenTitle,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: state.isPerformanceReportLoading
            ? FastCircularProgressIndicator()
            : report == null || reportViewData == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AppTextView.body(
                    AppStrings.performanceReportUnavailable,
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ValueListenableBuilder<_PerformanceReportLocalState>(
                valueListenable: _localStateNotifier,
                builder: (context, localState, _) {
                  final selectedCategoryIndex = controller
                      .resolvePerformanceReportSelectedCategoryIndex(
                        selectedCategoryIndex: localState.selectedCategoryIndex,
                        categorySelectionKey: localState.categorySelectionKey,
                      );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                    child: Column(
                      children: [
                        _ProfileSummaryCard(report: report),
                        const SizedBox(height: 14),
                        if (report.profile.profiles.length > 1) ...[
                          _ProfileChipsRow(
                            report: report,
                            showNoProfileChip: false,
                            isLoading: state.isPerformanceReportLoading,
                            onProfileTap: (profile) => _handleProfileChipTap(
                              controller,
                              report,
                              profile,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (reportViewData.isOpenSeatView) ...[
                          _OpenSeatEmptyView(
                            message: reportViewData.reportMessage,
                          ),
                        ] else if (reportViewData
                            .shouldShowCompleteReportUi) ...[
                          _TimeRangeSelector(
                            value: state.performanceReportTimeRange,
                            options: _timeRanges,
                            customRangeLabel:
                                state.performanceReportTimeRange ==
                                        'Custom Date Range' &&
                                    state.performanceReportStartDate != null &&
                                    state.performanceReportEndDate != null
                                ? '${_formatDate(state.performanceReportStartDate!)} - ${_formatDate(state.performanceReportEndDate!)}'
                                : null,
                            onChanged: (value) => _handleTimeRangeChanged(
                              context,
                              controller,
                              value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (state.certifiedReportOptions.isNotEmpty) ...[
                            _CertifiedReportsSelector(
                              value: state.selectedCertifiedReportUuid,
                              options: state.certifiedReportOptions,
                              isDownloading:
                                  controller.isCertifiedReportPdfDownloading,
                              onChanged: controller.selectCertifiedReport,
                              onDownload: (option) =>
                                  _downloadCertifiedReportPdf(
                                    context,
                                    controller,
                                    option,
                                  ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (report.hasPersonalityData) ...[
                            _PersonaCard(
                              report: report,
                              showPersonaHeader: state.isOwner,
                              showGenerateRemarksAction: _canGenerateRemarks,
                              isGeneratingRemarks:
                                  state.isGeneratingPerformanceReportRemarks,
                              onGenerateRemarks: () async {
                                await controller
                                    .generatePerformanceReportRemarks();
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          _RatingsTable(
                            rows: report.categoryTabs.isEmpty
                                ? report.ratingRows
                                : report
                                      .categoryTabs[selectedCategoryIndex]
                                      .rows,
                            onDescriptionGo: (row) =>
                                _openFinalReport(context, report, row),
                            categoryTabs: report.categoryTabs,
                            selectedCategoryIndex: selectedCategoryIndex,
                            onCategorySelected: (index) {
                              _localStateNotifier.value = localState.copyWith(
                                selectedCategoryIndex: index,
                                categorySelectionKey:
                                    reportViewData.categorySelectionKey,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          PerformanceReportPaygradePipelineSection(
                            report: report,
                            onTap: () =>
                                showPerformanceReportPaygradePipelineSheet(
                                  context,
                                  report: report,
                                  currentStep:
                                      reportViewData.currentPaygradeStep,
                                ),
                          ),
                          if (report.coreValues.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _CoreValuesCard(
                              values: report.coreValues,
                              isExpanded: localState.isCoreValuesExpanded,
                              onToggle: () {
                                _localStateNotifier.value = localState.copyWith(
                                  isCoreValuesExpanded:
                                      !localState.isCoreValuesExpanded,
                                );
                              },
                            ),
                          ],
                          if (!widget.isMyReport) ...[
                            const SizedBox(height: 16),
                            ListenableBuilder(
                              listenable: AppManager.instance,
                              builder: (context, _) {
                                final canManageContent = AppManager
                                    .instance
                                    .canCurrentOrganizationModifyContent;
                                final isCommitmentReadOnly =
                                    report.isCertified || !canManageContent;

                                return Column(
                                  children: [
                                    _CommitmentCard(
                                      controller: _commentsController,
                                      isReadOnly: isCommitmentReadOnly,
                                      certifiedAt: report.certifiedAt,
                                      employeeSignatureUrl:
                                          report.selectedProfileSignatureUrl,
                                      employeeName:
                                          report.employeeSignatureName ??
                                          report.profile.name,
                                      employeeSignatureBytes:
                                          state.employeeSignatureBytes,
                                      facilitatorSignatureUrl:
                                          report.facilitatorSignatureUrl,
                                      facilitatorName: report.facilitatorName,
                                      facilitatorSignatureBytes:
                                          state.facilitatorSignatureBytes,
                                      onChanged: controller
                                          .updatePerformanceReportCommitment,
                                      onAddEmployeeSignature: () =>
                                          _openSignaturePad(
                                            context,
                                            title: 'Employee Signature',
                                            existingSignatureUrl: report
                                                .selectedProfileSignatureUrl,
                                            onSaved: controller
                                                .saveEmployeeSignature,
                                          ),
                                      onAddFacilitatorSignature: () async {
                                        final user =
                                            await AppPreference.getUser();
                                        if (!context.mounted) {
                                          return;
                                        }
                                        await _openSignaturePad(
                                          context,
                                          title: 'Facilitator Signature',
                                          existingSignatureUrl:
                                              user?.signature?.image,
                                          onSaved: controller
                                              .saveFacilitatorSignature,
                                        );
                                      },
                                      onClearEmployeeSignature:
                                          controller.clearEmployeeSignature,
                                      onClearFacilitatorSignature:
                                          controller.clearFacilitatorSignature,
                                    ),
                                    if (!report.isCertified &&
                                        canManageContent) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed:
                                              state.isAuditActionLoading ||
                                                  state
                                                      .isFacilitatorSignatureUploading
                                              ? null
                                              : () => _handleCertify(
                                                  context,
                                                  controller,
                                                ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.secondaryColor,
                                            foregroundColor:
                                                AppColors.textPrimary,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child:
                                              state.isAuditActionLoading ||
                                                  state
                                                      .isFacilitatorSignatureUploading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          AppColors.textPrimary,
                                                        ),
                                                  ),
                                                )
                                              : const Text(AppStrings.certify),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ] else if (reportViewData.shouldShowMessageOnly &&
                            reportViewData.reportMessage != null) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: AppTextView.body2(
                              reportViewData.reportMessage!,
                              color: AppColors.textSecondary,
                              textAlign: TextAlign.center,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _handleProfileChipTap(
    CheckInController controller,
    PerformanceReport report,
    AuditMemberProfile selectedProfile,
  ) async {
    if (controller.state.isPerformanceReportLoading) {
      return;
    }

    final profileUuid = selectedProfile.uuid.trim();
    if (profileUuid.isEmpty) {
      return;
    }

    _localStateNotifier.value = const _PerformanceReportLocalState();
    await controller.initializePerformanceReport(
      _buildSelectedReportProfile(
        currentProfile: report.profile,
        selectedProfile: selectedProfile,
      ),
    );
  }

  AuditProfile _buildSelectedReportProfile({
    required AuditProfile currentProfile,
    required AuditMemberProfile selectedProfile,
  }) {
    final selectedProfileUuid = selectedProfile.uuid.trim();
    final selectedEmail = selectedProfile.email.trim();

    return AuditProfile(
      uuid: selectedProfileUuid,
      profileJob: currentProfile.profileJob,
      profileUuid: selectedProfileUuid,
      email: selectedEmail.isEmpty ? currentProfile.email : selectedEmail,
      imageUrl: selectedProfile.imageUrl,
      isFavorite: currentProfile.isFavorite,
      lastAuditDates: currentProfile.lastAuditDates,
      roleTitle: currentProfile.roleTitle,
      name: selectedProfile.name,
      lastAuditLabel: currentProfile.lastAuditLabel,
      yearQuarter: currentProfile.yearQuarter,
      seatProfile: currentProfile.seatProfile,
      overallScore: currentProfile.overallScore,
      confidenceLevel: currentProfile.confidenceLevel,
      status: currentProfile.status,
      reviewerInitials: currentProfile.reviewerInitials,
      avatarLabel: currentProfile.avatarLabel,
      profiles: currentProfile.profiles,
      avatarImageUrl: selectedProfile.imageUrl,
    );
  }

  Future<void> _handleTimeRangeChanged(
    BuildContext context,
    CheckInController controller,
    String value,
  ) async {
    if (value == 'This Quarter') {
      await controller.selectPerformanceReportTimeRange(value);
      return;
    }

    final result = await _openTimeRangeDialog(
      context,
      startDate: controller.state.performanceReportStartDate,
      endDate: controller.state.performanceReportEndDate,
      report: controller.state.performanceReport,
    );
    if (!mounted || result == null) {
      return;
    }

    if (result == PerformanceReportTimeRangeDialogResult.thisQuarter) {
      await controller.selectPerformanceReportTimeRange('This Quarter');
      return;
    }

    final range = result as DateTimeRange;

    await controller.applyPerformanceReportCustomDateRange(
      startDate: range.start,
      endDate: range.end,
    );
  }

  Future<Object?> _openTimeRangeDialog(
    BuildContext context, {
    DateTime? startDate,
    DateTime? endDate,
    PerformanceReport? report,
  }) {
    return showPerformanceReportTimeRangeDialog(
      context,
      startDate: startDate,
      endDate: endDate,
      minDate: _resolvePerformanceReportMinDate(report),
      maxDate: _normalizeCalendarDate(DateTime.now()),
      formatDate: _formatDate,
    );
  }

  String _formatDate(DateTime value) {
    return MaterialLocalizations.of(context).formatShortDate(value);
  }

  DateTime _resolvePerformanceReportMinDate(PerformanceReport? report) {
    final parsedCreatedAt = _resolveParsedPerformanceReportCreatedAt(report);
    final today = _normalizeCalendarDate(DateTime.now());
    if (parsedCreatedAt == null) {
      return today;
    }

    final normalizedCreatedAt = _normalizeCalendarDate(parsedCreatedAt);
    return normalizedCreatedAt.isAfter(today) ? today : normalizedCreatedAt;
  }

  DateTime _normalizeCalendarDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _resolveParsedPerformanceReportCreatedAt(
    PerformanceReport? report,
  ) {
    final candidates = <String?>[
      report?.createdAt,
      report?.reportSnapshot['createdAt']?.toString(),
      report?.reportSnapshot['created_at']?.toString(),
      report?.profile.lastAuditLabel,
    ];

    for (final candidate in candidates) {
      final parsed = _parseReportCreatedAt(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  DateTime? _parseReportCreatedAt(String? value) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return null;
    }

    final normalizedValue = trimmedValue
        .replaceAll(RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false), r'$1')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parsedDateTime = DateTime.tryParse(normalizedValue);
    if (parsedDateTime != null) {
      final localDateTime = parsedDateTime.toLocal();
      return DateTime(
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
      );
    }

    final isoDateMatch = RegExp(
      r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})',
    ).firstMatch(normalizedValue);
    if (isoDateMatch != null) {
      final year = int.tryParse(isoDateMatch.group(1)!);
      final month = int.tryParse(isoDateMatch.group(2)!);
      final day = int.tryParse(isoDateMatch.group(3)!);
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    const monthNames = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    final dayMonthYearMatch = RegExp(
      r'(\d{1,2})[\s/-]+([A-Za-z]+)(?:[\s/-]+(\d{4}))?',
    ).firstMatch(normalizedValue);
    if (dayMonthYearMatch != null) {
      final day = int.tryParse(dayMonthYearMatch.group(1)!);
      final month = monthNames[dayMonthYearMatch.group(2)!.toLowerCase()];
      final year =
          int.tryParse(dayMonthYearMatch.group(3) ?? '') ?? DateTime.now().year;
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    final monthDayYearMatch = RegExp(
      r'([A-Za-z]+)[\s/-]+(\d{1,2})(?:[\s/-]+(\d{4}))?',
    ).firstMatch(normalizedValue);
    if (monthDayYearMatch != null) {
      final month = monthNames[monthDayYearMatch.group(1)!.toLowerCase()];
      final day = int.tryParse(monthDayYearMatch.group(2)!);
      final year =
          int.tryParse(monthDayYearMatch.group(3) ?? '') ?? DateTime.now().year;
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    final numericDateMatch = RegExp(
      r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
    ).firstMatch(normalizedValue);
    if (numericDateMatch != null) {
      final first = int.tryParse(numericDateMatch.group(1)!);
      final second = int.tryParse(numericDateMatch.group(2)!);
      final year = int.tryParse(numericDateMatch.group(3)!);
      if (first != null && second != null && year != null) {
        final dayFirst = _safeDate(
          year,
          second > 12 ? first : second,
          second > 12 ? second : first,
        );
        if (dayFirst != null) {
          return dayFirst;
        }

        final monthFirst = _safeDate(year, first, second);
        if (monthFirst != null) {
          return monthFirst;
        }
      }
    }

    return null;
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }

    return value;
  }

  Future<void> _handleCertify(
    BuildContext context,
    CheckInController controller,
  ) async {
    if (!AppManager.instance.canCurrentOrganizationModifyContent) {
      return;
    }

    final message = await controller.certifyPerformanceReport();
    if (!context.mounted) {
      return;
    }

    if (message != 'Performance report certified successfully.') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openFinalReport(
    BuildContext context,
    PerformanceReport report,
    PerformanceReportRatingRow row,
  ) {
    final auditController = context.read<CheckInController>();
    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CheckInController>.value(
          value: auditController,
          child: SeatDescriptionFinalCheckInReportScreen(
            flowFirstId: report.profile.profileJob,
            profileUuid: report.profile.profileUuid,
            descriptionId: row.descriptionUuid,
            quarter: currentYearQuarter.quarter,
            year: currentYearQuarter.year,
          ),
        ),
      ),
    );
  }

  Future<String> _downloadCertifiedReportPdf(
    BuildContext context,
    CheckInController controller,
    CertifiedReportOption option,
  ) async {
    final pdfUrl = await controller.downloadCertifiedReportPdf(option.uuid);
    return pdfUrl;
  }

  Future<void> _openSignaturePad(
    BuildContext context, {
    required String title,
    required String? existingSignatureUrl,
    required Future<String?> Function(Uint8List bytes) onSaved,
  }) async {
    await showPerformanceReportSignatureDialog(
      context,
      title: title,
      existingSignatureUrl: existingSignatureUrl,
      onSaved: onSaved,
    );
  }
}

class _PerformanceReportLocalState {
  const _PerformanceReportLocalState({
    this.selectedCategoryIndex = 0,
    this.categorySelectionKey,
    this.isCoreValuesExpanded = false,
  });

  final int selectedCategoryIndex;
  final String? categorySelectionKey;
  final bool isCoreValuesExpanded;

  _PerformanceReportLocalState copyWith({
    int? selectedCategoryIndex,
    String? categorySelectionKey,
    bool? isCoreValuesExpanded,
  }) {
    return _PerformanceReportLocalState(
      selectedCategoryIndex:
          selectedCategoryIndex ?? this.selectedCategoryIndex,
      categorySelectionKey: categorySelectionKey ?? this.categorySelectionKey,
      isCoreValuesExpanded: isCoreValuesExpanded ?? this.isCoreValuesExpanded,
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.report});

  final PerformanceReport report;

  @override
  Widget build(BuildContext context) {
    final isUnavailablePaygrade = _isUnavailablePaygradeDisplay(
      report.currentPaygrade,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 13,
          child: Container(
            constraints: const BoxConstraints(minHeight: 172),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileSummaryAvatar(
                  imageUrl:
                      report.profile.imageUrl ?? report.profile.avatarImageUrl,
                  name: report.profile.name,
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextView.body3(
                      report.profile.seatProfile,
                      color: AppColors.secondaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body1(
                      report.profile.name,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const AppTextView.body3(
                          'Paygrade: ',
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        AppTextView.body3(
                          report.currentPaygrade,
                          color: isUnavailablePaygrade
                              ? AppColors.secondaryColor
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 10,
          child: Column(
            children: [
              _MetricCard(
                value: report.overallPerformanceScore.toStringAsFixed(1),
                label: 'Running Overall Performance Score',
                valueColor: AppColors.lightGreen1,
              ),
              const SizedBox(height: 8),
              _MetricCard(
                value:
                    '${report.confidenceLevel.toStringAsFixed(report.confidenceLevel.truncateToDouble() == report.confidenceLevel ? 0 : 1)}%',
                label: 'Confidence Level',
                valueColor: AppColors.orange1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpenSeatEmptyView extends StatelessWidget {
  const _OpenSeatEmptyView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message?.trim().isNotEmpty == true
        ? message!.trim()
        : 'No profile is assigned to this seat yet.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.person_off_outlined,
            color: AppColors.secondaryColor,
            size: 34,
          ),
          const SizedBox(height: 12),
          AppTextView.body1(
            'No Profile Assigned',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AppTextView.body3(
            resolvedMessage,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryAvatar extends StatelessWidget {
  const _ProfileSummaryAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);
    if (resolvedImageUrl == null) {
      return _ProfileSummaryAvatarFallback(name: name);
    }

    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondaryColor, width: 1.5),
      ),
      child: ClipOval(
        child: Image.network(
          resolvedImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _ProfileSummaryAvatarFallback(name: name),
        ),
      ),
    );
  }
}

class _ProfileSummaryAvatarFallback extends StatelessWidget {
  const _ProfileSummaryAvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();

    return Container(
      width: 65,
      height: 65,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.grey2,
      ),
      child: AppTextView.title1(
        initial,
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 69),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextView.title1(
            value,
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 4),
          AppTextView.body4(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({
    required this.value,
    required this.options,
    required this.onChanged,
    this.customRangeLabel,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? customRangeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textPrimary,
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option == 'Custom Date Range' &&
                            value == 'Custom Date Range' &&
                            customRangeLabel != null
                        ? customRangeLabel!
                        : option,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _CertifiedReportsSelector extends StatelessWidget {
  const _CertifiedReportsSelector({
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
  Widget build(BuildContext context) {
    final selectedValue = options.any((item) => item.uuid == value)
        ? value
        : null;
    String? selectedLabel;
    for (final option in options) {
      if (option.uuid == selectedValue) {
        selectedLabel = option.displayName;
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCertifiedReportsSheet(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel ?? 'Select Certified Report',
                style: TextStyle(
                  color: selectedLabel == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCertifiedReportsSheet(BuildContext context) async {
    await showPerformanceReportCertifiedReportsSheet(
      context,
      value: value,
      options: options,
      isDownloading: isDownloading,
      onChanged: onChanged,
      onDownload: onDownload,
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.report,
    required this.showPersonaHeader,
    required this.showGenerateRemarksAction,
    required this.isGeneratingRemarks,
    required this.onGenerateRemarks,
  });

  final PerformanceReport report;
  final bool showPersonaHeader;
  final bool showGenerateRemarksAction;
  final bool isGeneratingRemarks;
  final Future<void> Function() onGenerateRemarks;

  String get _displayArchetypeSubtitle {
    final value = report.archetypeSubtitle.trim();
    if (value.isEmpty) {
      return value;
    }

    final separatorIndex = value.indexOf('_');
    if (separatorIndex == -1) {
      return value;
    }

    return value.substring(0, separatorIndex).trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (report.hasPersonalityData) ...[
            if (showPersonaHeader) ...[
              Image.asset(
                report.personalityAvatarImagePath!,
                width: 160,
                height: 160,
              ),
              SizedBox(height: 1),
              AppTextView.body2(
                report.archetypeTitle,
                color: AppColors.lightPurple1,
                fontWeight: FontWeight.w600,
              ),
              AppTextView.body1(
                _displayArchetypeSubtitle,
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 12),
              AppTextView.body1(
                report.archetypeSummary,
                color: AppColors.secondaryColor,
                textAlign: TextAlign.center,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              const SizedBox(height: 16),
              for (final paragraph in report.guidanceParagraphs) ...[
                AppTextView.body(
                  paragraph,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 16),
              ],
              if (showGenerateRemarksAction) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: isGeneratingRemarks ? null : onGenerateRemarks,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryColor,
                        side: const BorderSide(color: AppColors.secondaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isGeneratingRemarks
                                ? 'Generating...'
                                : 'Generate Remarks',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryColor,
                            ),
                          ),
                          if (isGeneratingRemarks) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.secondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProfileChipsRow extends StatelessWidget {
  const _ProfileChipsRow({
    required this.report,
    required this.onProfileTap,
    this.showNoProfileChip = false,
    this.isLoading = false,
  });

  final PerformanceReport report;
  final ValueChanged<AuditMemberProfile> onProfileTap;
  final bool showNoProfileChip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final profiles = report.profile.profiles;

    if (profiles.isEmpty && !showNoProfileChip) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: showNoProfileChip
              ? const [_ProfileNameChip(label: 'No Profile', isSelected: false)]
              : [
                  for (var index = 0; index < profiles.length; index++) ...[
                    _ProfileNameChip(
                      label: profiles[index].name,
                      isSelected:
                          profiles[index].uuid == report.profile.uuid ||
                          profiles[index].uuid == report.profile.profileUuid,
                      onTap: isLoading
                          ? null
                          : () => onProfileTap(profiles[index]),
                    ),
                    if (index != profiles.length - 1) const SizedBox(width: 8),
                  ],
                ],
        ),
      ),
    );
  }
}

class _ProfileNameChip extends StatelessWidget {
  const _ProfileNameChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.purple2 : AppColors.grey2,
              width: 1,
            ),
          ),
          child: AppTextView.body3(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RatingsTable extends StatelessWidget {
  const _RatingsTable({
    required this.rows,
    required this.categoryTabs,
    required this.onDescriptionGo,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  final List<PerformanceReportRatingRow> rows;
  final List<PerformanceReportCategoryTab> categoryTabs;
  final ValueChanged<PerformanceReportRatingRow> onDescriptionGo;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryTabs.isNotEmpty) ...[
            _PerformanceReportCategorySelectorCard(
              categoryTabs: categoryTabs,
              selectedCategoryIndex: selectedCategoryIndex,
              onCategorySelected: onCategorySelected,
            ),
            const SizedBox(height: 16),
          ],
          if (rows.isEmpty)
            const AppTextView.body3(
              AppStrings.performanceReportNoCategoryDescriptions,
              color: AppColors.textSecondary,
            )
          else
            Column(
              children: List<Widget>.generate(rows.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == rows.length - 1 ? 0 : 12,
                  ),
                  child: _DescriptionRatingCard(
                    row: rows[index],
                    onGo: () => onDescriptionGo(rows[index]),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _PerformanceReportCategorySelectorCard extends StatelessWidget {
  const _PerformanceReportCategorySelectorCard({
    required this.categoryTabs,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  final List<PerformanceReportCategoryTab> categoryTabs;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  PerformanceReportCategoryTab get _selectedCategory {
    if (categoryTabs.isEmpty) {
      return const PerformanceReportCategoryTab(
        label: '',
        score: 0,
        rows: <PerformanceReportRatingRow>[],
      );
    }

    final resolvedIndex = selectedCategoryIndex.clamp(
      0,
      categoryTabs.length - 1,
    );
    return categoryTabs[resolvedIndex];
  }

  Future<void> _showCategorySheet(BuildContext context) async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      isScrollControlled: true,
      builder: (_) => _PerformanceReportCategorySheet(
        categoryTabs: categoryTabs,
        selectedCategoryIndex: selectedCategoryIndex,
      ),
    );

    if (!context.mounted ||
        selectedIndex == null ||
        selectedIndex == selectedCategoryIndex) {
      return;
    }

    onCategorySelected(selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final category = _selectedCategory;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showCategorySheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppTextView.body3(
                    AppStrings.performanceReportSelectedCategoryTitle,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 4),
                  AppTextView.body2(
                    '${category.label} (${category.score.toStringAsFixed(1)})',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceReportCategorySheet extends StatelessWidget {
  const _PerformanceReportCategorySheet({
    required this.categoryTabs,
    required this.selectedCategoryIndex,
  });

  final List<PerformanceReportCategoryTab> categoryTabs;
  final int selectedCategoryIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 620),
          decoration: const BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: AppTextView.body1(
                          AppStrings.performanceReportCategoriesTitle,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppOverlayCloseButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const AppTextView.body3(
                    AppStrings.performanceReportSelectCategoryDescription,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0; index < categoryTabs.length; index++) ...[
                    _PerformanceReportCategorySheetItem(
                      category: categoryTabs[index],
                      isSelected: index == selectedCategoryIndex,
                      onTap: () => Navigator.of(context).pop(index),
                    ),
                    if (index != categoryTabs.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceReportCategorySheetItem extends StatelessWidget {
  const _PerformanceReportCategorySheetItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final PerformanceReportCategoryTab category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.14)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.secondaryColor
                : AppColors.fieldBorder.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextView.body2(
                    category.label,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 4),
                  AppTextView.body3(
                    '${AppStrings.performanceReportPercentageLabel} ${category.score.toStringAsFixed(1)}%',
                    color: isSelected
                        ? AppColors.secondaryColor
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.secondaryColor
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionRatingCard extends StatelessWidget {
  const _DescriptionRatingCard({required this.row, required this.onGo});

  final PerformanceReportRatingRow row;
  final VoidCallback onGo;

  bool get _canOpenDetail {
    return row.passCount > 0 || row.partialCount > 0 || row.failCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextView.body1(
                  row.title,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppTextView.body3(
                    'Ratings',
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(width: 6),
                  AppTextView.body2(
                    '${row.ratingPercent}%',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppTextView.body3(
                'Ratings',
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 8),
              _RatingBadge(value: row.passCount, color: AppColors.lightGreen1),
              const SizedBox(width: 8),
              _RatingBadge(value: row.partialCount, color: AppColors.orange1),
              const SizedBox(width: 8),
              _RatingBadge(value: row.failCount, color: AppColors.orange2),
              if (_canOpenDetail) ...[
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onGo,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (row.remarks != null && row.remarks!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const AppTextView.body3(
              'Remarks',
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            AppTextView.body3(
              row.remarks!,
              color: AppColors.textPrimary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppTextView.body4(
        '$value',
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CoreValuesCard extends StatelessWidget {
  const _CoreValuesCard({
    required this.values,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<PerformanceReportCoreValue> values;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CheckInController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Expanded(
                    child: AppTextView.body2(
                      AppStrings.performanceReportCoreValuesTitle,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _ExpandChevronBadge(isExpanded: isExpanded),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : 0.0;
                  if (maxWidth <= 10) {
                    return const SizedBox.shrink();
                  }

                  final itemWidth = (maxWidth - 10) / 2;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List<Widget>.generate(values.length, (index) {
                      final value = values[index];
                      final visualSpec = controller
                          .resolvePerformanceReportCoreValueVisualSpec(value);

                      return SizedBox(
                        width: itemWidth,
                        child: _CoreValuePill(
                          coreValue: value,
                          visualSpec: visualSpec,
                          fillWidth: true,
                          onTap: () => showPerformanceReportCoreValueDialog(
                            context,
                            coreValue: value,
                            icon: visualSpec.icon,
                            accentColor: visualSpec.color,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _CoreValuePill extends StatelessWidget {
  const _CoreValuePill({
    required this.coreValue,
    required this.visualSpec,
    required this.onTap,
    this.fillWidth = false,
  });

  final PerformanceReportCoreValue coreValue;
  final PerformanceReportCoreValueVisualSpec visualSpec;
  final VoidCallback onTap;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: fillWidth ? double.infinity : null,
        constraints: fillWidth
            ? null
            : const BoxConstraints(minWidth: 148, maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visualSpec.color, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: visualSpec.color.withValues(alpha: 0.12),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visualSpec.color,
              ),
              child: Icon(
                visualSpec.icon,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextView.body1(
                coreValue.title,
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandChevronBadge extends StatelessWidget {
  const _ExpandChevronBadge({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.28),
          ),
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({
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
                  'For the quarter I commit to working on:',
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              //const _BotGlowButton(),
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
                      'Comments',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const AppTextView.body3(
                  'Share your goals, plans, and key focus areas for this quarter.',
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
                    hintText: 'Enter Comments',
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
                    '$currentLength/2000',
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
                      "Signature",
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const AppTextView.body3(
                  'Add the Employee and Facilitator signature to confirm this commitment.',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                _SignatureSection(
                  title: 'Employee Signature',
                  signatureUrl: employeeSignatureUrl,
                  signerName: employeeName,
                  signatureBytes: employeeSignatureBytes,
                  isReadOnly: isReadOnly,
                  onAddSignature: onAddEmployeeSignature,
                  onClearSignature: onClearEmployeeSignature,
                ),
                _SignatureSection(
                  title: 'Facilitator Signature',
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
                    'Certified at: ${_formatCertifiedAt(certifiedAt)}',
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
                  'No signature added yet',
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                const AppTextView.body3(
                  'Add signature to confirm',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 10),
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
                            ? 'Add Signature'
                            : 'Retake Signature',
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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceDark,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
  );
}

BoxDecoration _innerCardDecoration() {
  return BoxDecoration(
    // color: AppColors.surfaceDark2,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.18)),
  );
}
