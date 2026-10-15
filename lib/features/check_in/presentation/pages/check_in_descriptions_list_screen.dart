import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/core/widgets/app_listing_search_bar.dart';
import 'package:sparrowkaizen/core/widgets/app_text_view.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/data/datasources/audit_remote_data_source.dart';
import 'package:sparrowkaizen/features/check_in/data/repositories/audit_repository_impl.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_profile.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_quarterly_audit_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/description_media_comment_bottom_sheet.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/description_text_comment_dialog.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import 'View_all_team_members.dart';
import 'check_in_single_description.dart';

bool _canEditSingleDescriptionAudit({
  required bool isViewOnly,
  required bool isOwner,
  required String date,
}) {
  return !isViewOnly && isOwner && CustomFunctions.isAuditWithinContinueWindow(date);
}

bool _canCommentOnSingleDescriptionAudit({required bool isViewOnly, required String date}) {
  return !isViewOnly && CustomFunctions.isAuditWithinContinueWindow(date);
}

enum _PassBlockState { great, almostThere, needsImprovement, defaultValue }

class _PassSelectionViewState {
  const _PassSelectionViewState({required this.blocks, required this.hasLocalChanges});

  final List<_PassBlockState> blocks;
  final bool hasLocalChanges;

  _PassSelectionViewState copyWith({List<_PassBlockState>? blocks, bool? hasLocalChanges}) {
    return _PassSelectionViewState(
      blocks: blocks ?? this.blocks,
      hasLocalChanges: hasLocalChanges ?? this.hasLocalChanges,
    );
  }
}

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
        Provider<AuditRemoteDataSource>(create: (_) => createAuditRemoteDataSource()),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) => createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) => createGetAuditOverviewUseCase(repository),
        ),
        ProxyProvider<AuditRepositoryImpl, GetQuarterlyAuditUseCase>(
          update: (_, repository, __) => createGetQuarterlyAuditUseCase(repository),
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
  State<_CheckInDescriptionsListView> createState() => _CheckInDescriptionsListViewState();
}

class _CheckInDescriptionsListViewState extends State<_CheckInDescriptionsListView> {
  late final ValueNotifier<_CheckInDescriptionsListFiltersState> _filtersNotifier;

  @override
  void initState() {
    super.initState();
    _filtersNotifier = ValueNotifier<_CheckInDescriptionsListFiltersState>(
      const _CheckInDescriptionsListFiltersState(),
    );
  }

  @override
  void didUpdateWidget(covariant _CheckInDescriptionsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didIdentityChange =
        oldWidget.lastAuditDate != widget.lastAuditDate ||
        oldWidget.date != widget.date ||
        oldWidget.quarterlyAuditId != widget.quarterlyAuditId ||
        oldWidget.year != widget.year ||
        oldWidget.quarter != widget.quarter ||
        oldWidget.requireDescriptionSelection != widget.requireDescriptionSelection ||
        oldWidget.isSelfAudit != widget.isSelfAudit;
    if (!didIdentityChange) {
      return;
    }

    _clearFiltersSilently();
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
  void dispose() {
    _filtersNotifier.dispose();
    super.dispose();
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
            Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 0), child: _buildHeader(context)),
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
                      ValueListenableBuilder<_CheckInDescriptionsListFiltersState>(
                        valueListenable: _filtersNotifier,
                        builder: (context, filtersState, _) {
                          return _buildDescriptionsSection(context, audit, filtersState);
                        },
                      ),
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
                isSelected: _isCurrentMember(audit, member),
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
    final profileName = member.name.trim().isEmpty ? AppStrings.noProfile : member.name;

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

    if (!context.mounted || selectedMember == null || _isCurrentMember(audit, selectedMember)) {
      return;
    }

    await _openSelectedTeamMember(context, selectedMember);
  }

  Future<void> _openSelectedTeamMember(BuildContext context, AuditProfile member) {
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

  bool _isCurrentMember(QuarterlyAudit audit, AuditProfile member) {
    final memberProfileUuid = member.profileUuid.trim();
    final memberProfileJob = member.profileJob.trim();

    return memberProfileUuid.isNotEmpty && memberProfileUuid == audit.profileUuid.trim() ||
        memberProfileJob.isNotEmpty && memberProfileJob == audit.profileJob.trim();
  }

  Future<void> _openDescriptionDetails(
    BuildContext context,
    QuarterlyAudit audit,
    List<QuarterlyAuditDescription> descriptions,
    int initialDescriptionIndex,
    Map<String, int> initialRatingCounts,
  ) async {
    final auditController = context.read<CheckInController>();
    final descriptionPages = List<QuarterlyAuditDescription>.unmodifiable(descriptions);
    auditController.selectQuarterlyAuditDescription(descriptionPages[initialDescriptionIndex].uuid);

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
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                  audit.profileName.trim().isEmpty ? AppStrings.noProfile : audit.profileName,
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
                          color: AppColors.textSecondary.withValues(alpha: 0.78),
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
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final controller = context.read<CheckInController>();
    final filteredDescriptions = controller.searchDescriptions(
      _filteredDescriptions(audit, filtersState),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextView.body1(
                filtersState.isFilterOptionsVisible ? 'Filter Options' : 'Descriptions',
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggleFilterOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(filtersState.isFilterOptionsVisible ? 8 : 8),
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
                  axisAlignment: -1,
                  child: SlideTransition(position: slideAnimation, child: child),
                ),
              );
            },
            layoutBuilder: (currentChild, previousChildren) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [...previousChildren, if (currentChild != null) currentChild],
              );
            },
            child: filtersState.isFilterOptionsVisible
                ? _buildFilterOptionsView(audit, filtersState)
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
                      return _CheckInDescriptionCard(
                        key: ValueKey('${audit.uuid}:${description.uuid}'),
                        audit: audit,
                        description: description,
                        date: widget.date,
                        isOwner: context.read<CheckInController>().state.isOwner,
                        isSelfAudit: widget.isSelfAudit,
                        onOpenDetails: (initialRatingCounts) => _openDescriptionDetails(
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
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final categories = _categoryOptions(audit, filtersState);
    final milestoneOptions = _milestoneOptions(audit, filtersState);
    final auditTimingOptions = _auditTimingOptions(audit, filtersState);
    final auditTypeOptions = _auditTypeOptions(audit, filtersState);

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
          _buildAuditedOnlyRow(filtersState),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: 'Categories',
            options: categories,
            selectedValues: filtersState.selectedCategories,
            onTap: _toggleCategory,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: 'Milestons',
            options: milestoneOptions,
            selectedValues: filtersState.selectedMilestones,
            onTap: _toggleMilestone,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: 'Audit Timing',
            options: auditTimingOptions,
            selectedValues: filtersState.selectedAuditTimings,
            onTap: _toggleAuditTiming,
          ),
          const SizedBox(height: 16),
          _buildFilterGroup(
            label: 'Audit Type',
            options: auditTypeOptions,
            selectedValues: filtersState.selectedAuditTypes,
            onTap: _toggleAuditType,
          ),
          if (_hasActiveFilters(filtersState)) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const AppTextView.body2(
                  'Clear All',
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

  Widget _buildAuditedOnlyRow(_CheckInDescriptionsListFiltersState filtersState) {
    return Row(
      children: [
        const Expanded(
          child: AppTextView.body2(
            'Show Audited Only',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: _toggleShowAuditedOnly,
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
        AppTextView.body2(label, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.orange2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected ? AppColors.orange2 : AppColors.textPrimary,
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

  List<QuarterlyAuditDescription> _filteredDescriptions(
    QuarterlyAudit audit,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    return audit.descriptions
        .where((description) {
          if (!_isDescriptionEligibleForDisplay(audit, description, filtersState)) {
            return false;
          }

          final categoryTitle = CustomFunctions.resolveAuditCategoryOption(
            audit: audit,
            description: description,
          );
          final milestone = CustomFunctions.normalizeAuditMilestone(description.milestoneDay);
          final auditTiming = CustomFunctions.resolveAuditTiming(description);
          final auditType = CustomFunctions.normalizeAuditType(description.auditFactorType);

          final matchesCategory =
              filtersState.selectedCategories.isEmpty ||
              filtersState.selectedCategories.contains(categoryTitle);
          final matchesMilestone =
              filtersState.selectedMilestones.isEmpty ||
              filtersState.selectedMilestones.contains(milestone);
          final matchesAuditTiming =
              filtersState.selectedAuditTimings.isEmpty ||
              filtersState.selectedAuditTimings.contains(auditTiming);
          final matchesAuditType =
              filtersState.selectedAuditTypes.isEmpty ||
              filtersState.selectedAuditTypes.contains(auditType);

          return matchesCategory && matchesMilestone && matchesAuditTiming && matchesAuditType;
        })
        .toList(growable: false);
  }

  bool _isDescriptionAudited(QuarterlyAuditDescription description) {
    return description.hasAudit || description.totalRatings > 0;
  }

  bool _isDescriptionEligibleForDisplay(
    QuarterlyAudit audit,
    QuarterlyAuditDescription description,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    if (!_isDescriptionEligibleForFilterOptions(audit, description, filtersState)) {
      return false;
    }

    final isAudited = _isDescriptionAudited(description);
    if (audit.isMismatch && !isAudited) {
      return false;
    }

    if (filtersState.showAuditedOnly && !isAudited) {
      return false;
    }

    return true;
  }

  bool _isDescriptionEligibleForFilterOptions(
    QuarterlyAudit audit,
    QuarterlyAuditDescription description,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final isAudited = _isDescriptionAudited(description);
    final isSelectedAuditDateBeforeToday = CustomFunctions.isDateBeforeToday(widget.date);
    final shouldIncludeUnauditedContinueDescriptions = _shouldIncludeUnauditedContinueDescriptions(
      audit,
    );

    if (audit.isMismatch && !isAudited) {
      return false;
    }

    if (isSelectedAuditDateBeforeToday &&
        !isAudited &&
        !shouldIncludeUnauditedContinueDescriptions) {
      return false;
    }

    return true;
  }

  bool _shouldIncludeUnauditedContinueDescriptions(QuarterlyAudit audit) {
    return !audit.isMismatch && CustomFunctions.isAuditWithinContinueWindow(widget.date);
  }

  List<String> _categoryOptions(
    QuarterlyAudit audit,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final options =
        audit.descriptions
            .where(
              (description) =>
                  _isDescriptionEligibleForFilterOptions(audit, description, filtersState),
            )
            .map(
              (description) => CustomFunctions.resolveAuditCategoryOption(
                audit: audit,
                description: description,
              ),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return options;
  }

  List<String> _milestoneOptions(
    QuarterlyAudit audit,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final options =
        audit.descriptions
            .where(
              (description) =>
                  _isDescriptionEligibleForFilterOptions(audit, description, filtersState),
            )
            .map((description) => CustomFunctions.normalizeAuditMilestone(description.milestoneDay))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return options;
  }

  List<String> _auditTimingOptions(
    QuarterlyAudit audit,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final preferredOrder = AppStrings.auditTimingOptions;
    final availableOptions = audit.descriptions
        .where(
          (description) => _isDescriptionEligibleForFilterOptions(audit, description, filtersState),
        )
        .map(CustomFunctions.resolveAuditTiming)
        .where((value) => value.isNotEmpty)
        .toSet();

    return preferredOrder.where(availableOptions.contains).toList(growable: false);
  }

  List<String> _auditTypeOptions(
    QuarterlyAudit audit,
    _CheckInDescriptionsListFiltersState filtersState,
  ) {
    final preferredOrder = AppStrings.auditTypeOptions;
    final availableOptions = audit.descriptions
        .where(
          (description) => _isDescriptionEligibleForFilterOptions(audit, description, filtersState),
        )
        .map((description) => CustomFunctions.normalizeAuditType(description.auditFactorType))
        .where((value) => value.isNotEmpty)
        .toSet();

    return preferredOrder.where(availableOptions.contains).toList(growable: false);
  }

  bool _hasActiveFilters(_CheckInDescriptionsListFiltersState filtersState) =>
      filtersState.showAuditedOnly ||
      filtersState.selectedCategories.isNotEmpty ||
      filtersState.selectedMilestones.isNotEmpty ||
      filtersState.selectedAuditTimings.isNotEmpty ||
      filtersState.selectedAuditTypes.isNotEmpty;

  void _toggleFilterOptions() {
    final currentState = _filtersNotifier.value;
    _filtersNotifier.value = currentState.copyWith(
      isFilterOptionsVisible: !currentState.isFilterOptionsVisible,
    );
  }

  void _toggleCategory(String value) {
    _filtersNotifier.value = _filtersNotifier.value.toggleCategory(value);
  }

  void _toggleShowAuditedOnly() {
    final currentState = _filtersNotifier.value;
    _filtersNotifier.value = currentState.copyWith(showAuditedOnly: !currentState.showAuditedOnly);
  }

  void _toggleMilestone(String value) {
    _filtersNotifier.value = _filtersNotifier.value.toggleMilestone(value);
  }

  void _toggleAuditTiming(String value) {
    _filtersNotifier.value = _filtersNotifier.value.toggleAuditTiming(value);
  }

  void _toggleAuditType(String value) {
    _filtersNotifier.value = _filtersNotifier.value.toggleAuditType(value);
  }

  void _clearFilters() {
    _clearFiltersSilently();
  }

  void _clearFiltersSilently() {
    _filtersNotifier.value = const _CheckInDescriptionsListFiltersState();
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

class _CheckInDescriptionCard extends StatefulWidget {
  const _CheckInDescriptionCard({
    super.key,
    required this.audit,
    required this.description,
    required this.date,
    required this.isOwner,
    required this.onOpenDetails,
    required this.isSelfAudit,
  });

  final QuarterlyAudit audit;
  final QuarterlyAuditDescription description;
  final String date;
  final bool isOwner;
  final ValueChanged<Map<String, int>> onOpenDetails;
  final bool isSelfAudit;

  @override
  State<_CheckInDescriptionCard> createState() => _CheckInDescriptionCardState();
}

class _CheckInDescriptionCardState extends State<_CheckInDescriptionCard> {
  static const Duration _submitDebounceDuration = Duration(milliseconds: 180);

  late final ValueNotifier<_PassSelectionViewState> _viewStateNotifier;
  late final ValueNotifier<bool> _isMediaCommentCreatedNotifier;
  Timer? _submitDebounceTimer;
  Timer? _mediaCommentSuccessTimer;
  Future<AuditDescriptionAudit>? _auditDescriptionFuture;
  Future<void>? _ratingSubmission;
  late Map<String, int> _lastSyncedAuditCounts;
  final ValueNotifier<bool> _isOpeningDetailsNotifier = ValueNotifier(false);
  var _editRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastSyncedAuditCounts = _auditCountsFromDescription(widget.description);
    _viewStateNotifier = ValueNotifier<_PassSelectionViewState>(
      _PassSelectionViewState(
        blocks: _blocksFromCounts(_lastSyncedAuditCounts),
        hasLocalChanges: false,
      ),
    );
    _isMediaCommentCreatedNotifier = ValueNotifier<bool>(false);
  }

  @override
  void didUpdateWidget(covariant _CheckInDescriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description.uuid != widget.description.uuid ||
        oldWidget.audit.uuid != widget.audit.uuid ||
        oldWidget.date != widget.date) {
      _resetCardState();
      return;
    }

    _syncFromDescriptionSummary();
  }

  @override
  void dispose() {
    _submitDebounceTimer?.cancel();
    _mediaCommentSuccessTimer?.cancel();
    _isOpeningDetailsNotifier.dispose();
    _viewStateNotifier.dispose();
    _isMediaCommentCreatedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEditBlocks =
        _canEditSingleDescriptionAudit(
          isViewOnly: widget.audit.isMismatch,
          isOwner: widget.isOwner,
          date: widget.date,
        ) &&
        !widget.isSelfAudit;
    final canCreateComments = _canCommentOnSingleDescriptionAudit(
      isViewOnly: widget.audit.isMismatch,
      date: widget.date,
    );
    final auditFactorType = CustomFunctions.capitalizeFirstLetter(
      widget.description.auditFactorType,
    );
    final milestone = CustomFunctions.normalizeAuditMilestone(widget.description.milestoneDay);
    final hasMilestone = AppStrings.auditMilestoneOptions.contains(milestone);
    final auditTypeLabel = auditFactorType.isEmpty ? AppStrings.checkInTitle : auditFactorType;
    final milestoneLabel = hasMilestone ? AppStrings.auditMilestoneCardLabel(milestone) : null;
    final descriptionText = widget.description.description.isEmpty
        ? AppStrings.auditNoDescriptionAvailable
        : widget.description.description;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openDetails,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isMediaCommentCreatedNotifier,
        builder: (context, isMediaCommentCreated, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextView.body1(
                        descriptionText,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: _DescriptionAuditTypePill(text: auditTypeLabel),
                    ),
                    if (milestoneLabel != null) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: _DescriptionMilestonePill(text: milestoneLabel),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: canCreateComments ? 78 : 42),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: SizedBox.shrink()),
                          ValueListenableBuilder<_PassSelectionViewState>(
                            valueListenable: _viewStateNotifier,
                            builder: (context, viewState, _) {
                              final counts = _auditCountsFromBlocks(viewState.blocks);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SelectionCounter(
                                    color: canEditBlocks
                                        ? AppColors.green1
                                        : AppColors.green1.withValues(alpha: 0.5),
                                    count: counts['great'] ?? 0,
                                    showDecrementControl: widget.isOwner && !widget.isSelfAudit,
                                    onTapCount: canEditBlocks
                                        ? () => _incrementRating(_PassBlockState.great)
                                        : null,
                                    onTapArrow: canEditBlocks
                                        ? () => _decrementRating(_PassBlockState.great)
                                        : null,
                                    canEditBlocks: canEditBlocks,
                                  ),
                                  const SizedBox(width: 8),
                                  _SelectionCounter(
                                    color: canEditBlocks
                                        ? AppColors.orange1
                                        : AppColors.orange1.withValues(alpha: 0.5),
                                    count: counts['almost_there'] ?? 0,
                                    showDecrementControl: widget.isOwner && !widget.isSelfAudit,
                                    onTapCount: canEditBlocks
                                        ? () => _incrementRating(_PassBlockState.almostThere)
                                        : null,
                                    onTapArrow: canEditBlocks
                                        ? () => _decrementRating(_PassBlockState.almostThere)
                                        : null,
                                    canEditBlocks: canEditBlocks,
                                  ),
                                  const SizedBox(width: 8),
                                  _SelectionCounter(
                                    color: canEditBlocks
                                        ? AppColors.red1
                                        : AppColors.red1.withValues(alpha: 0.5),
                                    count: counts['needs_improvement'] ?? 0,
                                    showDecrementControl: widget.isOwner && !widget.isSelfAudit,
                                    onTapCount: canEditBlocks
                                        ? () => _incrementRating(_PassBlockState.needsImprovement)
                                        : null,
                                    onTapArrow: canEditBlocks
                                        ? () => _decrementRating(_PassBlockState.needsImprovement)
                                        : null,
                                    canEditBlocks: canEditBlocks,
                                  ),
                                ],
                              );
                            },
                          ),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isMediaCommentCreated
                                    ? AppColors.green1
                                    : AppColors.secondaryColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _isOpeningDetailsNotifier,
                                builder: (context, isOpeningDetails, _) {
                                  if (isOpeningDetails) {
                                    return Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: FastCircularProgressIndicator(),
                                    );
                                  }
                                  return Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: isMediaCommentCreated
                                        ? Colors.white
                                        : AppColors.secondaryColor,
                                    size: 16,
                                  );
                                },
                              ),
                            ),
                            if (canCreateComments)
                              _CommentIconButton(
                                isEnabled: true,
                                icon: Icons.camera_alt_outlined,
                                onTap: _openCreateCommentDialog,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _auditCountsFromDescription(QuarterlyAuditDescription description) {
    return <String, int>{
      'great': description.great,
      'almost_there': description.almostThere,
      'needs_improvement': description.needsImprovement,
    };
  }

  Future<void> _openDetails() async {
    if (_isOpeningDetailsNotifier.value) {
      return;
    }
    _isOpeningDetailsNotifier.value = true;
    try {
      // Finish edits made on the card before the detail screen starts editing
      // the same description, including an unresolved audit-UUID request.
      _submitDebounceTimer?.cancel();
      await _ratingSubmission;
      if (!mounted) {
        return;
      }
      if (_viewStateNotifier.value.hasLocalChanges) {
        await _submitDescriptionAudit(
          _auditCountsFromBlocks(_viewStateNotifier.value.blocks),
          _editRevision,
        );
      }
      if (!mounted) {
        return;
      }
      widget.onOpenDetails(_auditCountsFromBlocks(_viewStateNotifier.value.blocks));
    } finally {
      if (mounted) {
        _isOpeningDetailsNotifier.value = false;
      }
    }
  }

  Map<String, int> _auditCountsFromBlocks(List<_PassBlockState> blocks) {
    return <String, int>{
      'great': blocks.where((block) => block == _PassBlockState.great).length,
      'almost_there': blocks.where((block) => block == _PassBlockState.almostThere).length,
      'needs_improvement': blocks
          .where((block) => block == _PassBlockState.needsImprovement)
          .length,
    };
  }

  List<_PassBlockState> _blocksFromCounts(Map<String, int> counts) {
    final great = counts['great'] ?? 0;
    final almostThere = counts['almost_there'] ?? 0;
    final needsImprovement = counts['needs_improvement'] ?? 0;
    final blocks = <_PassBlockState>[
      for (var index = 0; index < great; index += 1) _PassBlockState.great,
      for (var index = 0; index < almostThere; index += 1) _PassBlockState.almostThere,
      for (var index = 0; index < needsImprovement; index += 1) _PassBlockState.needsImprovement,
    ];
    if (blocks.isEmpty) {
      blocks.add(_PassBlockState.defaultValue);
    }
    return blocks;
  }

  void _resetCardState() {
    _submitDebounceTimer?.cancel();
    _auditDescriptionFuture = null;
    _ratingSubmission = null;
    _editRevision = 0;
    _lastSyncedAuditCounts = _auditCountsFromDescription(widget.description);
    _viewStateNotifier.value = _PassSelectionViewState(
      blocks: _blocksFromCounts(_lastSyncedAuditCounts),
      hasLocalChanges: false,
    );
  }

  void _syncFromDescriptionSummary() {
    final summaryCounts = _auditCountsFromDescription(widget.description);
    final currentState = _viewStateNotifier.value;
    if (currentState.hasLocalChanges) {
      return;
    }

    if (_sameAuditCounts(_lastSyncedAuditCounts, summaryCounts)) {
      return;
    }

    _lastSyncedAuditCounts = summaryCounts;
    _viewStateNotifier.value = _PassSelectionViewState(
      blocks: _blocksFromCounts(summaryCounts),
      hasLocalChanges: false,
    );
  }

  bool _sameAuditCounts(Map<String, int> left, Map<String, int> right) {
    return (left['great'] ?? 0) == (right['great'] ?? 0) &&
        (left['almost_there'] ?? 0) == (right['almost_there'] ?? 0) &&
        (left['needs_improvement'] ?? 0) == (right['needs_improvement'] ?? 0);
  }

  void _decrementRating(_PassBlockState state) {
    final currentState = _viewStateNotifier.value;
    final updatedBlocks = List<_PassBlockState>.from(currentState.blocks);
    final index = updatedBlocks.lastIndexOf(state);
    if (index < 0) {
      return;
    }

    updatedBlocks.removeAt(index);
    _editRevision += 1;
    _viewStateNotifier.value = _PassSelectionViewState(
      blocks: _normalizeDefaultBlocks(updatedBlocks),
      hasLocalChanges: true,
    );
    _scheduleAuditSubmission();
  }

  void _incrementRating(_PassBlockState state) {
    final currentState = _viewStateNotifier.value;
    final count = currentState.blocks.where((block) => block == state).length;
    if (!AuditRating.canIncrementCount(count)) {
      return;
    }

    final updatedBlocks = List<_PassBlockState>.from(currentState.blocks)
      ..removeWhere((block) => block == _PassBlockState.defaultValue)
      ..add(state);
    _editRevision += 1;
    _viewStateNotifier.value = _PassSelectionViewState(
      blocks: updatedBlocks,
      hasLocalChanges: true,
    );
    _scheduleAuditSubmission();
  }

  List<_PassBlockState> _normalizeDefaultBlocks(List<_PassBlockState> blocks) {
    final hasSelectedBlock = blocks.any((block) => block != _PassBlockState.defaultValue);
    if (hasSelectedBlock) {
      return blocks;
    }

    return <_PassBlockState>[_PassBlockState.defaultValue];
  }

  void _scheduleAuditSubmission() {
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(_submitDebounceDuration, () {
      if (!mounted) {
        return;
      }

      _submitDescriptionAudit(
        _auditCountsFromBlocks(_viewStateNotifier.value.blocks),
        _editRevision,
      );
    });
  }

  Future<void> _submitDescriptionAudit(Map<String, int> audit, int submissionRevision) {
    final submission = _saveDescriptionAudit(audit, submissionRevision);
    _ratingSubmission = submission;
    return submission;
  }

  Future<void> _saveDescriptionAudit(Map<String, int> audit, int submissionRevision) async {
    try {
      final controller = context.read<CheckInController>();
      final descriptionId = await _resolveAuditUuid();

      final response = await controller.submitAuditDescriptionSelection(
        quarterlyAuditId: widget.audit.uuid,
        seatDescriptionId: widget.description.uuid,
        descriptionId: descriptionId,
        audit: audit,
      );

      if (!mounted) {
        return;
      }

      // The submit response can omit its audit list, so retain the payload
      // that the API just accepted instead of briefly rendering zero counts.
      _lastSyncedAuditCounts = Map<String, int>.from(audit);
      _auditDescriptionFuture = Future<AuditDescriptionAudit>.value(response);

      if (submissionRevision != _editRevision) {
        return;
      }

      _viewStateNotifier.value = _PassSelectionViewState(
        blocks: _blocksFromCounts(_lastSyncedAuditCounts),
        hasLocalChanges: false,
      );
    } catch (error) {
      debugPrint('Unable to submit description audit from list: $error');
      if (!mounted || submissionRevision != _editRevision) {
        return;
      }

      _revertToLastSyncedState();
      _showSnackBar(AppStrings.auditUnableToUpdateRating);
    }
  }

  Future<void> _openCreateCommentDialog() async {
    try {
      final auditUuid = await _resolveAuditUuid();
      if (!mounted) {
        return;
      }

      final didCreateMediaComment = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return _DescriptionMediaTypeSelectionBottomSheet(
            onTypeSelected: (selectedType) =>
                _openSelectedMediaCommentDialog(auditUuid, selectedType),
            onCommentOnlySelected: () => _openTextOnlyCommentDialog(auditUuid),
          );
        },
      );
      if (didCreateMediaComment == true && mounted) {
        _animateMediaCommentCreated();
      }
    } catch (error) {
      debugPrint('Unable to resolve audit uuid for media comment: $error');
      if (!mounted) {
        return;
      }

      _showSnackBar(AppStrings.auditUnableToLoadDescriptionDetails);
    }
  }

  Future<String> _resolveAuditUuid() async {
    final auditUuid = widget.description.auditUuid.trim();
    if (auditUuid.isNotEmpty) {
      return auditUuid;
    }

    final inFlightRequest = _auditDescriptionFuture;
    final auditDescription = inFlightRequest != null
        ? await inFlightRequest
        : await _loadAuditDescriptionForUuid();
    final resolvedAuditUuid = auditDescription.uuid.trim();
    if (resolvedAuditUuid.isEmpty) {
      throw StateError('Audit description uuid is empty.');
    }

    return resolvedAuditUuid;
  }

  Future<AuditDescriptionAudit> _loadAuditDescriptionForUuid() async {
    final quarterlyAuditId = widget.audit.uuid.trim();
    final descriptionId = widget.description.uuid.trim();
    final date = widget.date.trim();
    if (quarterlyAuditId.isEmpty || descriptionId.isEmpty || date.isEmpty) {
      throw StateError('Audit description is missing required identifiers.');
    }

    final future = context.read<CheckInController>().loadAuditDescription(
      quarterlyAuditId: quarterlyAuditId,
      descriptionId: descriptionId,
      date: date,
    );
    _auditDescriptionFuture = future;

    try {
      final auditDescription = await future;
      _auditDescriptionFuture = Future<AuditDescriptionAudit>.value(auditDescription);
      return auditDescription;
    } catch (_) {
      _auditDescriptionFuture = null;
      rethrow;
    }
  }

  Future<bool> _openTextOnlyCommentDialog(String auditUuid) async {
    final controller = context.read<CheckInController>();
    final didSave = await showDialog<bool>(
      context: context,
      builder: (_) => DescriptionTextCommentDialog(
        onSave: (comment) =>
            controller.createAuditDescriptionComment(descriptionId: auditUuid, comment: comment),
      ),
    );

    return didSave == true && mounted;
  }

  Future<bool> _openSelectedMediaCommentDialog(
    String auditUuid,
    DescriptionMediaCommentContentType selectedType,
  ) async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DescriptionMediaCommentBottomSheet(
          contentType: selectedType,
          onSave: (comment, mediaFile, mediaType) =>
              _saveCommentWithMedia(auditUuid, comment, mediaFile, mediaType),
        );
      },
    );

    if (didSave != true || !mounted) {
      return false;
    }

    return true;
  }

  Future<void> _saveCommentWithMedia(
    String descriptionId,
    String comment,
    File? mediaFile,
    String? mediaType,
  ) async {
    await context.read<CheckInController>().createAuditDescriptionMediaComment(
      descriptionId: descriptionId,
      comment: comment,
      mediaFile: mediaFile,
      mediaType: mediaType,
    );
  }

  void _animateMediaCommentCreated() {
    _mediaCommentSuccessTimer?.cancel();
    _isMediaCommentCreatedNotifier.value = true;
    _mediaCommentSuccessTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _isMediaCommentCreatedNotifier.value = false;
      }
    });
  }

  void _revertToLastSyncedState() {
    _viewStateNotifier.value = _PassSelectionViewState(
      blocks: _blocksFromCounts(_lastSyncedAuditCounts),
      hasLocalChanges: false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DescriptionAuditTypePill extends StatelessWidget {
  const _DescriptionAuditTypePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.orange1, borderRadius: BorderRadius.circular(50)),
      child: AppTextView.body2(
        text,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 9,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DescriptionMilestonePill extends StatelessWidget {
  const _DescriptionMilestonePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.hexe8f2ff,
        border: Border.all(color: AppColors.purple1),
        borderRadius: BorderRadius.circular(50),
      ),
      child: AppTextView.body2(
        text,
        color: AppColors.purple1,
        fontWeight: FontWeight.w600,
        fontSize: 9,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SelectionCounter extends StatelessWidget {
  const _SelectionCounter({
    required this.color,
    required this.count,
    this.onTapCount,
    this.onTapArrow,
    required this.canEditBlocks,
    required this.showDecrementControl,
  });

  final Color color;
  final int count;
  final VoidCallback? onTapCount;
  final VoidCallback? onTapArrow;
  final bool canEditBlocks;
  final bool showDecrementControl;

  @override
  Widget build(BuildContext context) {
    final hasReachedLimit = !AuditRating.canIncrementCount(count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasReachedLimit ? null : onTapCount,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasReachedLimit ? color.withValues(alpha: 0.5) : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppTextView.body2(
              '$count',
              color: hasReachedLimit ? Colors.white60 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        if (showDecrementControl) ...[
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapArrow,
            child: Container(
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: canEditBlocks ? AppColors.grey1 : AppColors.grey1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                canEditBlocks ? Icons.keyboard_arrow_down_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: canEditBlocks ? 24 : 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentIconButton extends StatelessWidget {
  const _CommentIconButton({required this.isEnabled, required this.icon, this.onTap});

  final bool isEnabled;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? AppColors.secondaryColor : AppColors.grey1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _DescriptionMediaTypeSelectionBottomSheet extends StatefulWidget {
  const _DescriptionMediaTypeSelectionBottomSheet({
    required this.onTypeSelected,
    required this.onCommentOnlySelected,
  });

  final Future<bool> Function(DescriptionMediaCommentContentType selectedType) onTypeSelected;
  final Future<bool> Function() onCommentOnlySelected;

  @override
  State<_DescriptionMediaTypeSelectionBottomSheet> createState() =>
      _DescriptionMediaTypeSelectionBottomSheetState();
}

class _DescriptionMediaTypeSelectionBottomSheetState
    extends State<_DescriptionMediaTypeSelectionBottomSheet> {
  static const _availableTypes = <DescriptionMediaCommentContentType>[
    DescriptionMediaCommentContentType.photo,
    DescriptionMediaCommentContentType.video,
    DescriptionMediaCommentContentType.upload,
  ];

  late final ValueNotifier<bool> _isOpeningChildSheetNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isOpeningChildSheetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: _isOpeningChildSheetNotifier,
      builder: (context, isOpeningChildSheet, _) {
        return SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding + 24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const AppTextView.body1(
                    AppStrings.auditSelectMediaType,
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 14),
                  _MediaTypeOption(
                    title: AppStrings.auditCommentOnly,
                    onTap: isOpeningChildSheet
                        ? null
                        : () => _openChildSheet(widget.onCommentOnlySelected),
                  ),
                  ..._availableTypes.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _MediaTypeOption(
                        title: _mediaTypeTitle(type),
                        onTap: isOpeningChildSheet
                            ? null
                            : () => _openChildSheet(() => widget.onTypeSelected(type)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    text: AppStrings.done,
                    onPressed: isOpeningChildSheet ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _mediaTypeTitle(DescriptionMediaCommentContentType type) {
    return switch (type) {
      DescriptionMediaCommentContentType.photo => AppStrings.auditPhoto,
      DescriptionMediaCommentContentType.video => AppStrings.auditVideo,
      DescriptionMediaCommentContentType.upload => AppStrings.auditUpload,
      DescriptionMediaCommentContentType.screenRecording => AppStrings.auditScreenRecording,
    };
  }

  Future<void> _openChildSheet(Future<bool> Function() openSheet) async {
    if (_isOpeningChildSheetNotifier.value) {
      return;
    }

    _isOpeningChildSheetNotifier.value = true;
    try {
      final didSave = await openSheet();
      if (didSave && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        _isOpeningChildSheetNotifier.value = false;
      }
    }
  }
}

class _MediaTypeOption extends StatelessWidget {
  const _MediaTypeOption({required this.title, required this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTextView.body2(
                  title,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInDescriptionsListFiltersState {
  const _CheckInDescriptionsListFiltersState({
    this.isFilterOptionsVisible = false,
    this.showAuditedOnly = false,
    this.selectedCategories = const <String>{},
    this.selectedMilestones = const <String>{},
    this.selectedAuditTimings = const <String>{},
    this.selectedAuditTypes = const <String>{},
  });

  final bool isFilterOptionsVisible;
  final bool showAuditedOnly;
  final Set<String> selectedCategories;
  final Set<String> selectedMilestones;
  final Set<String> selectedAuditTimings;
  final Set<String> selectedAuditTypes;

  _CheckInDescriptionsListFiltersState copyWith({
    bool? isFilterOptionsVisible,
    bool? showAuditedOnly,
    Set<String>? selectedCategories,
    Set<String>? selectedMilestones,
    Set<String>? selectedAuditTimings,
    Set<String>? selectedAuditTypes,
  }) {
    return _CheckInDescriptionsListFiltersState(
      isFilterOptionsVisible: isFilterOptionsVisible ?? this.isFilterOptionsVisible,
      showAuditedOnly: showAuditedOnly ?? this.showAuditedOnly,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedMilestones: selectedMilestones ?? this.selectedMilestones,
      selectedAuditTimings: selectedAuditTimings ?? this.selectedAuditTimings,
      selectedAuditTypes: selectedAuditTypes ?? this.selectedAuditTypes,
    );
  }

  _CheckInDescriptionsListFiltersState toggleCategory(String value) {
    return copyWith(selectedCategories: _toggleSetValue(selectedCategories, value));
  }

  _CheckInDescriptionsListFiltersState toggleMilestone(String value) {
    return copyWith(selectedMilestones: _toggleSetValue(selectedMilestones, value));
  }

  _CheckInDescriptionsListFiltersState toggleAuditTiming(String value) {
    return copyWith(selectedAuditTimings: _toggleSetValue(selectedAuditTimings, value));
  }

  _CheckInDescriptionsListFiltersState toggleAuditType(String value) {
    return copyWith(selectedAuditTypes: _toggleSetValue(selectedAuditTypes, value));
  }

  static Set<String> _toggleSetValue(Set<String> values, String value) {
    final updatedValues = Set<String>.from(values);
    if (updatedValues.contains(value)) {
      updatedValues.remove(value);
    } else {
      updatedValues.add(value);
    }
    return updatedValues;
  }
}
