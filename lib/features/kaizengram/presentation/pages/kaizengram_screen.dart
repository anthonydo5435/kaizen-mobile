import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../../../routes/app_router.dart';
import '../../../compliance/presentation/widgets/compliance_video_player.dart';
import '../../data/datasources/kaizengram_remote_data_source.dart';
import '../../groups/presentation/pages/kaizengram_groups_screen.dart';
import '../chat/pages/kaizengram_channels_screen.dart';
import '../chat/pages/kaizengram_chat_screen.dart';
import '../chat/providers/kaizengram_chat_controller.dart';
import '../chat/widgets/chat_mention_text.dart';
import '../chat/widgets/chat_video_preview.dart';
import '../chat/widgets/share_post_bottom_sheet.dart';
import '../kaizengram_message_attachment.dart';
import '../providers/kaizengram_controller.dart';
import '../widgets/kaizengram_audit_widgets.dart';
import '../widgets/kaizengram_full_screen_attachment_view.dart';
import '../widgets/kaizengram_link_preview_card.dart';
import '../widgets/kaizengram_link_utils.dart';
import '../widgets/kaizengram_notifier_state.dart';
import '../widgets/kaizengram_screen_common_widgets.dart';
import 'notifications/kaizengram_notifications_screen.dart';

part '../widgets/kaizengram_comment_widgets.dart';
part '../widgets/kaizengram_feed_widgets.dart';
part '../widgets/kaizengram_post_widgets.dart';
part '../widgets/kaizengram_screen_actions.dart';

const double _commentComposerCornerRadius = 12;
const double _commentComposerControlHeight = 48;
const double _commentComposerActionWidth = 48;

class KaizenGramScreen extends StatelessWidget {
  const KaizenGramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appManager = context.watch<AppManager>();
    if (appManager.usesParentApiEndpoints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }

        AppRouter.pushReplacementNamed<void, void>(
          context,
          AppRouter.trainingLibrary,
        );
      });

      return Scaffold(
        backgroundColor: AppColors.mainBg,
        body: Center(child: FastCircularProgressIndicator()),
      );
    }

    return ChangeNotifierProxyProvider<AppManager, KaizengramController>(
      create: (context) => KaizengramController(
        KaizengramRemoteDataSource(),
        currentUser: context.read<AppManager>().currentUser,
      )..initialize(),
      update: (_, appManager, controller) {
        controller!.syncCurrentUser(appManager.currentUser);
        return controller;
      },
      child: const _KaizenGramView(),
    );
  }
}

class _KaizenGramView extends StatefulWidget {
  const _KaizenGramView();

  @override
  State<_KaizenGramView> createState() => _KaizenGramViewState();
}

class _KaizenGramViewState extends State<_KaizenGramView>
    with
        SingleTickerProviderStateMixin,
        KaizengramNotifierState<_KaizenGramView> {
  late final TabController _tabController;
  late final KaizengramChatController _chatController;
  final ScrollController _mixedFeedScrollController = ScrollController();
  final ScrollController _auditFeedScrollController = ScrollController();
  final ScrollController _learningFeedScrollController = ScrollController();
  final ScrollController _documentFeedScrollController = ScrollController();
  final Map<String, GlobalKey> _postKeys = <String, GlobalKey>{};
  var _isPickingComposeImage = false;
  var _isPickingComposeAttachment = false;

  static const List<_PowerListEntry> _powerListEntriesFirstHalf =
      <_PowerListEntry>[
        _PowerListEntry(
          title: AppStrings.kaizengramLearningCompliancesTitle,
          value: AppStrings.kaizengramLearningCompliancesDue,
          icon: Icons.school_rounded,
          accentColor: AppColors.progressColor,
          destination: _PowerListDestination.learningCompliance,
        ),
        _PowerListEntry(
          title: AppStrings.kaizengramDocumentCompliancesTitle,
          value: AppStrings.kaizengramDocumentCompliancesPending,
          icon: Icons.description_rounded,
          accentColor: AppColors.hexffb547,
          destination: _PowerListDestination.documentCompliance,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _chatController = KaizengramChatController();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _tabController.dispose();
    _mixedFeedScrollController.dispose();
    _auditFeedScrollController.dispose();
    _learningFeedScrollController.dispose();
    _documentFeedScrollController.dispose();
    super.dispose();
  }

  static const List<_PowerListEntry> _powerListEntriesSecondHalf =
      <_PowerListEntry>[
        _PowerListEntry(
          title: AppStrings.kaizengramCheckInsTitle,
          value: AppStrings.kaizengramCheckInsActive,
          icon: Icons.fact_check_rounded,
          accentColor: AppColors.hex7ea6ff,
          destination: _PowerListDestination.audit,
        ),
        _PowerListEntry(
          title: AppStrings.kaizengramCheckInReportsTitle,
          value: AppStrings.kaizengramCheckInReportsReady,
          icon: Icons.assignment_turned_in_rounded,
          accentColor: AppColors.hexff7d7d,
          destination: _PowerListDestination.audit,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final controller = context.watch<KaizengramController>();
      final unreadNotificationCount = controller.unreadNotificationCount;

      return DrawerMainScreen(
        title: AppStrings.homeKaizengram,
        selectedMenu: AppMenuType.home,
        appBarActions: _buildAppBarActions(context, unreadNotificationCount),
        child: _buildScreenBody(context, controller),
      );
    });
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    int unreadNotificationCount,
  ) {
    return <Widget>[
      _buildGroupsAction(context),
      _buildChatAction(context),
      _buildNotificationAction(context, unreadNotificationCount),
    ];
  }

  Widget _buildGroupsAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openGroups(context),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.groups_2_rounded),
        ),
      ),
    );
  }

  Widget _buildChatAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openChat(context),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.forum_rounded),
        ),
      ),
    );
  }

  Widget _buildNotificationAction(
    BuildContext context,
    int unreadNotificationCount,
  ) {
    return Padding(
      // The action's inner padding completes the 8-pixel screen inset.
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openNotifications(context),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: KaizengramNotificationActionIcon(
            unreadNotificationCount: unreadNotificationCount,
          ),
        ),
      ),
    );
  }

  Widget _buildScreenBody(
    BuildContext context,
    KaizengramController controller,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.hex252a40, AppColors.hex1b1f31],
        ),
      ),
      child: controller.isLoading
          ? Center(child: FastCircularProgressIndicator())
          : _buildFeedBody(context, controller),
    );
  }

  Widget _buildFeedBody(BuildContext context, KaizengramController controller) {
    return controller.useSeparateFeedDemo
        ? showSeparateFeed(context, controller)
        : showMixedFeed(context, controller);
  }

  Widget showMixedFeed(BuildContext context, KaizengramController controller) {
    return RefreshIndicator(
      color: AppColors.secondaryColor,
      onRefresh: () =>
          context.read<KaizengramController>().initialize(forceRefresh: true),
      child: ListView(
        controller: _mixedFeedScrollController,
        padding: const EdgeInsets.only(bottom: 20),
        children: <Widget>[
          _buildComposeHeader(context, controller),
          _buildStoriesRow(context, controller),
          ..._buildFeedStateChildren(controller),
          ..._buildMixedFeedChildren(context, controller),
        ],
      ),
    );
  }

  Widget showSeparateFeed(
    BuildContext context,
    KaizengramController controller,
  ) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final category = controller.categoryForTabIndex(_tabController.index);
        final posts = controller.postsForCategory(category);

        return _FeedTabList(
          posts: posts,
          onRefresh: () => context.read<KaizengramController>().initialize(
            forceRefresh: true,
          ),
          scrollController: _scrollControllerFor(category),
          itemBuilder: (post) => _buildPostCard(context, controller, post),
          children: _buildSeparateFeedContent(
            context,
            controller,
            posts: posts,
            category: category,
          ),
        );
      },
    );
  }

  List<Widget> _buildSeparateFeedContent(
    BuildContext context,
    KaizengramController controller, {
    required List<KaizengramFeedItem> posts,
    required KaizengramPostCategory category,
  }) {
    final children = <Widget>[
      _buildComposeHeader(context, controller),
      _buildStoriesRow(context, controller),
      _buildFeedTabs(),
      const SizedBox(height: 12),
    ];

    if (controller.errorMessage != null && controller.posts.isEmpty) {
      children.add(
        const _FeedStateMessage(
          message: AppStrings.kaizengramMessageUnableLoadFeed,
        ),
      );
      return children;
    }

    if (controller.posts.isEmpty) {
      children.add(
        const _FeedStateMessage(
          message: AppStrings.kaizengramMessageNoFeedItems,
        ),
      );
      return children;
    }

    if (category == KaizengramPostCategory.audit) {
      children.addAll(
        _buildWeeklyCheckInFeedChildren(context, controller, posts),
      );
      return children;
    }

    if (posts.isEmpty) {
      children.add(
        const _FeedStateMessage(
          message: 'No feed items are available in this tab.',
        ),
      );
      return children;
    }

    children.addAll(
      posts.map((post) => _buildPostCard(context, controller, post)),
    );
    return children;
  }

  Widget _buildFeedTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(7, 12, 7, 0),
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.fill,
        labelPadding: const EdgeInsets.only(top: 3),
        indicator: BoxDecoration(
          color: AppColors.secondaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.mainBg,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: const <Widget>[
          SizedBox(
            height: 32,
            child: Tab(text: AppStrings.kaizengramTabWeeklyCheckIn),
          ),
          SizedBox(
            height: 32,
            child: Tab(text: AppStrings.kaizengramTabLearning),
          ),
          SizedBox(
            height: 32,
            child: Tab(text: AppStrings.kaizengramTabDocument),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklyCheckInFeedChildren(
    BuildContext context,
    KaizengramController controller,
    List<KaizengramFeedItem> posts,
  ) {
    final widgets = <Widget>[];
    for (final socialPost in controller.socialPosts) {
      widgets.add(_buildSocialPostCard(context, controller, socialPost));
    }
    var socialPostIndex = 0;

    for (var index = 0; index < posts.length; index++) {
      widgets.add(_buildPostCard(context, controller, posts[index]));

      final afterPostCount = index + 1;
      final shouldInsertSocialPost =
          socialPostIndex < controller.seededWeeklyCheckInSocialPosts.length &&
          controller.weeklyCheckInSocialInsertAfterCounts.contains(
            afterPostCount,
          );
      if (!shouldInsertSocialPost) {
        continue;
      }

      final socialPost =
          controller.seededWeeklyCheckInSocialPosts[socialPostIndex];
      widgets.add(_buildSocialPostCard(context, controller, socialPost));
      socialPostIndex++;
    }

    return widgets;
  }

  Widget _buildComposeHeader(
    BuildContext context,
    KaizengramController controller,
  ) {
    return _KaizengramComposeHeader(
      displayName: controller.currentUserDisplayName,
      imagePath: controller.currentUserImagePath,
      imageUrl: controller.currentUserImageUrl,
      isPickingSource: _isPickingComposeImage || _isPickingComposeAttachment,
      onTap: () => _openCreatePostSheet(context),
      onSourceTap: () => _handleComposeSourceTap(context),
    );
  }

  Widget _buildStoriesRow(
    BuildContext context,
    KaizengramController controller,
  ) {
    return ListenableBuilder(
      listenable: _chatController,
      builder: (context, _) {
        return _StoriesRow(
          stories: _storyEntries(controller),
          onStoryTap: (story) => _handleStoryTap(context, controller, story),
        );
      },
    );
  }

  List<_StoryEntry> _storyEntries(KaizengramController controller) {
    final channelStories = _chatController.channels
        .map(
          (channel) => _StoryEntry.channel(
            id: 'channel-${channel.name}',
            name: _displayStoryChannelName(channel.name),
            channelName: channel.name,
            imagePath: channel.imagePath,
          ),
        )
        .toList(growable: false);
    final feedStories = controller.stories
        .map(
          (story) => _StoryEntry.feed(
            id: story.id,
            name: story.name,
            imagePath: story.avatarUrl,
          ),
        )
        .toList(growable: false);
    return <_StoryEntry>[...channelStories, ...feedStories];
  }

  String _displayStoryChannelName(String channelName) {
    final normalizedChannelName = channelName.trim().replaceFirst('#', '');
    if (normalizedChannelName.isEmpty) {
      return channelName;
    }

    return normalizedChannelName
        .split(RegExp(r'[-_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Future<void> _handleStoryTap(
    BuildContext context,
    KaizengramController controller,
    _StoryEntry story,
  ) async {
    if (story.isChannel) {
      await _openChatChannel(context, story.channelName!);
      return;
    }

    final post = controller.postById(story.id);
    if (post == null) {
      return;
    }

    await _openPost(context, post);
  }

  List<Widget> _buildFeedStateChildren(KaizengramController controller) {
    return <Widget>[
      if (controller.errorMessage != null && controller.posts.isEmpty)
        const _FeedStateMessage(
          message: AppStrings.kaizengramMessageUnableLoadFeed,
        ),
      if (controller.posts.isEmpty && controller.errorMessage == null)
        const _FeedStateMessage(
          message: AppStrings.kaizengramMessageNoFeedItems,
        ),
    ];
  }

  Widget _buildPostCard(
    BuildContext context,
    KaizengramController controller,
    KaizengramFeedItem post,
  ) {
    return KeyedSubtree(
      key: _postKeyFor(post.id),
      child: _PostCard(
        post: post,
        fallbackText: _resolvedCommentPreviewText(
          controller.commentThreadForPost(post),
        ),
        onTap: () => _openPost(context, post),
        onLikeTap: () => controller.toggleLike(post.id),
        onCommentTap: () => _openComments(context, post),
        onFallbackMoreTap: () => _openFallbackComments(context, post),
        onShareTap: () => _sharePost(context, post),
        onAuditMediaTap: (selectedMediaItem) {
          _showCommentsThreadSheet(
            context,
            post,
            selectedAuditMediaItem: selectedMediaItem,
          );
        },
      ),
    );
  }

  List<Widget> _buildMixedFeedChildren(
    BuildContext context,
    KaizengramController controller,
  ) {
    final widgets = <Widget>[];
    for (final socialPost in controller.socialPosts) {
      widgets.add(_buildSocialPostCard(context, controller, socialPost));
    }
    final firstInsertionIndex = controller.posts.length > 1 ? 2 : 1;
    final secondInsertionIndex = controller.posts.length > 4 ? 5 : null;

    for (var index = 0; index < controller.posts.length; index++) {
      final post = controller.posts[index];
      widgets.add(_buildPostCard(context, controller, post));

      if (index + 1 == firstInsertionIndex) {
        widgets.add(
          _PowerListCard(
            title: AppStrings.kaizengramPowerListTitle,
            subtitle: AppStrings.kaizengramPowerListSubtitle,
            entries: _powerListEntriesFirstHalf,
            onEntryTap: _handlePowerListTap,
          ),
        );
      }

      if (secondInsertionIndex != null && index + 1 == secondInsertionIndex) {
        widgets.add(
          _PowerListCard(
            title: AppStrings.kaizengramPowerListContinuedTitle,
            subtitle: AppStrings.kaizengramPowerListContinuedSubtitle,
            entries: _powerListEntriesSecondHalf,
            onEntryTap: _handlePowerListTap,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildSocialPostCard(
    BuildContext context,
    KaizengramController controller,
    KaizengramSocialPost post,
  ) {
    final resolvedPost = controller.resolveSocialPost(post);

    return _WeeklyCheckInSocialTextCard(
      post: resolvedPost,
      loggedInUserName: controller.currentUserDisplayName,
      onInlineCommentSend: (message, attachments) {
        controller.addCurrentUserSocialPostComment(
          post: resolvedPost,
          message: message,
          attachments: attachments,
        );
      },
      onCommentTap: () => _openSocialCommentsSheet(
        context,
        controller,
        resolvedPost,
        controller.currentUserDisplayName,
      ),
    );
  }

  GlobalKey _postKeyFor(String postId) {
    return _postKeys.putIfAbsent(postId, () => GlobalObjectKey(postId));
  }

  void _setViewState(VoidCallback callback) {
    updateView(callback);
  }
}

enum _PowerListDestination { learningCompliance, documentCompliance, audit }

List<KaizengramAuditMediaItem> _buildAuditThreadItems(KaizengramFeedItem post) {
  if (post.resolvedPostCategory != KaizengramPostCategory.audit ||
      post.commentThread.isEmpty) {
    return post.auditMediaItems;
  }

  return List<KaizengramAuditMediaItem>.unmodifiable(<KaizengramAuditMediaItem>[
    ...post.auditMediaItems,
    KaizengramAuditMediaItem(
      id: '${post.id}-thread-no-image',
      title: AppStrings.kaizengramNoImageThreadTitle,
      thumbnailUrl: '',
      rating: _resolveAuditThreadRating(post.status),
      commentThread: post.commentThread,
    ),
  ]);
}

KaizengramAuditRating _resolveAuditThreadRating(String? status) {
  final normalizedStatus = status?.trim().toLowerCase();
  if (normalizedStatus == null || normalizedStatus.isEmpty) {
    return KaizengramAuditRating.good;
  }
  if (normalizedStatus.contains('bad')) {
    return KaizengramAuditRating.bad;
  }
  if (normalizedStatus.contains('need')) {
    return KaizengramAuditRating.needsImprovement;
  }
  return KaizengramAuditRating.good;
}

String? _resolvedPostDescription(KaizengramFeedItem post) {
  final description = CustomFunctions.resolvedText(post.description);
  if (description == null || description == post.status) {
    return null;
  }

  return description;
}

String? _resolvedCommentPreviewText(List<KaizengramComment> comments) {
  for (final comment in comments) {
    final message = comment.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }

  return null;
}

String? _resolvedPostMediaFallbackText(KaizengramFeedItem post) {
  final commentPreview = _resolvedCommentPreviewText(post.commentThread);
  if (commentPreview != null) {
    return commentPreview;
  }

  final description = _resolvedPostDescription(post)?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }

  final title = post.title.trim();
  return title.isEmpty ? null : title;
}

String? _resolvedAuditMediaFallbackText(KaizengramAuditMediaItem mediaItem) {
  final commentPreview = _resolvedCommentPreviewText(mediaItem.commentThread);
  if (commentPreview != null) {
    return commentPreview;
  }

  final title = mediaItem.title.trim();
  return title.isEmpty ? null : title;
}

bool _shouldUseTextMediaFallback(KaizengramFeedItem post) {
  final fallbackText = _resolvedPostMediaFallbackText(post);
  if (fallbackText == null) {
    return false;
  }

  if (post.resolvedPostCategory == KaizengramPostCategory.audit) {
    return _buildAuditThreadItems(post).isEmpty;
  }

  if (post.hasVideo || post.mediaUrls.length > 1) {
    return false;
  }

  final normalizedImageUrl = post.feedImageUrl?.trim();
  return normalizedImageUrl == null || normalizedImageUrl.isEmpty;
}

class _PowerListEntry {
  const _PowerListEntry({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.destination,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final _PowerListDestination destination;
}
