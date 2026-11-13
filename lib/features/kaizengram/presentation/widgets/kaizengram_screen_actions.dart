part of 'package:sparrowkaizen/features/kaizengram/presentation/pages/kaizengram_screen.dart';

extension _KaizenGramViewStateActions on _KaizenGramViewState {
  Future<void> _openNotifications(BuildContext context) async {
    final selectedNotification = await Navigator.of(context)
        .push<KaizengramNotificationItem>(
          MaterialPageRoute<KaizengramNotificationItem>(
            builder: (_) => ChangeNotifierProvider<KaizengramController>.value(
              value: context.read<KaizengramController>(),
              child: const KaizengramNotificationsScreen(),
            ),
          ),
        );

    if (!context.mounted || selectedNotification == null) {
      return;
    }

    await _handleNotificationSelection(context, selectedNotification);
  }

  Future<void> _openChat(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramChannelsScreen(controller: _chatController),
      ),
    );
  }

  Future<void> _openGroups(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const KaizengramGroupsScreen()),
    );
  }

  Future<void> _openChatChannel(BuildContext context, String channelName) {
    _chatController.selectChannel(channelName);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramChatScreen(controller: _chatController),
      ),
    );
  }

  Future<void> _sharePost(BuildContext context, KaizengramFeedItem post) async {
    final groupDestinations = KaizengramGroupsScreen.shareDestinations;
    final destination = await showModalBottomSheet<KaizengramShareDestination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareKaizengramPostBottomSheet(
        controller: _chatController,
        groupDestinations: groupDestinations,
      ),
    );

    if (destination == null || !context.mounted) {
      return;
    }

    if (destination.type == KaizengramShareDestinationType.group) {
      final targetGroup = groupDestinations
          .cast<KaizengramGroupShareDestination?>()
          .firstWhere(
            (group) => group?.id == destination.groupId,
            orElse: () => null,
          );
      if (targetGroup == null) {
        return;
      }

      KaizengramGroupsScreen.sharePostToGroup(
        groupId: targetGroup.id,
        authorName: context.read<KaizengramController>().currentUserDisplayName,
        authorAvatarUrl: _sharedGroupAuthorAvatar(
          context.read<KaizengramController>(),
        ),
        authorRole: AppStrings.groupMemberRole,
        content: _buildSharedGroupPostContent(post),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppStrings.sharePostToGroupMessage(targetGroup.name)),
          ),
        );

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              KaizengramGroupsScreen(initialGroupId: targetGroup.id),
        ),
      );
      return;
    }

    final conversation = destination.conversation;
    if (conversation == null) {
      return;
    }

    final didSend = _chatController.sendPresetMessage(
      conversation: conversation,
      message: _buildSharedPostMessage(post),
    );
    if (!didSend || !context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KaizengramChatScreen(controller: _chatController),
      ),
    );
  }

  String _buildSharedPostMessage(KaizengramFeedItem post) {
    final lines = <String>[AppStrings.sharePostOriginLabel, post.title.trim()];
    final contextLine = _buildSharedPostContextLine(post);
    if (contextLine != null) {
      lines.add(contextLine);
    }

    final summary = _sharedPostSummary(post);
    if (summary != null) {
      lines
        ..add('')
        ..add(summary);
    }

    final shareableLinks = _shareableLinksForPost(post);
    if (shareableLinks.isNotEmpty) {
      lines.add('');
      for (final link in shareableLinks) {
        lines.add('${AppStrings.sharePostLinkLabel}: $link');
      }
    }

    return lines.join('\n');
  }

  String _buildSharedGroupPostContent(KaizengramFeedItem post) {
    final lines = <String>[
      AppStrings.sharedFromKaizengramLabel,
      post.title.trim(),
    ];
    final contextLine = _buildSharedPostContextLine(post);
    if (contextLine != null) {
      lines.add(contextLine);
    }

    final summary = _sharedPostSummary(post);
    if (summary != null) {
      lines
        ..add('')
        ..add(summary);
    }

    return lines.join('\n');
  }

  String _sharedGroupAuthorAvatar(KaizengramController controller) {
    final imageUrl = controller.currentUserImageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl;
    }

    return 'https://i.pravatar.cc/150?u=${Uri.encodeComponent(controller.currentUserDisplayName)}';
  }

  String? _buildSharedPostContextLine(KaizengramFeedItem post) {
    final parts = <String>[];
    final seatProfile = post.seatProfile.trim();
    final title = post.title.trim();
    final status = post.status?.trim();
    final dueBy = post.dueBy?.trim();

    if (seatProfile.isNotEmpty && seatProfile != title) {
      parts.add(seatProfile);
    }

    if (status != null && status.isNotEmpty) {
      parts.add(status);
    } else if (dueBy != null && dueBy.isNotEmpty) {
      parts.add(dueBy);
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }

  String? _sharedPostSummary(KaizengramFeedItem post) {
    final description = _resolvedPostDescription(post)?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }

    const maxLength = 180;
    if (description.length <= maxLength) {
      return description;
    }

    return '${description.substring(0, maxLength).trimRight()}...';
  }

  List<String> _shareableLinksForPost(KaizengramFeedItem post) {
    final links = <String>[];
    final previewCandidates = <String?>[
      _buildTrackAssignmentShareUrl(post.trackAssignmentUuid),
      post.documentPreviewUrl,
      post.feedVideoUrl,
      post.feedImageUrl,
    ];

    for (final candidate in previewCandidates) {
      final resolvedLink = candidate == null
          ? null
          : CustomFunctions.resolveNetworkUrl(candidate);
      if (resolvedLink == null || links.contains(resolvedLink)) {
        continue;
      }

      links.add(resolvedLink);
    }

    return List<String>.unmodifiable(links);
  }

  String? _buildTrackAssignmentShareUrl(String? rawTrackAssignmentUuid) {
    final trackAssignmentUuid = rawTrackAssignmentUuid?.trim();
    if (trackAssignmentUuid == null || trackAssignmentUuid.isEmpty) {
      return null;
    }

    final apiUri = Uri.tryParse(ApiEndPoints.baseUrl);
    final scheme = apiUri?.scheme.isNotEmpty == true ? apiUri!.scheme : 'https';
    final host = _shareableTrackHost(apiUri?.host);
    return Uri(
      scheme: scheme,
      host: host,
      pathSegments: <String>['ltc', 'assigned-track', trackAssignmentUuid],
    ).toString();
  }

  String _shareableTrackHost(String? apiHost) {
    switch (apiHost?.toLowerCase()) {
      case 'dev-api.kaizenteams.ai':
      case 'dev.kaizenteams.ai':
        return 'dev.kaizenteams.ai';
      case 'api.kaizenteams.ai':
        return 'api.kaizenteams.ai';
      default:
        return 'dev.kaizenteams.ai';
    }
  }

  Future<void> _handleComposeSourceTap(BuildContext context) async {
    if (_isPickingComposeImage || _isPickingComposeAttachment) {
      return;
    }

    final selectedOption = await _showComposeSourceOptions(context);
    if (!mounted || selectedOption == null) {
      return;
    }

    switch (selectedOption) {
      case _ComposePostSourceOption.image:
        await _pickComposeImagesAndOpenSheet();
        return;
      case _ComposePostSourceOption.attachment:
        await _pickComposeAttachmentsAndOpenSheet();
        return;
    }
  }

  Future<_ComposePostSourceOption?> _showComposeSourceOptions(
    BuildContext context,
  ) {
    if (!context.mounted) {
      return Future<_ComposePostSourceOption?>.value(null);
    }

    return showModalBottomSheet<_ComposePostSourceOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposePostSourceSheet(),
    );
  }

  Future<void> _pickComposeImagesAndOpenSheet() async {
    if (_isPickingComposeImage || _isPickingComposeAttachment) {
      return;
    }

    _setViewState(() {
      _isPickingComposeImage = true;
    });

    try {
      final pickedAttachments =
          await KaizengramMessageAttachmentPicker.pickImages(availableSlots: 1);
      if (pickedAttachments.isEmpty || !mounted) {
        return;
      }

      await _openCreatePostSheet(
        context,
        initialAttachments: pickedAttachments,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(AppStrings.kaizengramErrorPickImageFailed),
          ),
        );
    } finally {
      if (mounted) {
        _setViewState(() {
          _isPickingComposeImage = false;
        });
      } else {
        _isPickingComposeImage = false;
      }
    }
  }

  Future<void> _pickComposeAttachmentsAndOpenSheet() async {
    if (_isPickingComposeImage || _isPickingComposeAttachment) {
      return;
    }

    _setViewState(() {
      _isPickingComposeAttachment = true;
    });

    try {
      final pickedAttachments =
          await KaizengramMessageAttachmentPicker.pickPdfs(availableSlots: 1);
      if (pickedAttachments.isEmpty || !mounted) {
        return;
      }

      await _openCreatePostSheet(
        context,
        initialAttachments: pickedAttachments,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(AppStrings.kaizengramErrorPickAttachmentFailed),
          ),
        );
    } finally {
      if (mounted) {
        _setViewState(() {
          _isPickingComposeAttachment = false;
        });
      } else {
        _isPickingComposeAttachment = false;
      }
    }
  }

  Future<void> _openCreatePostSheet(
    BuildContext context, {
    List<KaizengramMessageAttachment> initialAttachments =
        const <KaizengramMessageAttachment>[],
  }) {
    final controller = context.read<KaizengramController>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => AppKeyboardBottomSheetSurface(
        color: AppColors.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: _CreateSocialPostBottomSheet(
          authorName: controller.currentUserDisplayName,
          avatarImagePath: controller.currentUserImagePath,
          avatarUrl: controller.currentUserImageUrl,
          initialAttachments: initialAttachments,
          onPostSubmitted: (message, attachments) {
            controller.createCurrentUserSocialPost(
              message: message,
              attachments: attachments,
            );
            if (controller.useSeparateFeedDemo && _tabController.index != 0) {
              _tabController.animateTo(0);
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleNotificationSelection(
    BuildContext context,
    KaizengramNotificationItem notification,
  ) async {
    final controller = context.read<KaizengramController>();
    final post = controller.postById(notification.post.id);
    if (post == null) {
      return;
    }

    await _focusPostInFeed(controller, post);
    if (!context.mounted) {
      return;
    }

    if (notification.type == KaizengramNotificationType.commented) {
      await _showCommentsThreadSheet(
        context,
        post,
        highlightCommentId: notification.targetCommentId,
      );
    }
  }

  Future<void> _focusPostInFeed(
    KaizengramController controller,
    KaizengramFeedItem post,
  ) async {
    if (!controller.useSeparateFeedDemo) {
      await _scrollToPost(
        controller: controller,
        posts: controller.posts,
        post: post,
        scrollController: _mixedFeedScrollController,
      );
      return;
    }

    _tabController.animateTo(
      controller.tabIndexForCategory(post.resolvedPostCategory),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }

    await _scrollToPost(
      controller: controller,
      posts: controller.postsForCategory(post.resolvedPostCategory),
      post: post,
      scrollController: _scrollControllerFor(post.resolvedPostCategory),
    );
  }

  ScrollController _scrollControllerFor(KaizengramPostCategory category) {
    switch (category) {
      case KaizengramPostCategory.audit:
        return _auditFeedScrollController;
      case KaizengramPostCategory.learningCompliance:
        return _learningFeedScrollController;
      case KaizengramPostCategory.documentCompliance:
        return _documentFeedScrollController;
    }
  }

  Future<void> _scrollToPost({
    required KaizengramController controller,
    required List<KaizengramFeedItem> posts,
    required KaizengramFeedItem post,
    required ScrollController scrollController,
  }) async {
    final postIndex = posts.indexWhere((item) => item.id == post.id);
    if (postIndex == -1) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !scrollController.hasClients) {
      return;
    }

    final insertedCardOffset =
        post.resolvedPostCategory == KaizengramPostCategory.audit
        ? controller.weeklyCheckInSocialCardCountBefore(postIndex) * 196
        : 0;
    final estimatedOffset =
        ((controller.estimatedPostExtent(post) * postIndex) +
                insertedCardOffset)
            .clamp(0.0, scrollController.position.maxScrollExtent)
            .toDouble();
    scrollController.jumpTo(estimatedOffset);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) {
      return;
    }

    final targetContext = _postKeyFor(post.id).currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.04,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openComments(
    BuildContext context,
    KaizengramFeedItem post,
  ) async {
    if (post.resolvedPostCategory == KaizengramPostCategory.audit &&
        post.auditMediaItems.isNotEmpty) {
      await _showAuditMediaSheet(context, post);
      return;
    }

    await _showCommentsThreadSheet(context, post);
  }

  Future<void> _openFallbackComments(
    BuildContext context,
    KaizengramFeedItem post,
  ) async {
    if (post.resolvedPostCategory == KaizengramPostCategory.audit) {
      final noImageThreadId = '${post.id}-thread-no-image';
      final noImageThreadItem = _buildAuditThreadItems(post)
          .cast<KaizengramAuditMediaItem?>()
          .firstWhere(
            (mediaItem) => mediaItem?.id == noImageThreadId,
            orElse: () => null,
          );

      if (noImageThreadItem != null) {
        await _showCommentsThreadSheet(
          context,
          post,
          selectedAuditMediaItem: noImageThreadItem,
        );
        return;
      }
    }

    await _showCommentsThreadSheet(context, post);
  }

  Future<void> _showCommentsThreadSheet(
    BuildContext context,
    KaizengramFeedItem post, {
    KaizengramAuditMediaItem? selectedAuditMediaItem,
    String? highlightCommentId,
  }) {
    final comments = context.read<KaizengramController>().commentThreadForPost(
      post,
      selectedAuditMediaItem: selectedAuditMediaItem,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CommentsThreadBottomSheet(
        post: post,
        comments: comments,
        selectedAuditMediaItem: selectedAuditMediaItem,
        highlightCommentId: highlightCommentId,
      ),
    );
  }

  Future<void> _showAuditMediaSheet(
    BuildContext context,
    KaizengramFeedItem post,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => KaizengramAuditMediaBottomSheet(
        post: post,
        threadItems: _buildAuditThreadItems(post),
        onMediaTap: (selectedMediaItem) {
          Navigator.of(sheetContext).pop();
          Future<void>.delayed(Duration.zero, () {
            if (!context.mounted) {
              return;
            }

            _showCommentsThreadSheet(
              context,
              post,
              selectedAuditMediaItem: selectedMediaItem,
            );
          });
        },
      ),
    );
  }

  Future<void> _openSocialCommentsSheet(
    BuildContext context,
    KaizengramController controller,
    KaizengramSocialPost post,
    String loggedInUserName,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => ChangeNotifierProvider<KaizengramController>.value(
        value: controller,
        child: AppKeyboardBottomSheetSurface(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: _SocialPostCommentsBottomSheet(
            post: post,
            loggedInUserName: loggedInUserName,
          ),
        ),
      ),
    );
  }

  Future<void> _handlePowerListTap(
    BuildContext context,
    _PowerListEntry entry,
  ) async {
    switch (entry.destination) {
      case _PowerListDestination.learningCompliance:
        await AppRouter.pushNamed<void>(context, AppRouter.learningTracks);
        return;
      case _PowerListDestination.documentCompliance:
        await AppRouter.pushNamed<void>(context, AppRouter.compliance);
        return;
      case _PowerListDestination.audit:
        await AppRouter.pushNamed<void>(context, AppRouter.checkIn);
        return;
    }
  }

  Future<void> _openPost(BuildContext context, KaizengramFeedItem post) async {
    switch (post.type) {
      case KaizengramFeedType.learningCompliance:
        if (CustomFunctions.isDeadlineOverdue(post.rawDeadline)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(AppStrings.kaizengramErrorCannotAccessCompliance),
              ),
            );
          return;
        }

        if (post.status != null &&
            CustomFunctions.isCancelledStatus(post.status!)) {
          CustomFunctions.showCustomAlert(
            context,
            AppStrings.kaizengramErrorRestrictedTitle,
            AppStrings.kaizengramErrorCannotAccessCompliance,
          );
          return;
        }

        final trackAssignmentUuid = post.trackAssignmentUuid?.trim();
        if (trackAssignmentUuid == null || trackAssignmentUuid.isEmpty) {
          return;
        }
        await AppRouter.pushNamed<void>(
          context,
          AppRouter.complianceTracks,
          arguments: ComplianceTracksRouteArgs(
            trackAssignmentUuid: trackAssignmentUuid,
            title: post.title,
            showCertificate: CustomFunctions.isPassedStatus(post.status),
          ),
        );
        return;
      case KaizengramFeedType.documentCompliance:
        await AppRouter.pushNamed<void>(context, AppRouter.compliance);
        return;
    }
  }
}
