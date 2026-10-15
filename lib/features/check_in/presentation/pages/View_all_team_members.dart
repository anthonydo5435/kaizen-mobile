// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/audit_profile.dart';
import '../providers/check_in_controller.dart';
import '../widgets/check_in_member_card.dart';

class ViewAllTeamMembers extends StatefulWidget {
  const ViewAllTeamMembers({super.key, required this.members});

  final List<AuditProfile> members;

  @override
  State<ViewAllTeamMembers> createState() => _ViewAllTeamMembersState();
}

class _ViewAllTeamMembersState extends State<ViewAllTeamMembers> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final ValueNotifier<_TeamMembersViewState> _viewStateNotifier;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _viewStateNotifier = ValueNotifier<_TeamMembersViewState>(
      const _TeamMembersViewState(),
    );
  }

  @override
  void dispose() {
    final controller = context.read<CheckInController>();
    if (controller.teamMembersSearchQuery.trim().isNotEmpty) {
      unawaited(controller.resetTeamMembersSearch());
    }

    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    _viewStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CheckInController>();
    final state = controller.state;
    final members = state.mainList?.results ?? widget.members;
    final isSearchLoading =
        state.isLoading && controller.teamMembersSearchQuery.trim().isNotEmpty;
    _syncSearchController(controller.teamMembersSearchQuery);

    return Dialog.fullscreen(
      backgroundColor: AppColors.mainBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 8),
              ValueListenableBuilder<_TeamMembersViewState>(
                valueListenable: _viewStateNotifier,
                builder: (context, viewState, _) {
                  final filteredMembers = _visibleMembers(
                    members,
                    viewState: viewState,
                  );
                  final shouldAutoLoadFavorites =
                      viewState.selectedTab == _TeamMembersTab.favorites &&
                      filteredMembers.isEmpty &&
                      state.mainList?.next != null &&
                      !state.isLoadingMore;

                  if (shouldAutoLoadFavorites) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) {
                        return;
                      }

                      context
                          .read<CheckInController>()
                          .loadNextTeamMembersPage();
                    });
                  }

                  return Expanded(
                    child: Column(
                      children: [
                        _TeamMembersTabs(
                          selectedTab: viewState.selectedTab,
                          onTabChanged: _selectTab,
                        ),
                        const SizedBox(height: 16),
                        _SearchBar(
                          controller: _searchController,
                          onChanged: _updateQuery,
                          isSearchLoading: isSearchLoading,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: state.isLoading && members.isEmpty
                              ? Center(child: FastCircularProgressIndicator())
                              : shouldAutoLoadFavorites
                              ? Center(child: FastCircularProgressIndicator())
                              : filteredMembers.isEmpty
                              ? const Center(
                                  child: AppTextView.body(
                                    AppStrings.auditNoTeamMembersFound,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  itemCount: filteredMembers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 18),
                                  itemBuilder: (context, index) {
                                    final member = filteredMembers[index];
                                    final isFavoriteUpdating = controller
                                        .isFavoriteUpdating(member.profileJob);
                                    return CheckInMemberCard(
                                      member: member,
                                      topRightAction: _FavoriteButton(
                                        isFavorite: member.isFavorite,
                                        isLoading: isFavoriteUpdating,
                                        onPressed: () =>
                                            _handleFavoriteTap(context, member),
                                      ),
                                      onCheckInTap: () =>
                                          Navigator.of(context).pop(member),
                                    );
                                  },
                                ),
                        ),
                        if (state.isLoadingMore) ...[
                          const SizedBox(height: 16),
                          FastCircularProgressIndicator(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 360) {
      return;
    }

    context.read<CheckInController>().loadNextTeamMembersPage();
  }

  void _selectTab(_TeamMembersTab tab) {
    final currentState = _viewStateNotifier.value;
    if (currentState.selectedTab == tab) {
      return;
    }

    _viewStateNotifier.value = currentState.copyWith(selectedTab: tab);
  }

  void _updateQuery(String query) {
    context.read<CheckInController>().updateTeamMembersSearchQuery(query);
  }

  Future<void> _handleFavoriteTap(
    BuildContext context,
    AuditProfile member,
  ) async {
    try {
      await context.read<CheckInController>().toggleFavoriteSubordinate(
        profileJobId: member.profileJob,
        isFavorite: member.isFavorite,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to update favorite right now.')),
        );
    }
  }

  void _syncSearchController(String value) {
    if (_searchController.text == value) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  List<AuditProfile> _visibleMembers(
    List<AuditProfile> members, {
    required _TeamMembersViewState viewState,
  }) {
    final visibleMembers = viewState.selectedTab == _TeamMembersTab.favorites
        ? members.where((member) => member.isFavorite).toList(growable: false)
        : members;
    return visibleMembers;
  }
}

enum _TeamMembersTab { all, favorites }

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const AppTextView.body1(
            AppStrings.auditTeamMembersTab,
            color: AppColors.secondaryColor,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppOverlayCloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.isSearchLoading,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isSearchLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.75),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasQuery = value.text.trim().isNotEmpty;
          const trailingSlotSize = 24.0;
          const trailingIconSize = 18.0;

          return Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  cursorColor: AppColors.textPrimary,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: AppStrings.auditSearchTeamMembersHint,
                    hintStyle: TextStyle(
                      color: AppColors.grey1,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (hasQuery)
                SizedBox(
                  width: trailingSlotSize,
                  height: trailingSlotSize,
                  child: isSearchLoading
                      ? Center(
                          child: FastCircularProgressIndicator(
                            width: trailingIconSize,
                            height: trailingIconSize,
                          ),
                        )
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: trailingSlotSize,
                            height: trailingSlotSize,
                          ),
                          splashRadius: 16,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: trailingIconSize,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamMembersTabs extends StatelessWidget {
  const _TeamMembersTabs({
    required this.selectedTab,
    required this.onTabChanged,
  });

  final _TeamMembersTab selectedTab;
  final ValueChanged<_TeamMembersTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TeamMembersTabButton(
              label: AppStrings.auditAllTeamMembersTab,
              isSelected: selectedTab == _TeamMembersTab.all,
              onTap: () => onTabChanged(_TeamMembersTab.all),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TeamMembersTabButton(
              label: AppStrings.auditMyFavoritesTab,
              isSelected: selectedTab == _TeamMembersTab.favorites,
              onTap: () => onTabChanged(_TeamMembersTab.favorites),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMembersTabButton extends StatelessWidget {
  const _TeamMembersTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppTextView.body3(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFavorite;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: isLoading ? null : onPressed,
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: isLoading
          ? FastCircularProgressIndicator(width: 16, height: 16)
          : Icon(
              Icons.star_rounded,
              color: isFavorite ? AppColors.yellow : AppColors.grey2,
              size: 18,
            ),
    );
  }
}

class _TeamMembersViewState {
  const _TeamMembersViewState({this.selectedTab = _TeamMembersTab.all});

  final _TeamMembersTab selectedTab;

  _TeamMembersViewState copyWith({_TeamMembersTab? selectedTab}) {
    return _TeamMembersViewState(selectedTab: selectedTab ?? this.selectedTab);
  }
}
