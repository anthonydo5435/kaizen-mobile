import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/core/widgets/app_listing_search_bar.dart';
import 'package:sparrowkaizen/core/widgets/app_text_view.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/data/datasources/audit_remote_data_source.dart';
import 'package:sparrowkaizen/features/check_in/data/repositories/audit_repository_impl.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_profile.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_quarterly_audit_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../widgets/check_in_description_card.dart';

import 'View_all_team_members.dart';
import 'check_in_single_description.dart';

class CheckInDescriptionsListScreen extends StatelessWidget {
  const CheckInDescriptionsListScreen({
    super.key,
    required this.quarterlyAuditId,
    required this.date,
    required this.lastAuditDate,
    this.year,
    this.quarter,
    this.requireDescriptionSelection = false,
    this.isSelfAudit = false,
  });

  final String quarterlyAuditId;
  final String date;
  final String lastAuditDate;
  final int? year;
  final int? quarter;
  final bool requireDescriptionSelection;
  final bool isSelfAudit;

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
        ProxyProvider<AuditRepositoryImpl, GetQuarterlyAuditUseCase>(
          update: (_, repository, __) =>
              createGetQuarterlyAuditUseCase(repository),
        ),
        ChangeNotifierProvider<CheckInController>(
          create: (context) =>
              CheckInController(
                context.read<GetAuditOverviewUseCase>(),
                null,
                null,
                context.read<GetQuarterlyAuditUseCase>(),
                null,
                null,
                null,
                context.read<AuditRepositoryImpl>(),
              )..initializeSingleAuditDetails(
                quarterlyAuditId: quarterlyAuditId,
                date: date,
                year: year,
                quarter: quarter,
              ),
        ),
      ],
      child: _CheckInDescriptionsListView(
        key: ValueKey('$quarterlyAuditId|$date|$lastAuditDate|$year|$quarter'),
        quarterlyAuditId: quarterlyAuditId,
        date: date,
        lastAuditDate: lastAuditDate,
        year: year,
        quarter: quarter,
        requireDescriptionSelection: requireDescriptionSelection,
        isSelfAudit: isSelfAudit,
      ),
    );
  }
}

class _CheckInDescriptionsListView extends StatefulWidget {
  const _CheckInDescriptionsListView({
    super.key,
    required this.date,
    required this.lastAuditDate,
    required this.quarterlyAuditId,
    this.year,
    this.quarter,
    required this.requireDescriptionSelection,
    required this.isSelfAudit,
  });

  final String date;
  final String lastAuditDate;
  final String quarterlyAuditId;
  final int? year;
  final int? quarter;
  final bool requireDescriptionSelection;
  final bool isSelfAudit;

  @override
  State<_CheckInDescriptionsListView> createState() =>
      _CheckInDescriptionsListViewState();
}

class _CheckInDescriptionsListViewState
    extends State<_CheckInDescriptionsListView> {
  @override
  void didUpdateWidget(covariant _CheckInDescriptionsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didIdentityChange =
        oldWidget.lastAuditDate != widget.lastAuditDate ||
        oldWidget.date != widget.date ||
        oldWidget.quarterlyAuditId != widget.quarterlyAuditId ||
        oldWidget.year != widget.year ||
        oldWidget.quarter != widget.quarter ||
        oldWidget.requireDescriptionSelection !=
            widget.requireDescriptionSelection ||
        oldWidget.isSelfAudit != widget.isSelfAudit;
    if (!didIdentityChange) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<CheckInController>().initializeSingleAuditDetails(
        quarterlyAuditId: widget.quarterlyAuditId,
        date: widget.date,
        year: widget.year,
        quarter: widget.quarter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppManager>();
    final controller = context.watch<CheckInController>();
    final state = controller.state;
    final audit = state.quarterlyAudit;
    final members = state.mainList?.results ?? const <AuditProfile>[];

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 18),
            if (state.isLoading)
              Expanded(child: Center(child: FastCircularProgressIndicator()))
            else if (audit == null)
              const Expanded(
                child: Center(
                  child: AppTextView.body(
                    AppStrings.noCheckInDetailFound,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  child: Column(
                    children: [
                      _buildAuditProfileCard(audit),
                      if (state.isOwner && members.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildTeamMembersSection(context, audit, members),
                      ],
                      const SizedBox(height: 18),
                      _buildDescriptionsSection(context, audit, controller),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMembersSection(
    BuildContext context,
    QuarterlyAudit audit,
    List<AuditProfile> members,
  ) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    final previewMembers = members.take(4).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppTextView.body1(
                AppStrings.auditTeamMembersTab,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => _openViewAllTeamMembers(context, audit, members),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const AppTextView.body2(
                AppStrings.auditSeeMore,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previewMembers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final member = previewMembers[index];
              return _buildTeamMemberPreviewCard(
                context,
                audit,
                member,
                isSelected: context
                    .read<CheckInController>()
                    .isCurrentAuditMember(audit, member),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMemberPreviewCard(
    BuildContext context,
    QuarterlyAudit audit,
    AuditProfile member, {
    required bool isSelected,
  }) {
    final profileName = member.name.trim().isEmpty
        ? AppStrings.noProfile
        : member.name;

    return GestureDetector(
      onTap: isSelected ? null : () => _openSelectedTeamMember(context, member),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 120,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondaryColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(38, member.imageUrl),
            const SizedBox(height: 8),
            AppTextView.body3(
              member.roleTitle,
              color: AppColors.secondaryColor,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              maxLines: 1,
              fontSize: 10,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            AppTextView.body2(
              profileName,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              textAlign: TextAlign.center,
              maxLines: 1,
              fontSize: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openViewAllTeamMembers(
    BuildContext context,
    QuarterlyAudit audit,
    List<AuditProfile> members,
  ) async {
    final auditController = context.read<CheckInController>();
    final selectedMember = await showDialog<AuditProfile>(
      context: context,
      useSafeArea: false,
      builder: (_) => ChangeNotifierProvider<CheckInController>.value(
        value: auditController,
        child: ViewAllTeamMembers(members: members),
      ),
    );

    if (!context.mounted ||
        selectedMember == null ||
        auditController.isCurrentAuditMember(audit, selectedMember)) {
      return;
    }

    await _openSelectedTeamMember(context, selectedMember);
  }

  Future<void> _openSelectedTeamMember(
    BuildContext context,
    AuditProfile member,
  ) {
    return AppRouter.pushNamed<void>(
      context,
      AppRouter.checkInDetails,
      arguments: CheckInDetailsRouteArgs(
        profileJobId: member.profileJob,
        year: widget.year,
        quarter: widget.quarter,
        selectedProfileUuid: member.profileUuid,
      ),
    );
  }

  Future<void> _openDescriptionDetails(
    BuildContext context,
    QuarterlyAudit audit,
    List<QuarterlyAuditDescription> descriptions,
    int initialDescriptionIndex,
    Map<String, int> initialRatingCounts,
  ) async {
    final auditController = context.read<CheckInController>();
    final descriptionPages = List<QuarterlyAuditDescription>.unmodifiable(
      descriptions,
    );
    auditController.selectQuarterlyAuditDescription(
      descriptionPages[initialDescriptionIndex].uuid,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CheckInController>.value(
          value: auditController,
          child: SingleDescriptionDetails(
            audit: audit,
            descriptions: descriptionPages,
            initialDescriptionIndex: initialDescriptionIndex,
            date: widget.date,
            isOwner: auditController.state.isOwner,
            isViewOnly: audit.isMismatch,
            isSelfAudit: widget.isSelfAudit,
            initialRatingCounts: initialRatingCounts,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                child: SvgPicture.asset(
                  '${AppStrings.imagePath}back.svg',
                  height: 24,
                  width: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
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

  Widget _buildAuditProfileCard(QuarterlyAudit audit) {
    final lastAuditDate = widget.date;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextView.body1(
                  audit.jobTitle,
                  color: AppColors.secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                AppTextView.body(
                  audit.profileName.trim().isEmpty
                      ? AppStrings.noProfile
                      : audit.profileName,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${AppStrings.lastAudit}: ',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(
                        text: CustomFunctions.formatDate(lastAuditDate),
                        style: TextStyle(
                          color: AppColors.secondaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildAvatar(82, audit.profileImage),
        ],
      ),
    );
  }

  Widget _buildDescriptionsSection(
    BuildContext context,
    QuarterlyAudit audit,
    CheckInController controller,
  ) {
    final filtersState = controller.descriptionFilters;
    final filteredDescriptions = controller.filteredDescriptions(
      audit,
      date: widget.date,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextView.body1(
                filtersState.isFilterOptionsVisible
                    ? AppStrings.auditDescriptionFilterOptions
                    : AppStrings.auditDescriptionsTitle,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: controller.toggleDescriptionFilterOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(
                  filtersState.isFilterOptionsVisible ? 8 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  filtersState.isFilterOptionsVisible
                      ? Icons.close_rounded
                      : Icons.filter_alt_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppListingSearchBar(
          controller: controller.descriptionSearchController,
          hintText: AppStrings.auditSearchDescriptionsHint,
          onChanged: controller.updateDescriptionSearchQuery,
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: child,
                  ),
                ),
              );
            },
            layoutBuilder: (currentChild, previousChildren) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: filtersState.isFilterOptionsVisible
                ? _buildFilterOptionsView(audit, controller)
                : filteredDescriptions.isEmpty
                ? Container(
                    key: const ValueKey('empty-filter-results'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppTextView.body2(
                      controller.descriptionSearchQuery.isEmpty
                          ? AppStrings.auditNoMatchingDescriptions
                          : AppStrings.auditNoMatchingDescriptionSearch,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('description-list'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDescriptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final description = filteredDescriptions[index];
                      return CheckInDescriptionCard(
                        key: ValueKey('${audit.uuid}:${description.uuid}'),
                        audit: audit,
                        description: description,
                        date: widget.date,
                        isOwner: context
                            .read<CheckInController>()
                            .state
                            .isOwner,
                        isSelfAudit: widget.isSelfAudit,
                        onOpenDetails: (initialRatingCounts) =>
                            _openDescriptionDetails(
                              context,
                              audit,
                              filteredDescriptions,
                              index,
                              initialRatingCounts,
                            ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterOptionsView(
    QuarterlyAudit audit,
    CheckInController controller,
  ) {
    final filtersState = controller.descriptionFilters;
    final categories = controller.descriptionCategoryOptions(
      audit,
      date: widget.date,
    );
    final milestoneOptions = controller.descriptionMilestoneOptions(
      audit,
      date: widget.date,
    );
    final auditTimingOptions = controller.descriptionAuditTimingOptions(
      audit,
      date: widget.date,
    );
    final auditTypeOptions = controller.descriptionAuditTypeOptions(
      audit,
      date: widget.date,
    );

    return Container(
      key: const ValueKey('filter-options'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuditedOnlyRow(controller),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: AppStrings.auditDescriptionCategories,
            options: categories,
            selectedValues: filtersState.selectedCategories,
            onTap: controller.toggleDescriptionCategory,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: AppStrings.auditDescriptionMilestones,
            options: milestoneOptions,
            selectedValues: filtersState.selectedMilestones,
            onTap: controller.toggleDescriptionMilestone,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: AppStrings.auditDescriptionTiming,
            options: auditTimingOptions,
            selectedValues: filtersState.selectedAuditTimings,
            onTap: controller.toggleDescriptionAuditTiming,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: AppStrings.auditDescriptionType,
            options: auditTypeOptions,
            selectedValues: filtersState.selectedAuditTypes,
            onTap: controller.toggleDescriptionAuditType,
          ),
          if (filtersState.hasActiveFilters) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.clearDescriptionFilters,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const AppTextView.body2(
                  AppStrings.auditDescriptionClearFilters,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditedOnlyRow(CheckInController controller) {
    final filtersState = controller.descriptionFilters;
    return Row(
      children: [
        const Expanded(
          child: AppTextView.body2(
            AppStrings.auditDescriptionShowAuditedOnly,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: controller.toggleShowAuditedDescriptionsOnly,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: filtersState.showAuditedOnly
                  ? AppColors.secondaryColor
                  : AppColors.surfaceDark2,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: filtersState.showAuditedOnly
                    ? AppColors.secondaryColor
                    : AppColors.fieldBorder.withValues(alpha: 0.5),
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              alignment: filtersState.showAuditedOnly
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterGroup({
    required String label,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body2(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selectedValues.contains(option);
              return InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () => onTap(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.orange2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.orange2
                          : AppColors.textPrimary,
                    ),
                  ),
                  child: Center(
                    child: AppTextView.body3(
                      option,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(double size, String? imageUrl) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: resolvedImageUrl == null
              ? const AssetImage('${AppStrings.imagePath}dumy_pic.png')
              : NetworkImage(resolvedImageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
