import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../widgets/kaizengram_notifier_state.dart';
import '../providers/kaizengram_chat_controller.dart';
import 'chat_module_ui.dart';
import 'chat_user_initial_avatar.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';

class AddPeopleBottomSheet extends StatefulWidget {
  const AddPeopleBottomSheet({super.key, required this.controller});

  final KaizengramChatController controller;

  @override
  State<AddPeopleBottomSheet> createState() => _AddPeopleBottomSheetState();
}

class _AddPeopleBottomSheetState extends State<AddPeopleBottomSheet>
    with KaizengramNotifierState<AddPeopleBottomSheet> {
  late final TextEditingController _queryController;
  final List<KaizengramChatUser> _selectedUsers = <KaizengramChatUser>[];
  String? _errorText;

  Set<String> get _selectedEmails =>
      _selectedUsers.map((user) => user.normalizedEmail).toSet();

  String get _query => _queryController.text.trim();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryController.addListener(() {
      if (_errorText != null) {
        updateView(() => _errorText = null);
        return;
      }
      notifyView();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  KaizengramChatUser? get _pendingCandidate {
    return widget.controller.currentChannelInviteCandidate(
      _query,
      excludedEmails: _selectedEmails,
    );
  }

  List<KaizengramChatUser> get _matchedUsers {
    final normalizedQuery = _query.toLowerCase();
    final matchedUsers = widget.controller.users
        .where(
          (user) =>
              user.normalizedEmail !=
                  widget.controller.currentUser.normalizedEmail &&
              user.normalizedEmail != AppStrings.userBotEmail &&
              user.matchesQuery(normalizedQuery),
        )
        .toList(growable: false);

    matchedUsers.sort((left, right) {
      final leftStarts =
          left.name.toLowerCase().startsWith(normalizedQuery) ||
          left.normalizedEmail.startsWith(normalizedQuery);
      final rightStarts =
          right.name.toLowerCase().startsWith(normalizedQuery) ||
          right.normalizedEmail.startsWith(normalizedQuery);
      if (leftStarts != rightStarts) {
        return leftStarts ? -1 : 1;
      }

      return left.name.compareTo(right.name);
    });

    final pendingCandidate = _pendingCandidate;
    final filteredUsers = matchedUsers
        .where(
          (user) =>
              pendingCandidate == null ||
              user.normalizedEmail != pendingCandidate.normalizedEmail,
        )
        .toList(growable: false);

    if (normalizedQuery.isEmpty && filteredUsers.length > 8) {
      return filteredUsers.take(8).toList(growable: false);
    }

    return filteredUsers;
  }

  bool _isSelectable(KaizengramChatUser user) {
    return !widget.controller.currentChannelMemberEmails.contains(
          user.normalizedEmail,
        ) &&
        !_selectedEmails.contains(user.normalizedEmail);
  }

  String _actionLabelForUser(KaizengramChatUser user) {
    if (widget.controller.currentChannelMemberEmails.contains(
      user.normalizedEmail,
    )) {
      return AppStrings.addPeopleAlreadyInChannelLabel;
    }
    if (_selectedEmails.contains(user.normalizedEmail)) {
      return AppStrings.addPeopleSelectedLabel;
    }
    return AppStrings.addPeopleLabel;
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;
      final pendingCandidate = _pendingCandidate;
      final suggestedUsers = _matchedUsers;
      final channelName = widget.controller.activeChannelName ?? '';

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            height: sheetHeight,
            child: AppKeyboardBottomSheetSurface(
              color: kaizengramChatScreenSurfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const KaizengramChatSheetHandle(),
                    const SizedBox(height: 18),
                    AppTextView.body1(
                      AppStrings.addPersonTitle(channelName),
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    const SizedBox(height: 6),
                    AppTextView.body4(
                      AppStrings.addPeopleSheetSubtitle(channelName),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 18),
                    AppTextView.body3(
                      AppStrings.addPeopleSearchLabel,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    KaizengramChatInputShell(
                      borderColor: _errorText == null
                          ? null
                          : AppColors.red.withValues(alpha: 0.70),
                      child: TextField(
                        controller: _queryController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.textPrimary,
                        decoration: const InputDecoration(
                          hintText: AppStrings.addPeopleSearchHint,
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14),
                          prefixIcon: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onSubmitted: (_) => _addPendingCandidate(),
                      ),
                    ),
                    if (_errorText != null) ...<Widget>[
                      const SizedBox(height: 8),
                      AppTextView.body4(
                        _errorText!,
                        color: AppColors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                    if (_selectedUsers.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      AppTextView.body4(
                        AppStrings.addPeopleSelectedCountLabel(
                          _selectedUsers.length,
                        ),
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedUsers
                            .map(
                              (user) => _SelectedChatUserChip(
                                user: user,
                                onRemove: () => _removeSelectedUser(user),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: <Widget>[
                          const AppTextView.body3(
                            AppStrings.addPeopleSuggestedHeader,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          const SizedBox(height: 12),
                          if (pendingCandidate != null) ...<Widget>[
                            _ChatInviteSuggestionTile(
                              user: pendingCandidate,
                              index: 0,
                              subtitle: pendingCandidate.isExternal
                                  ? AppStrings.addPeopleEmailInviteSubtitle(
                                      pendingCandidate.email,
                                    )
                                  : pendingCandidate.email,
                              actionLabel: AppStrings.addPeopleLabel,
                              onTap: () => _addSelectedUser(pendingCandidate),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (suggestedUsers.isEmpty &&
                              pendingCandidate == null)
                            const _AddPeopleEmptyState()
                          else
                            ...List<Widget>.generate(suggestedUsers.length, (
                              index,
                            ) {
                              final user = suggestedUsers[index];
                              final selectable = _isSelectable(user);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ChatInviteSuggestionTile(
                                  user: user,
                                  index: index + 1,
                                  subtitle: user.email,
                                  actionLabel: _actionLabelForUser(user),
                                  onTap: selectable
                                      ? () => _addSelectedUser(user)
                                      : null,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: KaizengramChatSecondaryButton(
                            label: AppStrings.actionCancel,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KaizengramChatPrimaryButton(
                            label: AppStrings.addPeopleConfirm,
                            onTap: _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _addSelectedUser(KaizengramChatUser user) {
    if (!_isSelectable(user)) {
      return;
    }

    updateView(() {
      _selectedUsers.add(user);
      _queryController.clear();
      _errorText = null;
    });
  }

  void _removeSelectedUser(KaizengramChatUser user) {
    updateView(() {
      _selectedUsers.removeWhere(
        (selectedUser) => selectedUser.normalizedEmail == user.normalizedEmail,
      );
      _errorText = null;
    });
  }

  void _addPendingCandidate() {
    final pendingCandidate = _pendingCandidate;
    if (pendingCandidate == null) {
      updateView(() {
        _errorText = _query.isEmpty
            ? AppStrings.addPeopleEmptySelectionError
            : widget.controller.validateUserEmailForCurrentChannel(_query) ??
                  AppStrings.invalidEmailError;
      });
      return;
    }

    _addSelectedUser(pendingCandidate);
  }

  void _submit() {
    final pendingCandidate = _pendingCandidate;
    final invitees = <KaizengramChatUser>[
      ..._selectedUsers,
      if (pendingCandidate != null &&
          !_selectedEmails.contains(pendingCandidate.normalizedEmail))
        pendingCandidate,
    ];

    if (invitees.isEmpty) {
      updateView(() {
        _errorText = _query.isEmpty
            ? AppStrings.addPeopleEmptySelectionError
            : widget.controller.validateUserEmailForCurrentChannel(_query) ??
                  AppStrings.invalidEmailError;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(invitees.map((user) => user.normalizedEmail).toList(growable: false));
  }
}

class _ChatInviteSuggestionTile extends StatelessWidget {
  const _ChatInviteSuggestionTile({
    required this.user,
    required this.index,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final KaizengramChatUser user;
  final int index;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kaizengramChatCardSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          ChatUserInitialAvatar(
            label: kaizengramChatInitialFor(user.name),
            accentColor: kaizengramChatAccentColorForIndex(index),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextView.body3(
                  user.name,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                AppTextView.body4(
                  subtitle,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IgnorePointer(
            ignoring: onTap == null,
            child: Opacity(
              opacity: onTap == null ? 0.65 : 1,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: onTap == null
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.secondaryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: onTap == null
                          ? AppColors.textPrimary.withValues(alpha: 0.10)
                          : AppColors.secondaryColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: AppTextView.body4(
                    actionLabel,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChatUserChip extends StatelessWidget {
  const _SelectedChatUserChip({required this.user, required this.onRemove});

  final KaizengramChatUser user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextView.body4(
            user.name,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPeopleEmptyState extends StatelessWidget {
  const _AddPeopleEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kaizengramChatCardSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextView.body3(
            AppStrings.addPeopleSearchEmptyTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          SizedBox(height: 6),
          AppTextView.body4(
            AppStrings.addPeopleSearchEmptySubtitle,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
