import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../widgets/kaizengram_notifier_state.dart';
import '../providers/kaizengram_chat_controller.dart';
import '../widgets/chat_module_ui.dart';
import '../widgets/chat_user_initial_avatar.dart';
import '../widgets/create_channel_bottom_sheet.dart';
import 'kaizengram_chat_screen.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';

class KaizengramChannelsScreen extends StatelessWidget {
  const KaizengramChannelsScreen({super.key, this.controller});

  final KaizengramChatController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ChangeNotifierProvider<KaizengramChatController>.value(
        value: controller!,
        child: const _KaizengramChannelsView(),
      );
    }

    return ChangeNotifierProvider<KaizengramChatController>(
      create: (_) => KaizengramChatController(),
      child: const _KaizengramChannelsView(),
    );
  }
}

class _KaizengramChannelsView extends StatelessWidget {
  const _KaizengramChannelsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KaizengramChatController>();

    return Scaffold(
      backgroundColor: kaizengramChatScreenSurfaceColor,
      appBar: AppBar(
        backgroundColor: kaizengramChatScreenSurfaceColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: const AppTextView.body1(
          AppStrings.chatHomeTitle,
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: <Widget>[
          _SectionHeader(
            title: AppStrings.channelsTitle,
            actionIcon: Icons.add_rounded,
            onActionTap: () => _showCreateChannelSheet(context),
          ),
          const SizedBox(height: 8),
          ...controller.channels.map(
            (channel) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChannelListTile(
                channel: channel,
                memberCount: controller.channelMemberCount(channel.name),
                onTap: () => _openChannel(context, channel.name),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: AppStrings.directMessagesTitle,
            actionIcon: Icons.add_rounded,
            onActionTap: () => _showDirectMessageSheet(context),
          ),
          const SizedBox(height: 8),
          if (controller.directMessageUsers.isEmpty)
            const _EmptyDirectMessagesCard()
          else
            ...controller.directMessageUsers.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DirectMessageListTile(
                  user: user,
                  onTap: () => _openDirectMessage(context, user.email),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateChannelSheet(BuildContext context) async {
    final controller = context.read<KaizengramChatController>();
    final createdChannel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateChannelBottomSheet(controller: controller),
    );

    if (createdChannel == null || createdChannel.isEmpty || !context.mounted) {
      return;
    }

    await _openChannel(context, createdChannel);
  }

  Future<void> _showDirectMessageSheet(BuildContext context) async {
    final controller = context.read<KaizengramChatController>();
    final selectedEmail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StartDirectMessageBottomSheet(controller: controller),
    );

    if (selectedEmail == null || !context.mounted) {
      return;
    }

    await _openDirectMessage(context, selectedEmail);
  }

  Future<void> _openChannel(BuildContext context, String channelName) {
    final controller = context.read<KaizengramChatController>();
    controller.selectChannel(channelName);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramChatScreen(controller: controller),
      ),
    );
  }

  Future<void> _openDirectMessage(BuildContext context, String userEmail) {
    final controller = context.read<KaizengramChatController>();
    controller.openDirectMessage(userEmail);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramChatScreen(controller: controller),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionIcon,
    required this.onActionTap,
  });

  final String title;
  final IconData actionIcon;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AppTextView.body2(
            title,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        InkWell(
          onTap: onActionTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kaizengramChatCardSurfaceColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(actionIcon, color: AppColors.textPrimary, size: 18),
          ),
        ),
      ],
    );
  }
}

class _ChannelListTile extends StatelessWidget {
  const _ChannelListTile({
    required this.channel,
    required this.memberCount,
    required this.onTap,
  });

  final KaizengramChatChannel channel;
  final int memberCount;
  final VoidCallback onTap;
  //
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 14),
        decoration: BoxDecoration(
          color: kaizengramChatCardSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: <Widget>[
                      _ChannelAvatar(channel: channel),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AppTextView.body2(
                              '#${channel.name}',
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(height: 2),
                            AppTextView.body4(
                              AppStrings.channelMembersLabel(memberCount),
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel});

  final KaizengramChatChannel channel;

  @override
  Widget build(BuildContext context) {
    final imagePath = channel.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      final networkUrl = CustomFunctions.resolveNetworkUrl(imagePath);
      final imageProvider = networkUrl != null
          ? NetworkImage(networkUrl)
          : FileImage(File(imagePath)) as ImageProvider<Object>;
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.surfaceDark3,
        backgroundImage: imageProvider,
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: const Icon(
        Icons.tag_rounded,
        color: AppColors.secondaryColor,
        size: 18,
      ),
    );
  }
}

class _DirectMessageListTile extends StatelessWidget {
  const _DirectMessageListTile({required this.user, required this.onTap});

  final KaizengramChatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kaizengramChatCardSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              ChatUserInitialAvatar(
                label: kaizengramChatInitialFor(user.name),
                accentColor: AppColors.blue,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppTextView.body2(
                      user.name,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 1),
                    AppTextView.body4(
                      user.email,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
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

class _EmptyDirectMessagesCard extends StatelessWidget {
  const _EmptyDirectMessagesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kaizengramChatCardSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: const AppTextView.body3(
        AppStrings.noDirectMessages,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StartDirectMessageBottomSheet extends StatefulWidget {
  const _StartDirectMessageBottomSheet({required this.controller});

  final KaizengramChatController controller;

  @override
  State<_StartDirectMessageBottomSheet> createState() =>
      _StartDirectMessageBottomSheetState();
}

class _StartDirectMessageBottomSheetState
    extends State<_StartDirectMessageBottomSheet>
    with KaizengramNotifierState<_StartDirectMessageBottomSheet> {
  late final TextEditingController _queryController;

  String get _query => _queryController.text.trim();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryController.addListener(notifyView);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final candidates = widget.controller.directMessageCandidatesForQuery(
        _query,
      );
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: AppKeyboardBottomSheetSurface(
            width: double.infinity,
            color: kaizengramChatScreenSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const KaizengramChatSheetHandle(),
                  const SizedBox(height: 18),
                  const AppTextView.body1(
                    AppStrings.startDirectMessageTitle,
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 6),
                  const AppTextView.body2(
                    AppStrings.startDirectMessageSubtitle,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 18),
                  const AppTextView.body3(
                    AppStrings.startDirectMessageSearchLabel,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 8),
                  KaizengramChatInputShell(
                    child: TextField(
                      controller: _queryController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      cursorColor: AppColors.textPrimary,
                      decoration: const InputDecoration(
                        hintText: AppStrings.startDirectMessageSearchHint,
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                    ),
                    child: candidates.isEmpty
                        ? const _StartDirectMessageEmptyState()
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: candidates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final user = candidates[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      Navigator.of(context).pop(user.email),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kaizengramChatCardSurfaceColor,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        ChatUserInitialAvatar(
                                          label: kaizengramChatInitialFor(
                                            user.name,
                                          ),
                                          accentColor:
                                              kaizengramChatAccentColorForIndex(
                                                index,
                                              ),
                                          size: 38,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              AppTextView.body2(
                                                user.name,
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              const SizedBox(height: 2),
                                              AppTextView.body4(
                                                user.email,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _StartDirectMessageEmptyState extends StatelessWidget {
  const _StartDirectMessageEmptyState();

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
            AppStrings.startDirectMessageEmptyTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          SizedBox(height: 6),
          AppTextView.body4(
            AppStrings.startDirectMessageEmptySubtitle,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
