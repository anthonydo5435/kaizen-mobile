import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../kaizengram_message_attachment.dart';
import '../../widgets/kaizengram_full_screen_attachment_view.dart';
import '../../widgets/kaizengram_link_preview_card.dart';
import '../../widgets/kaizengram_notifier_state.dart';
import '../providers/kaizengram_chat_controller.dart';
import '../widgets/chat_mention_text.dart';
import '../widgets/chat_message_composer.dart';
import '../widgets/chat_user_initial_avatar.dart';
import '../widgets/chat_users_bottom_sheet.dart';
import '../widgets/chat_video_preview.dart';
import '../widgets/delete_channel_confirmation_dialog.dart';

class KaizengramChatScreen extends StatelessWidget {
  const KaizengramChatScreen({super.key, this.controller});

  final KaizengramChatController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ChangeNotifierProvider<KaizengramChatController>.value(
        value: controller!,
        child: const _KaizengramChatView(),
      );
    }

    return ChangeNotifierProvider<KaizengramChatController>(
      create: (_) => KaizengramChatController(),
      child: const _KaizengramChatView(),
    );
  }
}

class _KaizengramChatView extends StatefulWidget {
  const _KaizengramChatView();

  @override
  State<_KaizengramChatView> createState() => _KaizengramChatViewState();
}

class _KaizengramChatViewState extends State<_KaizengramChatView>
    with KaizengramNotifierState<_KaizengramChatView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  String? _lastAutoScrollKey;
  String? _highlightedMessageId;
  int _highlightSequence = 0;

  static const Color _screenBackground = AppColors.hex111317;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final hasSelectedConversation = context
          .select<KaizengramChatController, bool>(
            (controller) => controller.hasSelectedConversation,
          );
      final conversationTitle = context
          .select<KaizengramChatController, String>(
            (controller) => controller.currentConversationTitle,
          );
      final conversationLabel = context
          .select<KaizengramChatController, String>(
            (controller) => controller.currentConversationLabel,
          );
      final isCurrentConversationChannel = context
          .select<KaizengramChatController, bool>(
            (controller) => controller.isCurrentConversationChannel,
          );
      final messageVersion = context.select<KaizengramChatController, int>(
        (controller) => controller.messageVersion,
      );
      final controller = context.read<KaizengramChatController>();
      final messages = controller.messages;
      final autoScrollKey =
          '$conversationTitle-$messageVersion-${messages.length}';

      if (messages.isNotEmpty && _lastAutoScrollKey != autoScrollKey) {
        _lastAutoScrollKey = autoScrollKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToLatestMessage();
        });
      }

      return Scaffold(
        backgroundColor: _screenBackground,
        appBar: _buildAppBar(
          context,
          conversationTitle: conversationTitle,
          conversationLabel: conversationLabel,
          isCurrentConversationChannel: isCurrentConversationChannel,
        ),
        body: hasSelectedConversation
            ? _buildBody(conversationTitle, messages)
            : const _NoConversationSelectedView(),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required String conversationTitle,
    required String conversationLabel,
    required bool isCurrentConversationChannel,
  }) {
    return AppBar(
      backgroundColor: _screenBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 18,
      title: _ChatAppBarTitle(
        title: conversationTitle,
        subtitle: conversationLabel,
        isChannel: isCurrentConversationChannel,
      ),
      actions: _buildAppBarActions(
        context,
        isCurrentConversationChannel: isCurrentConversationChannel,
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context, {
    required bool isCurrentConversationChannel,
  }) {
    if (!isCurrentConversationChannel) {
      return const <Widget>[SizedBox(width: 8)];
    }

    return <Widget>[
      PopupMenuButton<_ChatMenuAction>(
        color: AppColors.surfaceDark,
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (action) => _handleMenuSelection(context, action),
        itemBuilder: (_) => const <PopupMenuEntry<_ChatMenuAction>>[
          PopupMenuItem<_ChatMenuAction>(
            value: _ChatMenuAction.users,
            child: _PopupMenuLabel(title: AppStrings.menuUsers),
          ),
          PopupMenuItem<_ChatMenuAction>(
            value: _ChatMenuAction.deleteChannel,
            child: _PopupMenuLabel(title: AppStrings.menuDeleteChannel),
          ),
        ],
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildBody(
    String conversationTitle,
    List<KaizengramChatMessage> messages,
  ) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: <Widget>[
          Expanded(child: _buildMessagesContent(messages)),
          KaizengramChatMessageComposer(
            key: ValueKey<String>(conversationTitle),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesContent(List<KaizengramChatMessage> messages) {
    if (messages.isEmpty) {
      return const _EmptyMessagesView();
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _buildMessageItem(context, messages, index),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    List<KaizengramChatMessage> messages,
    int index,
  ) {
    final message = messages[index];
    return KeyedSubtree(
      key: _messageKeyFor(message.id),
      child: _ChatMessageTile(
        message: message,
        index: index,
        onReplyPreviewTap: _scrollToMessage,
        isHighlighted: _highlightedMessageId == message.id,
      ),
    );
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    _ChatMenuAction action,
  ) async {
    switch (action) {
      case _ChatMenuAction.users:
        await _showUsersSheet(context);
        return;
      case _ChatMenuAction.deleteChannel:
        await _confirmDeleteChannel(context);
        return;
    }
  }

  Future<void> _showUsersSheet(BuildContext context) {
    final controller = context.read<KaizengramChatController>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KaizengramChatUsersBottomSheet(controller: controller),
    );
  }

  Future<void> _confirmDeleteChannel(BuildContext context) async {
    final controller = context.read<KaizengramChatController>();
    final deletedChannel = controller.activeChannelName;
    if (deletedChannel == null) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteChannelConfirmationDialog(channelName: deletedChannel),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final wasDeleted = controller.deleteCurrentChannel();
    if (!wasDeleted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.lastChannelError)),
        );
    }
    if (wasDeleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  GlobalKey _messageKeyFor(String messageId) {
    return _messageKeys.putIfAbsent(
      messageId,
      () => GlobalObjectKey(messageId),
    );
  }

  Future<void> _scrollToMessage(String messageId) async {
    final controller = context.read<KaizengramChatController>();
    final targetIndex = controller.messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (targetIndex == -1 || !_scrollController.hasClients) {
      return;
    }

    var targetContext = _messageKeys[messageId]?.currentContext;
    if (targetContext == null) {
      final estimatedOffset = (targetIndex * 150.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      await _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      targetContext = _messageKeys[messageId]?.currentContext;
    }

    if (targetContext == null) {
      return;
    }
    if (!targetContext.mounted) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.18,
    );
    _highlightMessage(messageId);
  }

  void _jumpToLatestMessage() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _highlightMessage(String messageId) {
    final sequence = ++_highlightSequence;
    if (mounted) {
      updateView(() => _highlightedMessageId = messageId);
    }

    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || sequence != _highlightSequence) {
        return;
      }
      updateView(() => _highlightedMessageId = null);
    });
  }
}

enum _ChatMenuAction { users, deleteChannel }

class _EmptyMessagesView extends StatelessWidget {
  const _EmptyMessagesView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: AppTextView.body(
          AppStrings.emptyMessages,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NoConversationSelectedView extends StatelessWidget {
  const _NoConversationSelectedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: AppTextView.body(
          AppStrings.noConversationSelected,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ChatAppBarTitle extends StatelessWidget {
  const _ChatAppBarTitle({
    required this.title,
    required this.subtitle,
    required this.isChannel,
  });

  final String title;
  final String subtitle;
  final bool isChannel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppTextView.body1(
          isChannel ? '#$title' : title,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        const SizedBox(height: 2),
        AppTextView.body4(
          subtitle,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ],
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.message,
    required this.index,
    required this.onReplyPreviewTap,
    required this.isHighlighted,
  });

  final KaizengramChatMessage message;
  final int index;
  final Future<void> Function(String messageId) onReplyPreviewTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final accentColor = kaizengramChatAccentColorForIndex(index);
    final controller = context.read<KaizengramChatController>();
    final isOwnMessage = controller.isOwnMessage(message);

    return GestureDetector(
      onLongPressStart: (details) =>
          _showMessageActions(context, details.globalPosition, controller),
      child: Row(
        key: ValueKey<String>(message.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!isOwnMessage) ...<Widget>[
            ChatUserInitialAvatar(
              label: kaizengramChatInitialFor(message.sender.name),
              accentColor: accentColor,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwnMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedScale(
                  scale: isHighlighted ? 1.02 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.68,
                    ),
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      top: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isOwnMessage
                          ? AppColors.secondaryColor.withValues(alpha: 0.22)
                          : AppColors.hex1b1e27,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isHighlighted
                            ? AppColors.blue.withValues(alpha: 0.75)
                            : isOwnMessage
                            ? AppColors.secondaryColor.withValues(alpha: 0.45)
                            : AppColors.textPrimary.withValues(alpha: 0.06),
                      ),
                      boxShadow: isHighlighted
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: 0.22),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppTextView.body2(
                          message.sender.name,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(height: 8),
                        if (message.replyTo != null) ...<Widget>[
                          _ReplyPreviewCard(
                            replyTo: message.replyTo!,
                            users: controller.users,
                            isOwnMessage: isOwnMessage,
                            onTap: () =>
                                onReplyPreviewTap(message.replyTo!.messageId),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (message.hasMedia) ...<Widget>[
                          _ChatMessageMediaStrip(
                            attachments: message.attachments,
                            onOpenAttachment: (index) =>
                                _openMediaViewer(context, index),
                          ),
                          if (message.hasText) const SizedBox(height: 10),
                        ],
                        if (message.hasText)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ChatMentionText(
                                text: message.message,
                                users: controller.users,
                                defaultStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                ),
                              ),
                              KaizengramTextLinkPreview(text: message.message),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isOwnMessage) ...<Widget>[
            const SizedBox(width: 12),
            ChatUserInitialAvatar(
              label: kaizengramChatInitialFor(message.sender.name),
              accentColor: accentColor,
            ),
          ],
        ],
      ),
    );
  }

  void _openMediaViewer(BuildContext context, int initialIndex) {
    if (message.attachments.isEmpty) {
      return;
    }

    final selectedAttachment = message.attachments[initialIndex];

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramFullScreenAttachmentView(
          attachments: message.attachments,
          initialIndex: initialIndex,
          autoPlayInitialVideo: selectedAttachment.isVideo,
        ),
      ),
    );
  }

  Future<void> _showMessageActions(
    BuildContext context,
    Offset globalPosition,
    KaizengramChatController controller,
  ) async {
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (overlayBox is! RenderBox) {
      return;
    }

    final selectedAction = await showMenu<_MessageAction>(
      context: context,
      color: AppColors.surfaceDark,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: const <PopupMenuEntry<_MessageAction>>[
        PopupMenuItem<_MessageAction>(
          value: _MessageAction.reply,
          child: _PopupMenuLabel(title: AppStrings.actionReply),
        ),
      ],
    );

    if (selectedAction == _MessageAction.reply) {
      controller.startReply(message);
    }
  }
}

enum _MessageAction { reply }

class _ReplyPreviewCard extends StatelessWidget {
  const _ReplyPreviewCard({
    required this.replyTo,
    required this.users,
    required this.isOwnMessage,
    required this.onTap,
  });

  final KaizengramChatReplyPreview replyTo;
  final List<KaizengramChatUser> users;
  final bool isOwnMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: isOwnMessage
                ? AppColors.hex332a2d3d
                : AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppTextView.body3(
                        replyTo.senderName,
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 3),
                      ChatMentionText(
                        text: replyTo.message,
                        users: users,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        defaultStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupMenuLabel extends StatelessWidget {
  const _PopupMenuLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppTextView.body2(
      title,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }
}

class _ChatMessageMediaStrip extends StatelessWidget {
  const _ChatMessageMediaStrip({
    required this.attachments,
    required this.onOpenAttachment,
  });

  final List<KaizengramMessageAttachment> attachments;
  final ValueChanged<int> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    if (attachments.length == 1) {
      return _ChatMessageMediaCard(
        attachment: attachments.first,
        height: 180,
        onOpen: () => onOpenAttachment(0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width * 0.68;

        if (attachments.length <= kaizengramMessageAttachmentLimit) {
          const maxSquareSide = 96.0;
          var squareSide =
              (availableWidth - (spacing * (attachments.length - 1))) /
              attachments.length;
          if (squareSide > maxSquareSide) {
            squareSide = maxSquareSide;
          }

          return SizedBox(
            height: squareSide,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(attachments.length * 2 - 1, (
                index,
              ) {
                if (index.isOdd) {
                  return const SizedBox(width: spacing);
                }

                final attachmentIndex = index ~/ 2;
                return _ChatMessageMediaCard(
                  attachment: attachments[attachmentIndex],
                  height: squareSide,
                  width: squareSide,
                  onOpen: () => onOpenAttachment(attachmentIndex),
                );
              }),
            ),
          );
        }

        var squareSide = (availableWidth - spacing) / 2;
        if (squareSide > 120) {
          squareSide = 120;
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List<Widget>.generate(attachments.length, (index) {
              return _ChatMessageMediaCard(
                attachment: attachments[index],
                height: squareSide,
                width: squareSide,
                onOpen: () => onOpenAttachment(index),
              );
            }),
          ),
        );
      },
    );
  }
}

class _ChatMessageMediaCard extends StatelessWidget {
  const _ChatMessageMediaCard({
    required this.attachment,
    required this.height,
    this.width,
    required this.onOpen,
  });

  final KaizengramMessageAttachment attachment;
  final double height;
  final double? width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final mediaChild = attachment.isPdf
        ? _ChatMessagePdfCard(
            attachment: attachment,
            width: width,
            height: height,
            onOpen: onOpen,
          )
        : attachment.isVideo
        ? ChatVideoPreview(
            videoPath: attachment.path,
            maxHeight: height,
            autoPlay: false,
            playButtonSize: width == null ? 54 : 40,
            playIconSize: width == null ? 30 : 20,
            onTapOverride: width == null ? null : onOpen,
            onOpenFullScreen: onOpen,
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: attachment.isNetworkPath
                  ? Image.network(
                      attachment.path,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const _ChatMessageMediaFallback(),
                    )
                  : Image.file(
                      File(attachment.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const _ChatMessageMediaFallback(),
                    ),
            ),
          );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.hex111317,
          child: mediaChild,
        ),
      ),
    );
  }
}

class _ChatMessagePdfCard extends StatelessWidget {
  const _ChatMessagePdfCard({
    required this.attachment,
    required this.height,
    this.width,
    required this.onOpen,
  });

  final KaizengramMessageAttachment attachment;
  final double height;
  final double? width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? height;
    final showLabel = resolvedWidth >= 72 && height >= 72;
    final compactLayout = resolvedWidth < 96 || height < 96;
    final iconContainerSize = compactLayout ? 30.0 : 42.0;
    final iconSize = compactLayout ? 18.0 : 24.0;
    final edgePadding = compactLayout ? 8.0 : 14.0;
    final gap = compactLayout ? 6.0 : 10.0;
    final fileName = CustomFunctions.fileNameFromPath(
      attachment.path,
      fallback: AppStrings.documentMessageLabel,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(edgePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.secondaryColor,
                  size: iconSize,
                ),
              ),
              if (showLabel) ...<Widget>[
                SizedBox(height: gap),
                Text(
                  fileName,
                  maxLines: compactLayout ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: compactLayout ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    height: compactLayout ? 1.2 : 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageMediaFallback extends StatelessWidget {
  const _ChatMessageMediaFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
