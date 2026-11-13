part of 'package:sparrowkaizen/features/kaizengram/presentation/pages/kaizengram_screen.dart';

class _PowerListCard extends StatelessWidget {
  const _PowerListCard({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onEntryTap,
  });

  final String title;
  final String subtitle;
  final List<_PowerListEntry> entries;
  final Future<void> Function(BuildContext context, _PowerListEntry entry)
  onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.hex20253a,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.secondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body1(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 2),
                    AppTextView.body2(
                      subtitle,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (entry) => _PowerListRow(
              entry: entry,
              onTap: () => onEntryTap(context, entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerListRow extends StatelessWidget {
  const _PowerListRow({required this.entry, required this.onTap});

  final _PowerListEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: entry.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: entry.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body1(
                      entry.title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body2(
                      entry.value,
                      color: AppColors.textSecondary,
                      fontSize: 12,
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
  }
}

class _WeeklyCheckInSocialTextCard extends StatelessWidget {
  const _WeeklyCheckInSocialTextCard({
    required this.post,
    required this.loggedInUserName,
    required this.onInlineCommentSend,
    required this.onCommentTap,
  });

  final KaizengramSocialPost post;
  final String loggedInUserName;
  final void Function(
    String message,
    List<KaizengramMessageAttachment> attachments,
  )
  onInlineCommentSend;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    final previewComment = post.comments.isEmpty ? null : post.comments.last;
    final previewReply =
        previewComment == null || previewComment.replies.isEmpty
        ? null
        : previewComment.replies.last;
    final hasMessage = post.message.trim().isNotEmpty;
    final hasLinkPreview = kaizengramFirstLinkInText(post.message) != null;
    final attachments = post.resolvedAttachments;
    final hasAttachments = attachments.isNotEmpty;
    final avatarImageProvider = _resolvedAvatarImageProvider(
      imagePath: post.avatarImagePath,
      imageUrl: post.avatarUrl,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.hex20253a,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.surfaceDark3,
                backgroundImage: avatarImageProvider,
                child: avatarImageProvider != null
                    ? null
                    : AppTextView.body3(
                        _initialsFromName(post.authorName),
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body1(
                      post.authorName,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 2),
                    AppTextView.body2(
                      '${post.channelName} • ${post.timeLabel}',
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasMessage) ...<Widget>[
            const SizedBox(height: 14),
            ChatMentionText(
              text: post.message,
              users: const <KaizengramChatUser>[],
              defaultStyle: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (hasLinkPreview) ...<Widget>[
            const SizedBox(height: 10),
            KaizengramTextLinkPreview(text: post.message, topSpacing: 0),
          ],
          if (hasAttachments) ...<Widget>[
            SizedBox(height: hasMessage || hasLinkPreview ? 14 : 12),
            _SocialPostAttachmentPreview(attachments: attachments),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.favorite_border_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: onCommentTap,
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          if (previewComment != null) ...<Widget>[
            const SizedBox(height: 14),
            _SocialPostCommentPreview(
              comment: previewComment,
              reply: previewReply,
              onTap: onCommentTap,
            ),
          ],
          const SizedBox(height: 12),
          _InlineSocialCommentComposer(
            loggedInUserName: loggedInUserName,
            onSend: onInlineCommentSend,
          ),
        ],
      ),
    );
  }
}

class _SocialPostAttachmentPreview extends StatelessWidget {
  const _SocialPostAttachmentPreview({required this.attachments});

  final List<KaizengramMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    if (attachments.length == 1) {
      final selectedAttachment = attachments.first;
      return _CommentAttachmentPreviewCard(
        attachment: selectedAttachment,
        height: selectedAttachment.isPdf ? 104 : 220,
        onOpen: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => KaizengramFullScreenAttachmentView(
                attachments: attachments,
                initialIndex: 0,
                autoPlayInitialVideo: selectedAttachment.isVideo,
              ),
            ),
          );
        },
      );
    }

    return _CommentAttachmentPreviewStrip(
      attachments: attachments,
      onOpenAttachment: (index) {
        final selectedAttachment = attachments[index];
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => KaizengramFullScreenAttachmentView(
              attachments: attachments,
              initialIndex: index,
              autoPlayInitialVideo: selectedAttachment.isVideo,
            ),
          ),
        );
      },
    );
  }
}

class _SocialPostCommentPreview extends StatelessWidget {
  const _SocialPostCommentPreview({
    required this.comment,
    required this.reply,
    required this.onTap,
  });

  final KaizengramComment comment;
  final KaizengramComment? reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _CommentAvatar(comment: comment),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: AppTextView.body3(
                                comment.authorName,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AppTextView.body4(
                              comment.timestampLabel,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _CommentMessageText(
                          message: comment.message,
                          attachments: comment.attachments,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (reply != null) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.14),
                          width: 2,
                        ),
                      ),
                    ),
                    child: _ReplyCommentRow(
                      comment: reply!,
                      onReplyTap: (_) => onTap(),
                    ),
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

class _CommentMessageText extends StatelessWidget {
  const _CommentMessageText({
    required this.message,
    required this.style,
    this.attachments = const <KaizengramMessageAttachment>[],
  });

  final String message;
  final TextStyle style;
  final List<KaizengramMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final trimmedMessage = message.trim();
    final hasMessage = trimmedMessage.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasMessage)
          ChatMentionText(
            text: message,
            users: const <KaizengramChatUser>[],
            defaultStyle: style,
          ),
        if (hasMessage) KaizengramTextLinkPreview(text: message),
        if (attachments.isNotEmpty)
          _CommentAttachmentPreviewStrip(
            attachments: attachments,
            onOpenAttachment: (index) {
              final selectedAttachment = attachments[index];
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => KaizengramFullScreenAttachmentView(
                    attachments: attachments,
                    initialIndex: index,
                    autoPlayInitialVideo: selectedAttachment.isVideo,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _InlineSocialCommentComposer extends StatefulWidget {
  const _InlineSocialCommentComposer({
    required this.loggedInUserName,
    required this.onSend,
  });

  final String loggedInUserName;
  final void Function(
    String message,
    List<KaizengramMessageAttachment> attachments,
  )
  onSend;

  @override
  State<_InlineSocialCommentComposer> createState() =>
      _InlineSocialCommentComposerState();
}

class _InlineSocialCommentComposerState
    extends State<_InlineSocialCommentComposer>
    with KaizengramNotifierState<_InlineSocialCommentComposer> {
  late final TextEditingController _controller;
  List<KaizengramMessageAttachment> _draftAttachments =
      <KaizengramMessageAttachment>[];
  bool _isPickingAttachments = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final message = _controller.text.trim();
    if (message.isEmpty && _draftAttachments.isEmpty) {
      return;
    }

    widget.onSend(
      message,
      List<KaizengramMessageAttachment>.unmodifiable(_draftAttachments),
    );
    _controller.clear();
    updateView(() {
      _draftAttachments = <KaizengramMessageAttachment>[];
    });
  }

  Future<void> _pickAttachments() async {
    if (_isPickingAttachments) {
      return;
    }

    final availableSlots =
        kaizengramMessageAttachmentLimit - _draftAttachments.length;
    if (availableSlots <= 0) {
      _showAttachmentSnackBar(AppStrings.mediaLimitError);
      return;
    }

    updateView(() => _isPickingAttachments = true);

    try {
      final source = await KaizengramMessageAttachmentPicker.pickSource(
        context,
      );
      if (!mounted || source == null) {
        return;
      }

      final nextAttachments = await KaizengramMessageAttachmentPicker.pick(
        source: source,
        availableSlots: availableSlots,
        existingPaths: _draftAttachments.map((attachment) => attachment.path),
      );
      if (!mounted || nextAttachments.isEmpty) {
        return;
      }

      updateView(() {
        _draftAttachments = <KaizengramMessageAttachment>[
          ..._draftAttachments,
          ...nextAttachments,
        ];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAttachmentSnackBar(AppStrings.pickMediaError);
    } finally {
      if (mounted) {
        updateView(() => _isPickingAttachments = false);
      }
    }
  }

  void _removeAttachment(String attachmentPath) {
    updateView(() {
      _draftAttachments = _draftAttachments
          .where((attachment) => attachment.path != attachmentPath)
          .toList(growable: false);
    });
  }

  void _openAttachmentViewer(int index) {
    if (_draftAttachments.isEmpty) {
      return;
    }

    final selectedAttachment = _draftAttachments[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramFullScreenAttachmentView(
          attachments: _draftAttachments,
          initialIndex: index,
          autoPlayInitialVideo: selectedAttachment.isVideo,
        ),
      ),
    );
  }

  void _showAttachmentSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final canSend =
          _controller.text.trim().isNotEmpty || _draftAttachments.isNotEmpty;
      final draftText = _controller.text;
      final hasLinkPreview = kaizengramFirstLinkInText(draftText) != null;
      final currentUserComment = KaizengramComment(
        id: 'social-comment-preview-${widget.loggedInUserName}',
        authorName: widget.loggedInUserName,
        message: '',
        timestampLabel: '',
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_draftAttachments.isNotEmpty) ...<Widget>[
            _CommentAttachmentPreviewStrip(
              attachments: _draftAttachments,
              removable: true,
              onOpenAttachment: _openAttachmentViewer,
              onRemoveAttachment: _removeAttachment,
            ),
            const SizedBox(height: 10),
          ],
          if (hasLinkPreview) ...<Widget>[
            KaizengramTextLinkPreview(text: draftText, topSpacing: 0),
            const SizedBox(height: 10),
          ],
          Row(
            children: <Widget>[
              _CommentAvatar(comment: currentUserComment),
              const SizedBox(width: 10),
              _CommentComposerActionButton(
                onTap: _isPickingAttachments ? null : _pickAttachments,
                icon: Icons.attach_file_rounded,
                isBusy: _isPickingAttachments,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: _commentComposerControlHeight,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark3.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(
                      _commentComposerCornerRadius,
                    ),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    textAlignVertical: TextAlignVertical.center,
                    cursorHeight: 15,
                    cursorColor: AppColors.textPrimary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: AppStrings.commentAsUser(
                        widget.loggedInUserName,
                      ),
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => notifyView(),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CommentComposerSendButton(
                onTap: canSend ? _handleSend : null,
                canSend: canSend,
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _FeedStateMessage extends StatelessWidget {
  const _FeedStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 24),
      child: AppTextView.body1(
        message,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FeedTabList extends StatelessWidget {
  const _FeedTabList({
    required this.posts,
    required this.onRefresh,
    required this.scrollController,
    required this.itemBuilder,
    this.children,
  });

  final List<KaizengramFeedItem> posts;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final Widget Function(KaizengramFeedItem post) itemBuilder;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.secondaryColor,
      onRefresh: onRefresh,
      child: children != null
          ? ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              children: children!,
            )
          : posts.isEmpty
          ? ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: const <Widget>[
                _FeedStateMessage(
                  message: 'No feed items are available in this tab.',
                ),
              ],
            )
          : ListView.separated(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                return itemBuilder(posts[index]);
              },
            ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.stories, required this.onStoryTap});

  final List<_StoryEntry> stories;
  final ValueChanged<_StoryEntry> onStoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.64),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final story = stories[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onStoryTap(story),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(2.4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.hexf9ce34,
                              AppColors.hexee2a7b,
                              AppColors.hex6228d7,
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.surfaceDark,
                          child: _StoryAvatar(story: story),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 16,
                        child: AppTextView.body2(
                          story.name,
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.story});

  final _StoryEntry story;

  @override
  Widget build(BuildContext context) {
    final imagePath = story.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      final networkUrl = CustomFunctions.resolveNetworkUrl(imagePath);
      final ImageProvider<Object> imageProvider = networkUrl != null
          ? NetworkImage(networkUrl)
          : FileImage(File(imagePath));
      return CircleAvatar(radius: 25, backgroundImage: imageProvider);
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: AppColors.surfaceDark3,
      child: Icon(
        story.isChannel ? Icons.tag_rounded : Icons.image_outlined,
        color: story.isChannel
            ? AppColors.secondaryColor
            : AppColors.textSecondary,
        size: story.isChannel ? 22 : 20,
      ),
    );
  }
}

enum _StoryEntryKind { feed, channel }

class _StoryEntry {
  const _StoryEntry.feed({required this.id, required this.name, this.imagePath})
    : kind = _StoryEntryKind.feed,
      channelName = null;

  const _StoryEntry.channel({
    required this.id,
    required this.name,
    required this.channelName,
    this.imagePath,
  }) : kind = _StoryEntryKind.channel;

  final String id;
  final String name;
  final String? imagePath;
  final String? channelName;
  final _StoryEntryKind kind;

  bool get isChannel => kind == _StoryEntryKind.channel;
}

enum _ComposePostSourceOption { image, attachment }

class _KaizengramComposeHeader extends StatelessWidget {
  const _KaizengramComposeHeader({
    required this.displayName,
    this.imagePath,
    required this.imageUrl,
    required this.isPickingSource,
    required this.onTap,
    required this.onSourceTap,
  });

  final String displayName;
  final String? imagePath;
  final String? imageUrl;
  final bool isPickingSource;
  final VoidCallback onTap;
  final VoidCallback onSourceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ComposerHeaderAvatar(
                displayName: displayName,
                imagePath: imagePath,
                imageUrl: imageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark3.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: AppTextView.body2(
                        AppStrings.kaizengramComposePrompt,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ComposeHeaderIconButton(
                tooltip: AppStrings.kaizengramComposeSourceTitle,
                icon: Icons.attach_file_rounded,
                isBusy: isPickingSource,
                onTap: isPickingSource ? null : onSourceTap,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextView.body4(
            AppStrings.kaizengramComposeSubtitle,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ComposeHeaderIconButton extends StatelessWidget {
  const _ComposeHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isBusy = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark3.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: isBusy
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                : Icon(icon, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _ComposePostSourceSheet extends StatelessWidget {
  const _ComposePostSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey1,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppTextView.body1(
            AppStrings.kaizengramComposeSourceTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          const SizedBox(height: 14),
          _ComposePostSourceTile(
            icon: Icons.photo_library_outlined,
            title: AppStrings.kaizengramComposeActionImage,
            subtitle: AppStrings.kaizengramComposeActionImageHint,
            onTap: () {
              Navigator.of(context).pop(_ComposePostSourceOption.image);
            },
          ),
          const SizedBox(height: 12),
          _ComposePostSourceTile(
            icon: Icons.attach_file_rounded,
            title: AppStrings.kaizengramComposeActionAttachment,
            subtitle: AppStrings.kaizengramComposeActionAttachmentHint,
            onTap: () {
              Navigator.of(context).pop(_ComposePostSourceOption.attachment);
            },
          ),
        ],
      ),
    );
  }
}

class _ComposePostSourceTile extends StatelessWidget {
  const _ComposePostSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark3,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.secondaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body2(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body4(
                      subtitle,
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

class _ComposerHeaderAvatar extends StatelessWidget {
  const _ComposerHeaderAvatar({
    required this.displayName,
    this.imagePath,
    required this.imageUrl,
  });

  final String displayName;
  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(displayName);
    final imageProvider = _resolvedAvatarImageProvider(
      imagePath: imagePath,
      imageUrl: imageUrl,
    );

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.16),
      backgroundImage: imageProvider,
      child: imageProvider != null
          ? null
          : AppTextView.body3(
              initials.isEmpty ? 'Y' : initials,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
    );
  }
}

String _initialsFromName(String displayName) {
  final initials = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  return initials.isEmpty ? 'Y' : initials;
}

ImageProvider<Object>? _resolvedAvatarImageProvider({
  String? imagePath,
  String? imageUrl,
}) {
  final normalizedImagePath = imagePath?.trim();
  if (normalizedImagePath != null && normalizedImagePath.isNotEmpty) {
    if (CustomFunctions.isAssetImagePath(normalizedImagePath)) {
      return AssetImage(normalizedImagePath);
    }

    final localFile = File(normalizedImagePath);
    if (localFile.existsSync()) {
      return FileImage(localFile);
    }
  }

  final normalizedImageUrl = imageUrl?.trim();
  if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty) {
    final resolvedImageUrl = CustomFunctions.resolveNetworkUrl(
      normalizedImageUrl,
    );
    if (resolvedImageUrl != null) {
      return NetworkImage(resolvedImageUrl);
    }
  }

  if (normalizedImagePath != null && normalizedImagePath.isNotEmpty) {
    final resolvedImagePath = CustomFunctions.resolveNetworkUrl(
      normalizedImagePath,
    );
    if (resolvedImagePath != null) {
      return NetworkImage(resolvedImagePath);
    }
  }

  return null;
}
