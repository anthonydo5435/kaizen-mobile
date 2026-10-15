import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_select_team_member_filter_sheet.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_evaluation_chart_widget.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_details.dart';
import '../../domain/usecases/get_audit_details_usecase.dart';
import '../../domain/usecases/get_audit_evaluation_chart_usecase.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../../domain/usecases/get_quarterly_audit_usecase.dart';
import '../providers/check_in_controller.dart';
import '../widgets/upgrade_plan_dialog.dart';

class CheckInDetailsScreen extends StatelessWidget {
  const CheckInDetailsScreen({
    super.key,
    required this.profileJobId,
    this.year,
    this.quarter,
    this.selectedProfileUuid,
  });

  final String profileJobId;
  final int? year;
  final int? quarter;
  final String? selectedProfileUuid;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(create: (_) => createAuditRemoteDataSource()),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) => createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) => createGetAuditOverviewUseCase(repository),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditDetailsUseCase>(
          update: (_, repository, __) => createGetAuditDetailsUseCase(repository),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditEvaluationChartUseCase>(
          update: (_, repository, __) => createGetAuditEvaluationChartUseCase(repository),
        ),
        ProxyProvider<AuditRepositoryImpl, GetQuarterlyAuditUseCase>(
          update: (_, repository, __) => createGetQuarterlyAuditUseCase(repository),
        ),
        ChangeNotifierProvider<CheckInController>(
          create: (context) =>
              CheckInController(
                context.read<GetAuditOverviewUseCase>(),
                context.read<GetAuditDetailsUseCase>(),
                context.read<GetAuditEvaluationChartUseCase>(),
                context.read<GetQuarterlyAuditUseCase>(),
                null,
                null,
                null,
                context.read<AuditRepositoryImpl>(),
              )..initializeDetails(
                profileJobId,
                year: year,
                quarter: quarter,
                profileUuid: selectedProfileUuid,
              ),
        ),
      ],
      child: _CheckInDetailsScreenView(profileJobId: profileJobId, year: year, quarter: quarter),
    );
  }
}

class _CheckInDetailsScreenView extends StatelessWidget {
  const _CheckInDetailsScreenView({required this.profileJobId, this.year, this.quarter});
  final String profileJobId;
  final int? year;
  final int? quarter;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CheckInController>();
    final state = controller.state;
    final details = state.details;
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    _buildTitle(context),
                    const SizedBox(height: 18),
                    if (state.isLoading)
                      Expanded(child: Center(child: FastCircularProgressIndicator()))
                    else if (details == null)
                      const Expanded(
                        child: Center(
                          child: AppTextView.body(
                            AppStrings.noCheckInDetailFound,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else ...[
                      _buildHeaderSection(details),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark3,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.only(left: 14, right: 14, top: 12),
                          child: Column(
                            children: [
                              _buildAuditListHeader(context, controller, details),
                              const SizedBox(height: 6),

                              controller.showGraph
                                  ? Expanded(
                                      child: CheckInEvaluationChartWidget(
                                        charts: state.evaluationCharts,
                                        isLoading: state.isEvaluationChartLoading,
                                      ),
                                    )
                                  : Expanded(child: _buildAuditListView(controller, details)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!state.isLoading && !state.isSelfAudit)
              _buildNewAuditButton(
                context,
                details,
                isAuditActionLoading: state.isAuditActionLoading,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: SvgPicture.asset(
                '${AppStrings.imagePath}back.svg',
                height: 24,
                width: 24,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          AppTextView.body(
            AppStrings.checkInTitle,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(AuditDetails details) {
    final profileImage = CustomFunctions.resolveImageUrl(details.profileImage);
    final profileName = details.profileName.trim().isEmpty
        ? AppStrings.noProfile
        : details.profileName;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Card
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                      image: DecorationImage(
                        image: profileImage == null
                            ? const AssetImage('lib/assets/images/dumy_pic.png')
                            : NetworkImage(profileImage),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppTextView.body1(
                    details.jobTitle,
                    color: AppColors.secondaryColor,
                    fontSize: 14,
                  ),
                  AppTextView.body1(
                    profileName,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${AppStrings.checkInLastCheckIn}: ',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text: details.lastAuditDate,
                          style: const TextStyle(
                            color: AppColors.secondaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (details.profiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildProfilesList(details.profiles),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Stats Column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildStatBox(
                  details.overallScore.toStringAsFixed(1),
                  AppStrings.runningOverallPerformance,
                  AppColors.green1,
                ),
                const SizedBox(height: 12),
                _buildStatBox(
                  '${details.confidenceLevel.round()}%',
                  AppStrings.confidenceLevel,
                  AppColors.orange1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey2.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTextView.body1(value, fontSize: 24, color: color, fontWeight: FontWeight.w600),
            AppTextView.body2(
              label,
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditListHeader(
    BuildContext context,
    CheckInController controller,
    AuditDetails details,
  ) {
    final selectedProfileName = _resolveSelectedProfileName(controller, details);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedProfileName != null) ...[
          _SelectedTeamMemberTag(
            name: selectedProfileName,
            onClear: () => _clearSelectedTeamMember(context, controller, details),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 5),
                AppTextView.body1(
                  AppStrings.checkInEvaluationChart,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),

                // const SizedBox(height: 4),
                // GestureDetector(
                //   onTap: () => _openAuditReport(context, details),
                //   child: const Text(
                //     'Check-in Report',
                //     style: TextStyle(
                //       color: AppColors.textPrimary,
                //       fontSize: 12,
                //       fontWeight: FontWeight.w500,
                //       decoration: TextDecoration.underline,
                //       decorationColor: AppColors.textPrimary,
                //     ),
                //   ),
                // ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (controller.showGraph) {
                      controller.setShowGraph(false);
                    } else {
                      controller.showEvaluationChart(
                        details.profileJob,
                        profileUuid: _resolveActiveProfileUuid(controller, details),
                      );
                    }
                  },
                  child: _buildGraphIcon(controller.showGraph ? 'chart.svg' : 'list.svg'),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    openCheckInTeamMemberFilterSheet(context, details);
                  },
                  child: _buildFilterIcon(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGraphIcon(String iconName) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      width: 34,
      height: 34,
      child: SvgPicture.asset('${AppStrings.imagePath}$iconName'),
    );
  }

  Widget _buildFilterIcon() {
    return Container(
      width: 34,
      height: 34,
      padding: EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SvgPicture.asset('${AppStrings.imagePath}filter.svg'),
    );
  }

  Widget _buildAuditListView(CheckInController controller, AuditDetails details) {
    final isSelfAudit = controller.state.isSelfAudit;
    final isPastLastAuditDate = CustomFunctions.isDateBeforeToday(details.lastAuditDate);
    final visibleAudits = isPastLastAuditDate
        ? details.audits.where((audit) => audit.totalRatings > 0).toList(growable: false)
        : details.audits;

    if (visibleAudits.isEmpty) {
      return const Center(
        child: AppTextView.body(
          AppStrings.seatProfileCheckInNoCheckIn,
          color: AppColors.textSecondary,
        ),
      );
    }

    return ListView.separated(
      itemCount: visibleAudits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final audit = visibleAudits[index];
        final actionLabel = CustomFunctions.isAuditWithinContinueWindow(audit.date)
            ? AppStrings.continueAction
            : AppStrings.view;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openSingleAuditDetails(context, details, audit.date),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey2.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body1(
                      CustomFunctions.formatDate(audit.date),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppTextView.body2('Ratings: ', color: Colors.grey),
                        _buildRatingBadge(value: audit.great, color: AppColors.green1),
                        _buildRatingBadge(value: audit.almostThere, color: AppColors.orange1),
                        _buildRatingBadge(value: audit.needsImprovement, color: AppColors.red1),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    _openSingleAuditDetails(context, details, audit.date);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.only(left: 12, right: 12, top: 7, bottom: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextView.body2(
                          isSelfAudit ? AppStrings.view : actionLabel,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.north_east, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingBadge({required int value, required Color color}) {
    return Container(
      alignment: Alignment.center,
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: AppTextView.body2(
        '$value',
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _openSingleAuditDetails(
    BuildContext context,
    AuditDetails details,
    String date, {
    bool requireDescriptionSelection = false,
  }) async {
    await AppRouter.pushNamed(
      context,
      AppRouter.checkInDescriptionsList,
      arguments: CheckInDescriptionsListRouteArgs(
        quarterlyAuditId: details.uuid,
        date: date,
        lastAuditDate: details.lastAuditDate,
        year: year,
        quarter: quarter,
        requireDescriptionSelection: requireDescriptionSelection,
        isSelfAudit: context.read<CheckInController>().state.isSelfAudit,
      ),
    );

    if (!context.mounted) {
      return;
    }

    final activeProfileUuid = _resolveActiveProfileUuid(context.read<CheckInController>(), details);

    await _refreshDetailsAfterAuditReturn(
      context,
      details.profileJob,
      profileUuid: activeProfileUuid,
    );
  }

  Widget _buildNewAuditButton(
    BuildContext context,
    AuditDetails? details, {
    required bool isAuditActionLoading,
  }) {
    final hasDetails = details != null;
    final shouldStartNewAudit = hasDetails && _shouldStartNewAuditForBottomAction(details);
    if (shouldStartNewAudit && !context.read<CheckInController>().isSelectedAuditPeriodCurrent) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 20,
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: hasDetails
                ? AppButton(
                    text: shouldStartNewAudit ? AppStrings.newCheckIn : AppStrings.continueCheckIn,
                    onPressed: isAuditActionLoading
                        ? null
                        : () => _handleAuditAction(context, details, shouldStartNewAudit),
                    isLoading: isAuditActionLoading,
                    minimumHeight: 40,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuditAction(
    BuildContext context,
    AuditDetails details,
    bool shouldStartNewAudit,
  ) async {
    final controller = context.read<CheckInController>();
    if (shouldStartNewAudit && !controller.isSelectedAuditPeriodCurrent) {
      return;
    }

    if (context.read<AppManager>().showBillingBanner) {
      await showDialog<void>(
        context: context,
        builder: (_) => const UpgradePlanDialog(),
        barrierDismissible: false,
      );
      return;
    }

    final todayDate = CustomFunctions.apiDateString();
    if (controller.state.isAuditActionLoading || controller.state.isSelfAudit) {
      return;
    }

    controller.setAuditActionLoading(true);

    try {
      controller.setAuditActionLoading(false);

      await _openSingleAuditDetails(
        context,
        details,
        todayDate,
        requireDescriptionSelection: shouldStartNewAudit,
      );
    } finally {
      controller.setAuditActionLoading(false);
    }
  }

  Future<void> _refreshDetailsAfterAuditReturn(
    BuildContext context,
    String profileJobId, {
    String? profileUuid,
  }) async {
    await _refreshControllerDetailsAfterAuditReturn(
      context.read<CheckInController>(),
      profileJobId,
      profileUuid: profileUuid,
    );
  }

  Future<void> _refreshControllerDetailsAfterAuditReturn(
    CheckInController controller,
    String profileJobId, {
    String? profileUuid,
    bool clearEvaluationCharts = false,
  }) async {
    await controller.initializeDetails(
      profileJobId,
      year: year,
      quarter: quarter,
      clearEvaluationCharts: clearEvaluationCharts || !controller.showGraph,
      profileUuid: profileUuid,
    );

    if (controller.showGraph) {
      await controller.refreshEvaluationChart(profileJobId, profileUuid: profileUuid);
    }
  }

  Widget _buildProfilesList(List<AuditDetailsProfile> profiles) {
    const avatarSize = 26.0;
    const overlapOffset = 18.0;
    final visibleProfiles = profiles.take(5).toList(growable: false);
    final stackWidth = visibleProfiles.isEmpty
        ? 0.0
        : avatarSize + ((visibleProfiles.length - 1) * overlapOffset);

    return SizedBox(
      height: 34,
      width: stackWidth,
      child: Stack(
        children: [
          for (var index = 0; index < visibleProfiles.length; index++)
            Positioned(
              left: index * overlapOffset,
              child: _DetailProfileAvatar(imageUrl: visibleProfiles[index].image),
            ),
        ],
      ),
    );
  }

  String? _resolveActiveProfileUuid(CheckInController controller, AuditDetails details) {
    final selectedProfileUuid = controller.selectedAuditDetailsProfileUuid;
    if (selectedProfileUuid != null) {
      return selectedProfileUuid;
    }

    final allocatedProfileUuid = details.profileUuid.trim();
    return allocatedProfileUuid.isEmpty ? null : allocatedProfileUuid;
  }

  bool _shouldStartNewAuditForBottomAction(AuditDetails details) {
    return !CustomFunctions.isSameDate(details.lastAuditDate, CustomFunctions.apiDateString());
  }

  String? _resolveSelectedProfileName(CheckInController controller, AuditDetails details) {
    final selectedProfileUuid = _resolveActiveProfileUuid(controller, details);
    if (selectedProfileUuid == null || selectedProfileUuid == details.profileUuid.trim()) {
      return null;
    }

    for (final profile in details.profiles) {
      if (profile.uuid.trim() != selectedProfileUuid) {
        continue;
      }

      final resolvedName = profile.name.trim().isNotEmpty
          ? profile.name.trim()
          : profile.email.trim();
      return resolvedName.isEmpty ? null : resolvedName;
    }

    return null;
  }

  Future<void> _clearSelectedTeamMember(
    BuildContext context,
    CheckInController controller,
    AuditDetails details,
  ) async {
    await _refreshControllerDetailsAfterAuditReturn(
      controller,
      details.profileJob,
      clearEvaluationCharts: true,
    );
  }

  List<CheckInTeamMemberFilterOption> _buildTeamMemberFilterOptions(AuditDetails details) {
    final optionsById = <String, CheckInTeamMemberFilterOption>{};

    void addOption({
      required String profileUuid,
      required String name,
      required String email,
      String? imageUrl,
      required bool onboarded,
    }) {
      final normalizedProfileUuid = profileUuid.trim();
      final normalizedEmail = email.trim();
      final normalizedName = name.trim().isNotEmpty ? name.trim() : normalizedEmail;
      final selectionId = normalizedProfileUuid.isNotEmpty
          ? normalizedProfileUuid
          : normalizedEmail.toLowerCase().isNotEmpty
          ? normalizedEmail.toLowerCase()
          : normalizedName.toLowerCase();

      if (selectionId.isEmpty || normalizedName.isEmpty || optionsById.containsKey(selectionId)) {
        return;
      }

      optionsById[selectionId] = CheckInTeamMemberFilterOption(
        selectionId: selectionId,
        name: normalizedName,
        email: normalizedEmail,
        imageUrl: imageUrl,
        profileUuid: normalizedProfileUuid.isEmpty ? null : normalizedProfileUuid,
        onboarded: onboarded,
      );
    }

    addOption(
      profileUuid: details.profileUuid,
      name: details.profileName,
      email: details.profileEmail,
      imageUrl: details.profileImage,
      onboarded: details.profileOnboarded,
    );

    for (final profile in details.profiles) {
      addOption(
        profileUuid: profile.uuid,
        name: profile.name,
        email: profile.email,
        imageUrl: profile.image,
        onboarded: profile.onboarded,
      );
    }

    return optionsById.values.toList(growable: false);
  }

  String? _resolveInitialTeamMemberSelectionId(
    CheckInController controller,
    List<CheckInTeamMemberFilterOption> options,
    AuditDetails details,
  ) {
    final currentProfileUuid = _resolveActiveProfileUuid(controller, details);
    if (currentProfileUuid != null && currentProfileUuid.isNotEmpty) {
      for (final option in options) {
        if (option.profileUuid == currentProfileUuid) {
          return option.selectionId;
        }
      }
    }

    final currentEmail = details.profileEmail.trim().toLowerCase();
    if (currentEmail.isNotEmpty) {
      for (final option in options) {
        if (option.email.trim().toLowerCase() == currentEmail) {
          return option.selectionId;
        }
      }
    }

    return null;
  }

  Future<void> openCheckInTeamMemberFilterSheet(BuildContext context, AuditDetails details) async {
    final controller = context.read<CheckInController>();
    final options = _buildTeamMemberFilterOptions(details);
    if (options.isEmpty) {
      return;
    }

    final selectedOption = await showModalBottomSheet<CheckInTeamMemberFilterOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CheckInTeamMemberFilterSheet(
          options: options,
          initialSelectionId: _resolveInitialTeamMemberSelectionId(controller, options, details),
        ),
      ),
    );

    if (!context.mounted || selectedOption == null) {
      return;
    }

    final selectedProfileUuid = selectedOption.profileUuid?.trim() ?? '';
    final activeProfileUuid = _resolveActiveProfileUuid(controller, details) ?? '';
    if (selectedProfileUuid.isEmpty || selectedProfileUuid == activeProfileUuid) {
      return;
    }

    await _refreshControllerDetailsAfterAuditReturn(
      controller,
      details.profileJob,
      profileUuid: selectedProfileUuid,
      clearEvaluationCharts: true,
    );
  }
}

class _DetailProfileAvatar extends StatelessWidget {
  const _DetailProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1.4),
        image: DecorationImage(
          image: resolvedImageUrl == null
              ? const AssetImage('lib/assets/images/dumy_pic.png')
              : NetworkImage(resolvedImageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _SelectedTeamMemberTag extends StatelessWidget {
  const _SelectedTeamMemberTag({required this.name, required this.onClear});

  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.secondaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AppTextView.body2(
                name,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.secondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
