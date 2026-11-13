import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/managers/app_manager.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../login/domain/entities/user.dart';
import '../../../presentation/chat/widgets/chat_video_preview.dart';
import '../../../presentation/kaizengram_message_attachment.dart';
import '../../../presentation/widgets/kaizengram_full_screen_attachment_view.dart';
import '../../../presentation/widgets/kaizengram_link_preview_card.dart';
import '../../../presentation/widgets/kaizengram_link_utils.dart';
import '../../../presentation/widgets/kaizengram_notifier_state.dart';
import '../../../presentation/widgets/kaizengram_screen_common_widgets.dart';
import '../widgets/groups_common_widgets.dart';
import 'group_author_profile_screen.dart';

class KaizengramGroupShareDestination {
  const KaizengramGroupShareDestination({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.imagePath,
    required this.category,
    required this.privacyLabel,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String? imagePath;
  final String category;
  final String privacyLabel;
  final int memberCount;
}

class _KaizengramGroupsSharedStore {
  _KaizengramGroupsSharedStore() {
    final currentGroupEmail = _emailFromNameAndCategory(
      AppStrings.currentGroupMemberName,
      AppStrings.categoryAll,
    );
    currentGroupPerson = _GroupPerson(
      id: 'person-current',
      name: AppStrings.currentGroupMemberName,
      email: currentGroupEmail,
      role: AppStrings.currentGroupMemberRole,
      category: AppStrings.categoryAll,
      avatarUrl: _avatarUrlForSeed(currentGroupEmail),
      phone: _phoneForSeed('person-current'),
      dateOfBirth: _dateOfBirthForSeed('person-current'),
      gender: _genderForSeed('person-current'),
    );
    groups = _seedGroups();
    peopleDirectory = _seedPeopleDirectory();
    groupPostsByGroupId = _seedPostsForGroups(groups);
    trackedMembersByGroupId = _seedTrackedMembersForGroups(groups);
  }

  late final _GroupPerson currentGroupPerson;
  late List<_KaizengramGroupCommunity> groups;
  late List<_GroupPerson> peopleDirectory;
  late Map<String, List<_GroupFeedPost>> groupPostsByGroupId;
  late Map<String, List<_GroupPerson>> trackedMembersByGroupId;

  List<KaizengramGroupShareDestination> get shareDestinations => groups
      .where((group) => group.isJoined)
      .map(
        (group) => KaizengramGroupShareDestination(
          id: group.id,
          name: group.name,
          imageUrl: group.imageUrl,
          imagePath: group.imagePath,
          category: group.category,
          privacyLabel: group.privacyLabel,
          memberCount: group.memberCount,
        ),
      )
      .toList(growable: false);

  _GroupPerson resolvePersonForPost(
    _KaizengramGroupCommunity group,
    _GroupFeedPost post,
  ) {
    final matchedPerson = peopleDirectory.cast<_GroupPerson?>().firstWhere(
      (person) => person?.name == post.authorName,
      orElse: () => null,
    );
    if (matchedPerson != null) {
      return matchedPerson;
    }

    final synthesizedEmail = _emailFromNameAndCategory(
      post.authorName,
      group.category,
    );
    return _GroupPerson(
      id: 'person-$synthesizedEmail',
      name: post.authorName,
      email: synthesizedEmail,
      role: post.authorRole,
      category: group.category,
      avatarImagePath: post.authorAvatarImagePath,
      avatarUrl: post.authorAvatarUrl.trim().isEmpty
          ? _avatarUrlForSeed(synthesizedEmail)
          : post.authorAvatarUrl,
      phone: _phoneForSeed(synthesizedEmail),
      dateOfBirth: _dateOfBirthForSeed(synthesizedEmail),
      gender: _genderForSeed(synthesizedEmail),
    );
  }

  void sharePostToGroup({
    required String groupId,
    required String authorName,
    required String authorAvatarUrl,
    required String authorRole,
    required String content,
  }) {
    final groupIndex = groups.indexWhere((group) => group.id == groupId);
    if (groupIndex == -1) {
      return;
    }

    final targetGroup = groups[groupIndex];
    final normalizedAuthorName = authorName.trim().isEmpty
        ? AppStrings.currentUserCommentName
        : authorName.trim();
    final normalizedAuthorRole = authorRole.trim().isEmpty
        ? AppStrings.currentGroupMemberRole
        : authorRole.trim();
    final synthesizedEmail = _emailFromNameAndCategory(
      normalizedAuthorName,
      targetGroup.category,
    );
    final normalizedAvatarUrl = authorAvatarUrl.trim().isEmpty
        ? _avatarUrlForSeed(synthesizedEmail)
        : authorAvatarUrl.trim();
    final authorPerson = _GroupPerson(
      id: 'person-$synthesizedEmail',
      name: normalizedAuthorName,
      email: synthesizedEmail,
      role: normalizedAuthorRole,
      category: targetGroup.category,
      avatarUrl: normalizedAvatarUrl,
      phone: _phoneForSeed(synthesizedEmail),
      dateOfBirth: _dateOfBirthForSeed(synthesizedEmail),
      gender: _genderForSeed(synthesizedEmail),
    );

    if (!peopleDirectory.any(
      (person) => person.normalizedEmail == authorPerson.normalizedEmail,
    )) {
      peopleDirectory = <_GroupPerson>[authorPerson, ...peopleDirectory];
    }

    final currentMembers =
        trackedMembersByGroupId[targetGroup.id] ??
        <_GroupPerson>[currentGroupPerson];
    if (!currentMembers.any(
      (member) => member.normalizedEmail == authorPerson.normalizedEmail,
    )) {
      trackedMembersByGroupId = <String, List<_GroupPerson>>{
        ...trackedMembersByGroupId,
        targetGroup.id: <_GroupPerson>[authorPerson, ...currentMembers],
      };
    }

    final updatedGroup = targetGroup.copyWith(
      weeklyPosts: targetGroup.weeklyPosts + 1,
      newPostsCount: targetGroup.newPostsCount + 1,
    );
    groups = groups
        .map((group) => group.id == targetGroup.id ? updatedGroup : group)
        .toList(growable: false);

    final currentPosts =
        groupPostsByGroupId[targetGroup.id] ?? _seedPostsForGroup(updatedGroup);
    final sharedPost = _GroupFeedPost(
      id: '${targetGroup.id}-shared-${DateTime.now().microsecondsSinceEpoch}',
      authorName: normalizedAuthorName,
      authorAvatarUrl: normalizedAvatarUrl,
      authorRole: normalizedAuthorRole,
      timeLabel: AppStrings.justNowTimeLabel,
      content: content.trim(),
      authorAvatarImagePath: null,
      reactionCount: 0,
      comments: const <_GroupPostComment>[],
    );
    groupPostsByGroupId = <String, List<_GroupFeedPost>>{
      ...groupPostsByGroupId,
      targetGroup.id: <_GroupFeedPost>[sharedPost, ...currentPosts],
    };
  }

  List<_KaizengramGroupCommunity> _seedGroups() {
    return <_KaizengramGroupCommunity>[
      _KaizengramGroupCommunity(
        id: 'front-desk-momentum',
        name: AppStrings.groupFrontDeskName,
        description: AppStrings.groupFrontDeskDescription,
        category: AppStrings.categoryClinicOps,
        memberCount: 128,
        weeklyPosts: 14,
        newPostsCount: 4,
        isPrivate: true,
        isJoined: true,
        isManaged: true,
        isPinned: true,
        icon: Icons.local_hospital_outlined,
        accentColor: AppColors.blue,
        imageUrl:
            'https://images.unsplash.com/photo-1584515933487-779824d29309?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'training-lab-collective',
        name: AppStrings.groupTrainingLabName,
        description: AppStrings.groupTrainingLabDescription,
        category: AppStrings.categoryTraining,
        memberCount: 74,
        weeklyPosts: 11,
        newPostsCount: 3,
        isPrivate: false,
        isJoined: true,
        isManaged: false,
        isPinned: false,
        icon: Icons.school_outlined,
        accentColor: AppColors.progressColor,
        imageUrl:
            'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'audit-wins-room',
        name: AppStrings.groupAuditWinsName,
        description: AppStrings.groupAuditWinsDescription,
        category: AppStrings.categoryAudit,
        memberCount: 93,
        weeklyPosts: 18,
        newPostsCount: 6,
        isPrivate: true,
        isJoined: false,
        isManaged: false,
        hasInvite: true,
        icon: Icons.fact_check_outlined,
        accentColor: AppColors.hexff8e5d,
        imageUrl:
            'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'people-ops-connect',
        name: AppStrings.groupPeopleOpsName,
        description: AppStrings.groupPeopleOpsDescription,
        category: AppStrings.categoryPeopleOps,
        memberCount: 61,
        weeklyPosts: 8,
        newPostsCount: 2,
        isPrivate: true,
        isJoined: false,
        isManaged: false,
        icon: Icons.people_outline_rounded,
        accentColor: AppColors.hexff7d7d,
        imageUrl:
            'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'dental-assist-playbook',
        name: AppStrings.groupDentalAssistName,
        description: AppStrings.groupDentalAssistDescription,
        category: AppStrings.categoryClinicOps,
        memberCount: 117,
        weeklyPosts: 10,
        newPostsCount: 5,
        isPrivate: false,
        isJoined: true,
        isManaged: false,
        icon: Icons.medication_outlined,
        accentColor: AppColors.hex3cc4f4,
        imageUrl:
            'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'tech-workflow-roundtable',
        name: AppStrings.groupTechRoundtableName,
        description: AppStrings.groupTechRoundtableDescription,
        category: AppStrings.categoryTechnology,
        memberCount: 46,
        weeklyPosts: 7,
        newPostsCount: 1,
        isPrivate: false,
        isJoined: false,
        isManaged: false,
        icon: Icons.memory_outlined,
        accentColor: AppColors.secondaryColor,
        imageUrl:
            'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80',
      ),
      _KaizengramGroupCommunity(
        id: 'leadership-alignment-circle',
        name: AppStrings.groupLeadershipCircleName,
        description: AppStrings.groupLeadershipCircleDescription,
        category: AppStrings.categoryLeadership,
        memberCount: 32,
        weeklyPosts: 6,
        newPostsCount: 2,
        isPrivate: true,
        isJoined: true,
        isManaged: true,
        icon: Icons.workspace_premium_outlined,
        accentColor: AppColors.hex7ea6ff,
        imageUrl:
            'https://images.unsplash.com/photo-1552664730-d307ca884978?auto=format&fit=crop&w=300&q=80',
        coverImageUrl:
            'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
  }

  List<_GroupPerson> _seedPeopleDirectory() {
    return <_GroupPerson>[
      currentGroupPerson,
      _seedPerson(
        id: 'ops-ava',
        name: AppStrings.feedAuthor(AppStrings.categoryClinicOps),
        role: AppStrings.feedAuthorRole(AppStrings.categoryClinicOps),
        category: AppStrings.categoryClinicOps,
      ),
      _seedPerson(
        id: 'ops-noah',
        name: AppStrings.secondaryFeedAuthor(AppStrings.categoryClinicOps),
        role: AppStrings.secondaryFeedAuthorRole(AppStrings.categoryClinicOps),
        category: AppStrings.categoryClinicOps,
      ),
      _seedPerson(
        id: 'ops-taylor',
        name: AppStrings.commentAuthorOne(AppStrings.categoryClinicOps),
        role: AppStrings.frontDeskLeadRole,
        category: AppStrings.categoryClinicOps,
      ),
      _seedPerson(
        id: 'training-mason',
        name: AppStrings.feedAuthor(AppStrings.categoryTraining),
        role: AppStrings.feedAuthorRole(AppStrings.categoryTraining),
        category: AppStrings.categoryTraining,
      ),
      _seedPerson(
        id: 'training-lina',
        name: AppStrings.secondaryFeedAuthor(AppStrings.categoryTraining),
        role: AppStrings.secondaryFeedAuthorRole(AppStrings.categoryTraining),
        category: AppStrings.categoryTraining,
      ),
      _seedPerson(
        id: 'audit-sana',
        name: AppStrings.feedAuthor(AppStrings.categoryAudit),
        role: AppStrings.feedAuthorRole(AppStrings.categoryAudit),
        category: AppStrings.categoryAudit,
      ),
      _seedPerson(
        id: 'audit-imran',
        name: AppStrings.commentAuthorOne(AppStrings.categoryAudit),
        role: AppStrings.auditReviewerRole,
        category: AppStrings.categoryAudit,
      ),
      _seedPerson(
        id: 'leadership-elena',
        name: AppStrings.feedAuthor(AppStrings.categoryLeadership),
        role: AppStrings.feedAuthorRole(AppStrings.categoryLeadership),
        category: AppStrings.categoryLeadership,
      ),
      _seedPerson(
        id: 'leadership-mira',
        name: AppStrings.secondaryFeedAuthor(AppStrings.categoryLeadership),
        role: AppStrings.secondaryFeedAuthorRole(AppStrings.categoryLeadership),
        category: AppStrings.categoryLeadership,
      ),
      _seedPerson(
        id: 'people-nora',
        name: AppStrings.feedAuthor(AppStrings.categoryPeopleOps),
        role: AppStrings.feedAuthorRole(AppStrings.categoryPeopleOps),
        category: AppStrings.categoryPeopleOps,
      ),
      _seedPerson(
        id: 'people-amina',
        name: AppStrings.commentAuthorOne(AppStrings.categoryPeopleOps),
        role: AppStrings.hrBusinessPartnerRole,
        category: AppStrings.categoryPeopleOps,
      ),
      _seedPerson(
        id: 'tech-kai',
        name: AppStrings.feedAuthor(AppStrings.categoryTechnology),
        role: AppStrings.feedAuthorRole(AppStrings.categoryTechnology),
        category: AppStrings.categoryTechnology,
      ),
      _seedPerson(
        id: 'tech-eli',
        name: AppStrings.secondaryFeedAuthor(AppStrings.categoryTechnology),
        role: AppStrings.secondaryFeedAuthorRole(AppStrings.categoryTechnology),
        category: AppStrings.categoryTechnology,
      ),
    ];
  }

  Map<String, List<_GroupFeedPost>> _seedPostsForGroups(
    List<_KaizengramGroupCommunity> groups,
  ) {
    return <String, List<_GroupFeedPost>>{
      for (final group in groups) group.id: _seedPostsForGroup(group),
    };
  }

  List<_GroupFeedPost> _seedPostsForGroup(_KaizengramGroupCommunity group) {
    final reactionCount = (group.memberCount ~/ 9) > (group.newPostsCount + 4)
        ? (group.memberCount ~/ 9)
        : (group.newPostsCount + 4);

    return <_GroupFeedPost>[
      _GroupFeedPost(
        id: '${group.id}-post-0',
        authorName: AppStrings.feedAuthor(group.category),
        authorAvatarUrl: _avatarUrlForSeed('${group.id}-author'),
        authorRole: AppStrings.feedAuthorRole(group.category),
        timeLabel: AppStrings.feedTimeLabel(group.newPostsCount),
        content: AppStrings.feedPostBody(group.name, group.category),
        reactionCount: reactionCount,
        isLiked: true,
        comments: _seedComments(group, 0),
      ),
      _GroupFeedPost(
        id: '${group.id}-post-1',
        authorName: AppStrings.secondaryFeedAuthor(group.category),
        authorAvatarUrl: _avatarUrlForSeed('${group.id}-member-1'),
        authorRole: AppStrings.secondaryFeedAuthorRole(group.category),
        timeLabel: AppStrings.secondaryFeedTimeLabel,
        content: AppStrings.secondaryFeedPostBody(group.name),
        reactionCount: reactionCount + 3,
        comments: _seedComments(group, 1),
      ),
      _GroupFeedPost(
        id: '${group.id}-post-2',
        authorName: AppStrings.tertiaryFeedAuthor(group.category),
        authorAvatarUrl: _avatarUrlForSeed('${group.id}-member-2'),
        authorRole: AppStrings.tertiaryFeedAuthorRole(group.category),
        timeLabel: AppStrings.tertiaryFeedTimeLabel,
        content: AppStrings.tertiaryFeedPostBody(group.name),
        reactionCount: reactionCount + 1,
        comments: _seedComments(group, 2),
      ),
    ];
  }

  List<_GroupPostComment> _seedComments(
    _KaizengramGroupCommunity group,
    int postIndex,
  ) {
    return <_GroupPostComment>[
      _GroupPostComment(
        authorName: AppStrings.commentAuthorOne(group.category),
        authorAvatarUrl: _avatarUrlForSeed('${group.id}-comment-$postIndex-0'),
        timeLabel: AppStrings.commentTimeLabelOne,
        message: AppStrings.commentMessageOne(group.name),
      ),
      _GroupPostComment(
        authorName: AppStrings.commentAuthorTwo(group.category),
        authorAvatarUrl: _avatarUrlForSeed('${group.id}-comment-$postIndex-1'),
        timeLabel: AppStrings.commentTimeLabelTwo,
        message: AppStrings.commentMessageTwo(group.category),
      ),
    ];
  }

  Map<String, List<_GroupPerson>> _seedTrackedMembersForGroups(
    List<_KaizengramGroupCommunity> groups,
  ) {
    return <String, List<_GroupPerson>>{
      for (final group in groups) group.id: _seedTrackedMembersForGroup(group),
    };
  }

  List<_GroupPerson> _seedTrackedMembersForGroup(
    _KaizengramGroupCommunity group,
  ) {
    final categoryMatches = peopleDirectory
        .where((person) => person.category == group.category)
        .take(2)
        .toList(growable: false);

    return <_GroupPerson>[currentGroupPerson, ...categoryMatches];
  }

  _GroupPerson _seedPerson({
    required String id,
    required String name,
    required String role,
    required String category,
  }) {
    final email = _emailFromNameAndCategory(name, category);
    return _GroupPerson(
      id: id,
      name: name,
      email: email,
      role: role,
      category: category,
      avatarUrl: _avatarUrlForSeed(email),
      phone: _phoneForSeed(id),
      dateOfBirth: _dateOfBirthForSeed(id),
      gender: _genderForSeed(id),
    );
  }
}

class KaizengramGroupsScreen extends StatefulWidget {
  const KaizengramGroupsScreen({super.key, this.initialGroupId});

  static final _KaizengramGroupsSharedStore _sharedStore =
      _KaizengramGroupsSharedStore();

  final String? initialGroupId;

  static List<KaizengramGroupShareDestination> get shareDestinations =>
      _sharedStore.shareDestinations;

  static void sharePostToGroup({
    required String groupId,
    required String authorName,
    required String authorAvatarUrl,
    required String authorRole,
    required String content,
  }) {
    _sharedStore.sharePostToGroup(
      groupId: groupId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorRole: authorRole,
      content: content,
    );
  }

  @override
  State<KaizengramGroupsScreen> createState() => _KaizengramGroupsScreenState();
}

class _KaizengramGroupsScreenState extends State<KaizengramGroupsScreen>
    with KaizengramNotifierState<KaizengramGroupsScreen> {
  static const Color _screenBackground = AppColors.hex111317;

  late final _KaizengramGroupsSharedStore _store;
  late final TextEditingController _searchController;
  late _GroupPerson _loggedInGroupPerson;
  _GroupsHomeTab _selectedTab = _GroupsHomeTab.forYou;

  _GroupPerson get _currentGroupPerson => _store.currentGroupPerson;
  List<_KaizengramGroupCommunity> get _groups => _store.groups;
  set _groups(List<_KaizengramGroupCommunity> value) => _store.groups = value;
  List<_GroupPerson> get _peopleDirectory => _store.peopleDirectory;
  Map<String, List<_GroupFeedPost>> get _groupPostsByGroupId =>
      _store.groupPostsByGroupId;
  set _groupPostsByGroupId(Map<String, List<_GroupFeedPost>> value) =>
      _store.groupPostsByGroupId = value;
  Map<String, List<_GroupPerson>> get _trackedMembersByGroupId =>
      _store.trackedMembersByGroupId;
  set _trackedMembersByGroupId(Map<String, List<_GroupPerson>> value) =>
      _store.trackedMembersByGroupId = value;

  @override
  void initState() {
    super.initState();
    _store = KaizengramGroupsScreen._sharedStore;
    _loggedInGroupPerson = _store.currentGroupPerson;
    _searchController = TextEditingController();
    _searchController.addListener(notifyView);
    if (widget.initialGroupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final initialGroup = _groupById(widget.initialGroupId!);
        if (mounted && initialGroup != null) {
          _openGroupDetails(initialGroup);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loggedInGroupPerson = _groupPersonFromAppUser(
      context.read<AppManager>().currentUser,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_KaizengramGroupCommunity> get _joinedGroups =>
      _sortGroups(_groups.where((group) => group.isJoined));

  List<_KaizengramGroupCommunity> get _inviteGroups =>
      _filterGroups(_groups.where((group) => group.hasInvite));

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final visibleSections = _buildSections();

      return Scaffold(
        backgroundColor: _screenBackground,
        appBar: AppBar(
          backgroundColor: _screenBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleSpacing: 18,
          title: const AppTextView.title1(
            AppStrings.screenTitle,
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          actions: <Widget>[
            _CreateGroupAppBarAction(onTap: _openCreateGroupSheet),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: <Widget>[
              _GroupsTabBar(
                selectedTab: _selectedTab,
                onTabSelected: _switchTab,
              ),
              const SizedBox(height: 14),
              GroupsSearchField(controller: _searchController),
              const SizedBox(height: 16),
              if (visibleSections.isEmpty)
                _GroupsEmptyState(
                  onClearSearch: _clearSearch,
                  showClearAction: _searchController.text.trim().isNotEmpty,
                )
              else
                ...visibleSections,
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _buildSections() {
    switch (_selectedTab) {
      case _GroupsHomeTab.forYou:
        return _buildForYouSections();
      case _GroupsHomeTab.yourGroups:
        return _buildYourGroupsSections();
      case _GroupsHomeTab.yourActivity:
        return _buildYourActivitySections();
      case _GroupsHomeTab.invites:
        return _buildInvitesSections();
    }
  }

  List<Widget> _buildForYouSections() {
    final sections = <Widget>[];
    final yourGroups = _filterGroups(_joinedGroups);
    final previewGroups = yourGroups.take(3).toList(growable: false);

    if (previewGroups.isNotEmpty) {
      sections.add(
        GroupsSection(
          title: AppStrings.sectionYourGroups,
          subtitle: AppStrings.yourGroupsSubtitle,
          actionLabel: AppStrings.seeAllAction,
          onActionTap: () {
            _openMyGroupsScreen();
          },
          child: _YourGroupsRail(
            groups: previewGroups,
            onGroupTap: (group) {
              _openGroupDetails(group);
            },
          ),
        ),
      );
    }

    if (yourGroups.isNotEmpty) {
      sections.add(
        GroupsSection(
          title: AppStrings.sectionGroupsFeed,
          subtitle: AppStrings.groupsFeedSubtitle,
          child: Column(
            children: yourGroups
                .map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JoinedGroupPostCard(
                      group: group,
                      post: _postPreviewFor(group),
                      onGroupTap: () {
                        _openGroupDetails(group);
                      },
                      onViewGroupTap: () {
                        _openGroupDetails(group);
                      },
                      onProfileTap: () {
                        _openAuthorProfile(group, _postPreviewFor(group));
                      },
                      onCommentTap: () => _showCommentsBottomSheet(
                        group: group,
                        post: _postPreviewFor(group),
                        onPostUpdated: (updatedPost) => _updateGroupPost(
                          groupId: group.id,
                          updatedPost: updatedPost,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }

    return sections;
  }

  List<Widget> _buildYourGroupsSections() {
    final groups = _filterGroups(_joinedGroups);
    if (groups.isEmpty && _searchController.text.trim().isNotEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      _MyGroupsPanel(
        groups: groups,
        onCreateTap: () {
          _openCreateGroupSheet();
        },
        onGroupTap: (group) {
          _openGroupDetails(group);
        },
      ),
    ];
  }

  List<Widget> _buildYourActivitySections() {
    final activityGroups = _filterGroups(
      _joinedGroups.where(
        (group) => group.newPostsCount > 0 || group.weeklyPosts > 0,
      ),
    );
    if (activityGroups.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      GroupsSection(
        title: AppStrings.yourActivityTab,
        subtitle: AppStrings.yourActivitySubtitle,
        child: Column(
          children: activityGroups
              .map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _JoinedGroupPostCard(
                    group: group,
                    post: _postPreviewFor(group),
                    onGroupTap: () {
                      _openGroupDetails(group);
                    },
                    onViewGroupTap: () {
                      _openGroupDetails(group);
                    },
                    onProfileTap: () {
                      _openAuthorProfile(group, _postPreviewFor(group));
                    },
                    onCommentTap: () => _showCommentsBottomSheet(
                      group: group,
                      post: _postPreviewFor(group),
                      onPostUpdated: (updatedPost) => _updateGroupPost(
                        groupId: group.id,
                        updatedPost: updatedPost,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ];
  }

  List<Widget> _buildInvitesSections() {
    if (_inviteGroups.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      GroupsSection(
        title: AppStrings.sectionInvites,
        child: Column(
          children: _inviteGroups
              .map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupFeatureCard(
                    group: group,
                    badgeLabel: AppStrings.invitedLabel,
                    actionLabel: AppStrings.reviewAction,
                    onActionTap: () {
                      _openGroupDetails(group);
                    },
                    onTap: () {
                      _openGroupDetails(group);
                    },
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ];
  }

  List<_KaizengramGroupCommunity> _filterGroups(
    Iterable<_KaizengramGroupCommunity> source,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return source
        .where((group) {
          final matchesQuery = query.isEmpty || group.matchesQuery(query);
          return matchesQuery;
        })
        .toList(growable: false);
  }

  List<_KaizengramGroupCommunity> _sortGroups(
    Iterable<_KaizengramGroupCommunity> groups,
  ) {
    final sorted = groups.toList(growable: false);
    sorted.sort((left, right) {
      if (left.isPinned != right.isPinned) {
        return left.isPinned ? -1 : 1;
      }
      if (left.isManaged != right.isManaged) {
        return left.isManaged ? -1 : 1;
      }
      if (left.newPostsCount != right.newPostsCount) {
        return right.newPostsCount.compareTo(left.newPostsCount);
      }
      return right.memberCount.compareTo(left.memberCount);
    });
    return sorted;
  }

  void _switchTab(_GroupsHomeTab tab) {
    updateView(() => _selectedTab = tab);
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<void> _openMyGroupsScreen() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _KaizengramMyGroupsScreen(
          groupsBuilder: () => _joinedGroups,
          onCreateTap: _openCreateGroupSheet,
          onGroupTap: _openGroupDetails,
        ),
      ),
    );
  }

  Future<void> _openCreateGroupSheet() async {
    final draft = await showModalBottomSheet<_CreateGroupDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupBottomSheet(),
    );

    if (draft == null) {
      return;
    }

    final createdGroup = _KaizengramGroupCommunity(
      id: 'group-${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
      description: draft.about,
      category: draft.topic,
      memberCount: 1,
      weeklyPosts: 1,
      newPostsCount: 1,
      isPrivate: draft.isPrivate,
      isJoined: true,
      isManaged: true,
      isPinned: true,
      hasInvite: false,
      icon: _iconForTopic(draft.topic),
      accentColor: _accentForTopic(draft.topic),
      imagePath: draft.imagePath,
      coverImagePath: draft.coverImagePath,
      imageUrl: _imageForTopic(draft.topic),
      coverImageUrl: _coverImageForTopic(draft.topic),
    );

    updateView(() {
      _groups = <_KaizengramGroupCommunity>[createdGroup, ..._groups];
      _groupPostsByGroupId = <String, List<_GroupFeedPost>>{
        createdGroup.id: _seedPostsForGroup(createdGroup),
        ..._groupPostsByGroupId,
      };
      _trackedMembersByGroupId = <String, List<_GroupPerson>>{
        createdGroup.id: <_GroupPerson>[_loggedInGroupPerson],
        ..._trackedMembersByGroupId,
      };
      _selectedTab = _GroupsHomeTab.yourGroups;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.groupCreatedMessage(createdGroup.name)),
        ),
      );
  }

  Future<void> _openGroupDetails(_KaizengramGroupCommunity group) {
    final resolvedGroup = _groupById(group.id) ?? group;
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _KaizengramGroupDetailScreen(
          group: resolvedGroup,
          posts: _postsForGroup(resolvedGroup),
          members: _trackedMembersForGroup(resolvedGroup),
          directoryPeople: _peopleDirectory,
          currentUser: _loggedInGroupPerson,
          onGroupUpdated: _updateGroup,
          onGroupMembersUpdated: _updateGroupMembers,
          onPostCreated: (createdPost) => _prependGroupPost(
            groupId: resolvedGroup.id,
            createdPost: createdPost,
          ),
          onPostUpdated: (updatedPost) => _updateGroupPost(
            groupId: resolvedGroup.id,
            updatedPost: updatedPost,
          ),
          onAuthorTap: (post) => _openAuthorProfile(resolvedGroup, post),
        ),
      ),
    );
  }

  Future<void> _openAuthorProfile(
    _KaizengramGroupCommunity group,
    _GroupFeedPost post,
  ) {
    final person = _store.resolvePersonForPost(group, post);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GroupAuthorProfileScreen(
          groupName: group.name,
          groupCategory: group.category,
          groupPrivacyLabel: group.privacyLabel,
          authorName: post.authorName,
          authorAvatarUrl: post.authorAvatarUrl,
          authorRole: post.authorRole,
          email: person.email,
          phone: person.phone,
          dateOfBirth: person.dateOfBirth,
          gender: person.gender,
          timeLabel: post.timeLabel,
          postContent: post.content,
        ),
      ),
    );
  }

  List<_GroupPerson> _trackedMembersForGroup(_KaizengramGroupCommunity group) {
    return _trackedMembersByGroupId[group.id] ??
        <_GroupPerson>[_loggedInGroupPerson];
  }

  _GroupPerson _groupPersonFromAppUser(User? currentUser) {
    final resolvedName = CustomFunctions.resolveName(currentUser).trim();
    final name = resolvedName.isEmpty ? _currentGroupPerson.name : resolvedName;
    final email = currentUser?.email?.trim();
    final resolvedEmail = email == null || email.isEmpty
        ? _emailFromNameAndCategory(name, AppStrings.categoryAll)
        : email;
    final imagePath = currentUser?.image?.trim();
    final normalizedImagePath = imagePath == null || imagePath.isEmpty
        ? null
        : imagePath;
    final resolvedAvatarUrl =
        CustomFunctions.resolveImageUrl(
          currentUser?.imageUrl ?? currentUser?.image,
        ) ??
        _avatarUrlForSeed(resolvedEmail);

    return _GroupPerson(
      id: 'person-current-app-user',
      name: name,
      email: resolvedEmail,
      role: AppStrings.currentGroupMemberRole,
      category: AppStrings.categoryAll,
      avatarImagePath: normalizedImagePath,
      avatarUrl: resolvedAvatarUrl,
      phone: _currentGroupPerson.phone,
      dateOfBirth: _currentGroupPerson.dateOfBirth,
      gender: _currentGroupPerson.gender,
    );
  }

  void _updateGroupMembers(
    _KaizengramGroupCommunity updatedGroup,
    List<_GroupPerson> members,
  ) {
    updateView(() {
      _groups = _groups
          .map((group) => group.id == updatedGroup.id ? updatedGroup : group)
          .toList(growable: false);
      _trackedMembersByGroupId = <String, List<_GroupPerson>>{
        ..._trackedMembersByGroupId,
        updatedGroup.id: members,
      };
    });
  }

  _KaizengramGroupCommunity? _groupById(String id) {
    for (final group in _groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  void _updateGroup(_KaizengramGroupCommunity updatedGroup) {
    updateView(() {
      _groups = _groups
          .map((group) => group.id == updatedGroup.id ? updatedGroup : group)
          .toList(growable: false);
    });
  }

  void _updateGroupPost({
    required String groupId,
    required _GroupFeedPost updatedPost,
  }) {
    final posts = _groupPostsByGroupId[groupId];
    if (posts == null) {
      return;
    }

    updateView(() {
      _groupPostsByGroupId = <String, List<_GroupFeedPost>>{
        ..._groupPostsByGroupId,
        groupId: posts
            .map((post) => post.id == updatedPost.id ? updatedPost : post)
            .toList(growable: false),
      };
    });
  }

  void _prependGroupPost({
    required String groupId,
    required _GroupFeedPost createdPost,
  }) {
    final posts = _groupPostsByGroupId[groupId] ?? const <_GroupFeedPost>[];
    updateView(() {
      _groupPostsByGroupId = <String, List<_GroupFeedPost>>{
        ..._groupPostsByGroupId,
        groupId: <_GroupFeedPost>[createdPost, ...posts],
      };
    });
  }

  _GroupFeedPost _postPreviewFor(_KaizengramGroupCommunity group) {
    return _postsForGroup(group).first;
  }

  List<_GroupFeedPost> _postsForGroup(_KaizengramGroupCommunity group) {
    return _groupPostsByGroupId[group.id] ?? _seedPostsForGroup(group);
  }

  List<_GroupFeedPost> _seedPostsForGroup(_KaizengramGroupCommunity group) {
    final reactionCount = (group.memberCount ~/ 9) > (group.newPostsCount + 4)
        ? (group.memberCount ~/ 9)
        : (group.newPostsCount + 4);

    return <_GroupFeedPost>[
      _GroupFeedPost(
        id: '${group.id}-post-0',
        authorName: AppStrings.feedAuthor(group.category),
        authorAvatarUrl:
            'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${group.id}-author')}',
        authorRole: AppStrings.feedAuthorRole(group.category),
        timeLabel: AppStrings.feedTimeLabel(group.newPostsCount),
        content: AppStrings.feedPostBody(group.name, group.category),
        reactionCount: reactionCount,
        isLiked: true,
        comments: _seedComments(group, 0),
      ),
      _GroupFeedPost(
        id: '${group.id}-post-1',
        authorName: AppStrings.secondaryFeedAuthor(group.category),
        authorAvatarUrl:
            'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${group.id}-member-1')}',
        authorRole: AppStrings.secondaryFeedAuthorRole(group.category),
        timeLabel: AppStrings.secondaryFeedTimeLabel,
        content: AppStrings.secondaryFeedPostBody(group.name),
        reactionCount: reactionCount + 3,
        comments: _seedComments(group, 1),
      ),
      _GroupFeedPost(
        id: '${group.id}-post-2',
        authorName: AppStrings.tertiaryFeedAuthor(group.category),
        authorAvatarUrl:
            'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${group.id}-member-2')}',
        authorRole: AppStrings.tertiaryFeedAuthorRole(group.category),
        timeLabel: AppStrings.tertiaryFeedTimeLabel,
        content: AppStrings.tertiaryFeedPostBody(group.name),
        reactionCount: reactionCount + 1,
        comments: _seedComments(group, 2),
      ),
    ];
  }

  List<_GroupPostComment> _seedComments(
    _KaizengramGroupCommunity group,
    int postIndex,
  ) {
    return <_GroupPostComment>[
      _GroupPostComment(
        authorName: AppStrings.commentAuthorOne(group.category),
        authorAvatarUrl:
            'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${group.id}-comment-$postIndex-0')}',
        timeLabel: AppStrings.commentTimeLabelOne,
        message: AppStrings.commentMessageOne(group.name),
      ),
      _GroupPostComment(
        authorName: AppStrings.commentAuthorTwo(group.category),
        authorAvatarUrl:
            'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${group.id}-comment-$postIndex-1')}',
        timeLabel: AppStrings.commentTimeLabelTwo,
        message: AppStrings.commentMessageTwo(group.category),
      ),
    ];
  }

  Future<void> _showCommentsBottomSheet({
    required _KaizengramGroupCommunity group,
    required _GroupFeedPost post,
    required ValueChanged<_GroupFeedPost> onPostUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupCommentsBottomSheet(
        group: group,
        post: post,
        onPostUpdated: onPostUpdated,
      ),
    );
  }

  IconData _iconForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return Icons.local_hospital_outlined;
      case AppStrings.categoryTraining:
        return Icons.school_outlined;
      case AppStrings.categoryAudit:
        return Icons.fact_check_outlined;
      case AppStrings.categoryLeadership:
        return Icons.workspace_premium_outlined;
      case AppStrings.categoryPeopleOps:
        return Icons.people_outline_rounded;
      case AppStrings.categoryTechnology:
        return Icons.memory_outlined;
      default:
        return Icons.groups_2_outlined;
    }
  }

  Color _accentForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return AppColors.blue;
      case AppStrings.categoryTraining:
        return AppColors.progressColor;
      case AppStrings.categoryAudit:
        return AppColors.hexff8e5d;
      case AppStrings.categoryLeadership:
        return AppColors.hex7ea6ff;
      case AppStrings.categoryPeopleOps:
        return AppColors.hexff7d7d;
      case AppStrings.categoryTechnology:
        return AppColors.secondaryColor;
      default:
        return AppColors.blue;
    }
  }

  String _imageForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return 'https://images.unsplash.com/photo-1584515933487-779824d29309?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryTraining:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryAudit:
        return 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryLeadership:
        return 'https://images.unsplash.com/photo-1552664730-d307ca884978?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryPeopleOps:
        return 'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryTechnology:
        return 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=300&q=80';
      default:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=300&q=80';
    }
  }

  String _coverImageForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryTraining:
        return 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryAudit:
        return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryLeadership:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryPeopleOps:
        return 'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryTechnology:
        return 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80';
      default:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80';
    }
  }
}

enum _GroupsHomeTab { forYou, yourGroups, yourActivity, invites }

class _GroupFeedPost {
  const _GroupFeedPost({
    required this.id,
    required this.authorName,
    this.authorAvatarImagePath,
    required this.authorAvatarUrl,
    required this.authorRole,
    required this.timeLabel,
    required this.content,
    required this.reactionCount,
    required this.comments,
    this.attachments = const <KaizengramMessageAttachment>[],
    this.isLiked = false,
    this.showFallbackCoverImage = true,
  });

  final String id;
  final String authorName;
  final String? authorAvatarImagePath;
  final String authorAvatarUrl;
  final String authorRole;
  final String timeLabel;
  final String content;
  final int reactionCount;
  final List<_GroupPostComment> comments;
  final List<KaizengramMessageAttachment> attachments;
  final bool isLiked;
  final bool showFallbackCoverImage;

  int get commentCount => comments.length;

  _GroupFeedPost copyWith({
    String? id,
    String? authorName,
    String? authorAvatarImagePath,
    String? authorAvatarUrl,
    String? authorRole,
    String? timeLabel,
    String? content,
    int? reactionCount,
    List<_GroupPostComment>? comments,
    List<KaizengramMessageAttachment>? attachments,
    bool? isLiked,
    bool? showFallbackCoverImage,
  }) {
    return _GroupFeedPost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorAvatarImagePath:
          authorAvatarImagePath ?? this.authorAvatarImagePath,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorRole: authorRole ?? this.authorRole,
      timeLabel: timeLabel ?? this.timeLabel,
      content: content ?? this.content,
      reactionCount: reactionCount ?? this.reactionCount,
      comments: comments ?? this.comments,
      attachments: attachments ?? this.attachments,
      isLiked: isLiked ?? this.isLiked,
      showFallbackCoverImage:
          showFallbackCoverImage ?? this.showFallbackCoverImage,
    );
  }

  _GroupFeedPost toggledLike() {
    return copyWith(
      isLiked: !isLiked,
      reactionCount: isLiked
          ? (reactionCount > 0 ? reactionCount - 1 : 0)
          : reactionCount + 1,
    );
  }
}

class _GroupPostComment {
  const _GroupPostComment({
    required this.authorName,
    required this.authorAvatarUrl,
    required this.timeLabel,
    required this.message,
  });

  final String authorName;
  final String authorAvatarUrl;
  final String timeLabel;
  final String message;
}

class _GroupPerson {
  const _GroupPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.category,
    this.avatarImagePath,
    required this.avatarUrl,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String category;
  final String? avatarImagePath;
  final String avatarUrl;
  final String phone;
  final String dateOfBirth;
  final String gender;

  String get normalizedEmail => email.trim().toLowerCase();

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return name.toLowerCase().contains(normalizedQuery) ||
        email.toLowerCase().contains(normalizedQuery) ||
        role.toLowerCase().contains(normalizedQuery);
  }
}

String _normalizeInviteEmail(String value) => value.trim().toLowerCase();

bool _isValidInviteEmail(String value) {
  final normalizedValue = _normalizeInviteEmail(value);
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedValue);
}

String _emailFromNameAndCategory(String name, String category) {
  final normalizedName = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'\.+'), '.')
      .replaceAll(RegExp(r'^\.|\.$'), '');
  final normalizedCategory = category.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );

  if (normalizedCategory.isEmpty || normalizedCategory == 'all') {
    return '$normalizedName@kaizen.app';
  }

  return '$normalizedName.$normalizedCategory@kaizen.app';
}

String _displayNameFromEmail(String email) {
  final localPart = _normalizeInviteEmail(email).split('@').first;
  final words = localPart
      .split(RegExp(r'[._-]+'))
      .where((token) => token.isNotEmpty)
      .map((token) => '${token[0].toUpperCase()}${token.substring(1)}')
      .toList(growable: false);

  if (words.isEmpty) {
    return email;
  }

  return words.join(' ');
}

String _avatarUrlForSeed(String seed) {
  return 'https://i.pravatar.cc/150?u=${Uri.encodeComponent(seed)}';
}

int _seedValueForProfile(String seed) {
  return seed.runes.fold<int>(0, (value, rune) => value + rune);
}

String _phoneForSeed(String seed) {
  final baseSeed = _seedValueForProfile(seed);
  final areaCode = 201 + (baseSeed % 500);
  final suffix = 1000 + (baseSeed % 9000);
  return '($areaCode) 555-${suffix.toString().padLeft(4, '0')}';
}

String _dateOfBirthForSeed(String seed) {
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final baseSeed = _seedValueForProfile(seed);
  final month = baseSeed % monthLabels.length;
  final day = 1 + (baseSeed % 28);
  final year = 1986 + (baseSeed % 12);
  return '${monthLabels[month]} ${day.toString().padLeft(2, '0')}, $year';
}

String _genderForSeed(String seed) {
  return _seedValueForProfile(seed).isEven
      ? AppStrings.profileGenderFemale
      : AppStrings.profileGenderMale;
}

const Object _noGroupImagePathOverride = Object();
const Object _noGroupCoverImagePathOverride = Object();

class _KaizengramGroupCommunity {
  const _KaizengramGroupCommunity({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.memberCount,
    required this.weeklyPosts,
    required this.newPostsCount,
    required this.isPrivate,
    required this.icon,
    required this.accentColor,
    required this.imageUrl,
    required this.coverImageUrl,
    this.imagePath,
    this.coverImagePath,
    this.isJoined = false,
    this.isManaged = false,
    this.isPinned = false,
    this.hasInvite = false,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int memberCount;
  final int weeklyPosts;
  final int newPostsCount;
  final bool isPrivate;
  final bool isJoined;
  final bool isManaged;
  final bool isPinned;
  final bool hasInvite;
  final IconData icon;
  final Color accentColor;
  final String? imagePath;
  final String? coverImagePath;
  final String imageUrl;
  final String coverImageUrl;

  String get privacyLabel =>
      isPrivate ? AppStrings.privacyPrivate : AppStrings.privacyPublic;

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return name.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized) ||
        category.toLowerCase().contains(normalized);
  }

  _KaizengramGroupCommunity copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? memberCount,
    int? weeklyPosts,
    int? newPostsCount,
    bool? isPrivate,
    bool? isJoined,
    bool? isManaged,
    bool? isPinned,
    bool? hasInvite,
    IconData? icon,
    Color? accentColor,
    Object? imagePath = _noGroupImagePathOverride,
    Object? coverImagePath = _noGroupCoverImagePathOverride,
    String? imageUrl,
    String? coverImageUrl,
  }) {
    return _KaizengramGroupCommunity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      memberCount: memberCount ?? this.memberCount,
      weeklyPosts: weeklyPosts ?? this.weeklyPosts,
      newPostsCount: newPostsCount ?? this.newPostsCount,
      isPrivate: isPrivate ?? this.isPrivate,
      isJoined: isJoined ?? this.isJoined,
      isManaged: isManaged ?? this.isManaged,
      isPinned: isPinned ?? this.isPinned,
      hasInvite: hasInvite ?? this.hasInvite,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      imagePath: identical(imagePath, _noGroupImagePathOverride)
          ? this.imagePath
          : imagePath as String?,
      coverImagePath: identical(coverImagePath, _noGroupCoverImagePathOverride)
          ? this.coverImagePath
          : coverImagePath as String?,
      imageUrl: imageUrl ?? this.imageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}

class _KaizengramMyGroupsScreen extends StatefulWidget {
  const _KaizengramMyGroupsScreen({
    required this.groupsBuilder,
    required this.onCreateTap,
    required this.onGroupTap,
  });

  final List<_KaizengramGroupCommunity> Function() groupsBuilder;
  final Future<void> Function() onCreateTap;
  final Future<void> Function(_KaizengramGroupCommunity) onGroupTap;

  @override
  State<_KaizengramMyGroupsScreen> createState() =>
      _KaizengramMyGroupsScreenState();
}

class _KaizengramMyGroupsScreenState extends State<_KaizengramMyGroupsScreen>
    with KaizengramNotifierState<_KaizengramMyGroupsScreen> {
  Future<void> _handleCreateTap() async {
    await widget.onCreateTap();
    if (mounted) {
      notifyView();
    }
  }

  Future<void> _handleGroupTap(_KaizengramGroupCommunity group) async {
    await widget.onGroupTap(group);
    if (mounted) {
      notifyView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final groups = widget.groupsBuilder();

      return Scaffold(
        backgroundColor: AppColors.hex111317,
        appBar: AppBar(
          backgroundColor: AppColors.hex111317,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 18,
          title: const AppTextView.title1(
            AppStrings.myGroupsScreenTitle,
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: <Widget>[
              _MyGroupsPanel(
                groups: groups,
                onCreateTap: () {
                  _handleCreateTap();
                },
                onGroupTap: (group) {
                  _handleGroupTap(group);
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _GroupsTabBar extends StatelessWidget {
  const _GroupsTabBar({required this.selectedTab, required this.onTabSelected});

  final _GroupsHomeTab selectedTab;
  final ValueChanged<_GroupsHomeTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _GroupsHomeTab.values
            .map((tab) {
              final isSelected = tab == selectedTab;
              return Padding(
                padding: EdgeInsets.only(
                  right: tab == _GroupsHomeTab.invites ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => onTabSelected(tab),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.secondaryColor.withValues(alpha: 0.20)
                          : AppColors.hex1b1e27,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondaryColor.withValues(alpha: 0.50)
                            : AppColors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AppTextView.body3(
                      _labelFor(tab),
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _labelFor(_GroupsHomeTab tab) {
    switch (tab) {
      case _GroupsHomeTab.forYou:
        return AppStrings.forYouTab;
      case _GroupsHomeTab.yourGroups:
        return AppStrings.yourGroupsTab;
      case _GroupsHomeTab.yourActivity:
        return AppStrings.yourActivityTab;
      case _GroupsHomeTab.invites:
        return AppStrings.invitesTab;
    }
  }
}

class _YourGroupsRail extends StatelessWidget {
  const _YourGroupsRail({required this.groups, required this.onGroupTap});

  final List<_KaizengramGroupCommunity> groups;
  final ValueChanged<_KaizengramGroupCommunity> onGroupTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: groups
          .map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MyGroupSlimTile(
                group: group,
                onTap: () => onGroupTap(group),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MyGroupsPanel extends StatelessWidget {
  const _MyGroupsPanel({
    required this.groups,
    required this.onCreateTap,
    required this.onGroupTap,
  });

  final List<_KaizengramGroupCommunity> groups;
  final VoidCallback onCreateTap;
  final ValueChanged<_KaizengramGroupCommunity> onGroupTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CreateGroupListTile(onTap: onCreateTap),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.hex1b1e27,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: const AppTextView.body2(
              AppStrings.yourGroupsEmptySubtitle,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MyGroupSlimTile(
                group: group,
                onTap: () => onGroupTap(group),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateGroupListTile extends StatelessWidget {
  const _CreateGroupListTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.hex1b1e27,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.secondaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body2(
                      AppStrings.createGroup,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    SizedBox(height: 4),
                    AppTextView.body4(
                      AppStrings.createGroupTileSubtitle,
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
  }
}

class _CreateGroupAppBarAction extends StatelessWidget {
  const _CreateGroupAppBarAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.hex1b1e27,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.16),
              ),
            ),
            child: const Icon(
              Icons.add,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyGroupSlimTile extends StatelessWidget {
  const _MyGroupSlimTile({required this.group, required this.onTap});

  final _KaizengramGroupCommunity group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.hex1b1e27,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: <Widget>[
              GroupThumbnailImage(
                imageUrl: group.imageUrl,
                imagePath: group.imagePath,
                borderRadius: 14,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppTextView.body2(
                            group.name,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isPinned) ...<Widget>[
                          const SizedBox(width: 8),
                          const _PinnedGroupIcon(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body4(
                      AppStrings.compactGroupMeta(
                        group.memberCount,
                        group.newPostsCount,
                      ),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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

class _JoinedGroupPostCard extends StatelessWidget {
  const _JoinedGroupPostCard({
    required this.group,
    required this.post,
    required this.onGroupTap,
    required this.onViewGroupTap,
    required this.onProfileTap,
    required this.onCommentTap,
  });

  final _KaizengramGroupCommunity group;
  final _GroupFeedPost post;
  final VoidCallback onGroupTap;
  final VoidCallback onViewGroupTap;
  final VoidCallback onProfileTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    final hasMessage = post.content.trim().isNotEmpty;
    final hasAttachments = post.attachments.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.hex1b1e27,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                GroupHeaderAvatar(
                  groupImageUrl: group.imageUrl,
                  groupImagePath: group.imagePath,
                  authorAvatarImagePath: post.authorAvatarImagePath,
                  authorAvatarUrl: post.authorAvatarUrl,
                  onGroupTap: onGroupTap,
                  onProfileTap: onProfileTap,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        onTap: onGroupTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: AppTextView.body2(
                            group.name,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: AppTextView.body4(
                            AppStrings.authorMeta(
                              post.authorName,
                              post.timeLabel,
                            ),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (group.isPinned) const _PinnedGroupIcon(),
              ],
            ),
            if (hasMessage) ...<Widget>[
              const SizedBox(height: 14),
              AppTextView.body2(
                post.content,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ],
            if (hasAttachments) ...<Widget>[
              SizedBox(height: hasMessage ? 12 : 14),
              _GroupAttachmentPreviewStrip(
                attachments: post.attachments,
                singleMediaHeight: 180,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextView.body4(
                    AppStrings.reactionCountLabel(post.reactionCount),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppTextView.body4(
                  AppStrings.commentCountLabel(post.commentCount),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FeedActionButton(
                    icon: Icons.visibility_outlined,
                    label: AppStrings.viewGroupAction,
                    onTap: onViewGroupTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FeedActionButton(
                    icon: Icons.forum_outlined,
                    label: AppStrings.commentAction,
                    onTap: onCommentTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPostListCard extends StatelessWidget {
  const _GroupPostListCard({
    required this.group,
    required this.post,
    required this.onAuthorTap,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final _KaizengramGroupCommunity group;
  final _GroupFeedPost post;
  final VoidCallback onAuthorTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    final hasMessage = post.content.trim().isNotEmpty;
    final hasAttachments = post.attachments.isNotEmpty;
    final authorImageProvider = _resolvedGroupAvatarImageProvider(
      imagePath: post.authorAvatarImagePath,
      imageUrl: post.authorAvatarUrl,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.hex232834,
                    backgroundImage: authorImageProvider,
                    child: authorImageProvider == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppColors.textPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppTextView.body2(
                          post.authorName,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        const SizedBox(height: 4),
                        AppTextView.body4(
                          AppStrings.authorMeta(
                            post.authorRole,
                            post.timeLabel,
                          ),
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasMessage) ...<Widget>[
            const SizedBox(height: 14),
            AppTextView.body2(
              post.content,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ],
          if (hasAttachments || post.showFallbackCoverImage) ...<Widget>[
            const SizedBox(height: 14),
            if (hasAttachments)
              _GroupAttachmentPreviewStrip(
                attachments: post.attachments,
                singleMediaHeight: 220,
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _GroupCoverImage(
                  imageUrl: group.coverImageUrl,
                  imagePath: group.coverImagePath,
                  height: 170,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextView.body4(
                  AppStrings.reactionCountLabel(post.reactionCount),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppTextView.body4(
                AppStrings.commentCountLabel(post.commentCount),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _FeedActionButton(
                  icon: post.isLiked
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  label: AppStrings.likeAction,
                  isActive: post.isLiked,
                  onTap: onLikeTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FeedActionButton(
                  icon: Icons.forum_outlined,
                  label: AppStrings.commentAction,
                  onTap: onCommentTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isActive ? AppColors.blue : AppColors.textPrimary;
    final backgroundColor = isActive
        ? AppColors.blue.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = isActive
        ? AppColors.blue.withValues(alpha: 0.4)
        : AppColors.textPrimary.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: foregroundColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: AppTextView.body4(
                label,
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupFeatureCard extends StatelessWidget {
  const _GroupFeatureCard({
    required this.group,
    required this.actionLabel,
    required this.onActionTap,
    required this.onTap,
    this.badgeLabel,
  });

  final _KaizengramGroupCommunity group;
  final String actionLabel;
  final VoidCallback onActionTap;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.hex1b1e27,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 128,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(group.coverImageUrl),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (badgeLabel != null)
                            StatusChip(
                              label: badgeLabel!,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 2,
                              ),
                            ),
                            child: GroupThumbnailImage(
                              imageUrl: group.imageUrl,
                              imagePath: group.imagePath,
                              borderRadius: 12,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (group.newPostsCount > 0)
                      StatusChip(
                        label: AppStrings.newPostsLabel(group.newPostsCount),
                        backgroundColor: Colors.black.withValues(alpha: 0.24),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body1(
                      group.name,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 6),
                    AppTextView.body4(
                      AppStrings.privacyMeta(
                        group.privacyLabel,
                        group.category,
                      ),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    AppTextView.body2(
                      group.description,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppTextView.body4(
                            AppStrings.activityMeta(
                              AppStrings.memberCountLabel(group.memberCount),
                              group.weeklyPosts,
                            ),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GroupsActionChip(
                          label: actionLabel,
                          onTap: onActionTap,
                        ),
                      ],
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

class _GroupsEmptyState extends StatelessWidget {
  const _GroupsEmptyState({
    required this.onClearSearch,
    required this.showClearAction,
  });

  final VoidCallback onClearSearch;
  final bool showClearAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.groups_2_outlined,
            color: AppColors.textSecondary,
            size: 34,
          ),
          const SizedBox(height: 14),
          const AppTextView.body1(
            AppStrings.emptySearchTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const AppTextView.body2(
            AppStrings.emptySearchSubtitle,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          if (showClearAction) ...<Widget>[
            const SizedBox(height: 14),
            PrimaryGroupsButton(
              label: AppStrings.clearSearch,
              onTap: onClearSearch,
            ),
          ],
        ],
      ),
    );
  }
}

class _KaizengramGroupDetailScreen extends StatefulWidget {
  const _KaizengramGroupDetailScreen({
    required this.group,
    required this.posts,
    required this.members,
    required this.directoryPeople,
    required this.currentUser,
    required this.onGroupUpdated,
    required this.onGroupMembersUpdated,
    required this.onPostCreated,
    required this.onPostUpdated,
    required this.onAuthorTap,
  });

  final _KaizengramGroupCommunity group;
  final List<_GroupFeedPost> posts;
  final List<_GroupPerson> members;
  final List<_GroupPerson> directoryPeople;
  final _GroupPerson currentUser;
  final ValueChanged<_KaizengramGroupCommunity> onGroupUpdated;
  final void Function(_KaizengramGroupCommunity, List<_GroupPerson>)
  onGroupMembersUpdated;
  final ValueChanged<_GroupFeedPost> onPostCreated;
  final ValueChanged<_GroupFeedPost> onPostUpdated;
  final ValueChanged<_GroupFeedPost> onAuthorTap;

  @override
  State<_KaizengramGroupDetailScreen> createState() =>
      _KaizengramGroupDetailScreenState();
}

class _KaizengramGroupDetailScreenState
    extends State<_KaizengramGroupDetailScreen>
    with KaizengramNotifierState<_KaizengramGroupDetailScreen> {
  late _KaizengramGroupCommunity _group;
  late List<_GroupFeedPost> _posts;
  late List<_GroupPerson> _members;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _posts = widget.posts;
    _members = widget.members;
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      return Scaffold(
        backgroundColor: AppColors.hex111317,
        appBar: AppBar(
          backgroundColor: AppColors.hex111317,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 18,
          title: AppTextView.body1(
            _group.name,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
          actions: _group.isJoined
              ? <Widget>[
                  IconButton(
                    onPressed: _confirmLeaveGroup,
                    tooltip: AppStrings.leaveGroupAction,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                ]
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: <Widget>[
            _GroupDetailHero(
              group: _group,
              onJoinTap: _toggleJoined,
              onInviteTap: _openInvitePeopleSheet,
              onSecondaryTap: _handleSecondaryAction,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: GroupSummaryTile(
                    icon: Icons.groups_2_outlined,
                    label: AppStrings.summaryJoined,
                    value: AppStrings.memberCountLabel(_group.memberCount),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GroupSummaryTile(
                    icon: Icons.dynamic_feed_outlined,
                    label: AppStrings.sectionHighlights,
                    value: AppStrings.weeklyPostsLabel(_group.weeklyPosts),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GroupSummaryTile(
                    icon: Icons.bolt_outlined,
                    label: AppStrings.sectionRecent,
                    value: AppStrings.newPostsLabel(_group.newPostsCount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupsSection(
              title: AppStrings.detailAboutHeader,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.hex1b1e27,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body2(
                      _group.description,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        InlineMetaChip(label: _group.category),
                        InlineMetaChip(label: _group.privacyLabel),
                        InlineMetaChip(
                          label: AppStrings.memberCountLabel(
                            _group.memberCount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GroupsSection(
              title: AppStrings.detailPostsHeader,
              child: Column(
                children: _posts
                    .map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupPostListCard(
                          group: _group,
                          post: post,
                          onAuthorTap: () => widget.onAuthorTap(post),
                          onLikeTap: () => _togglePostLike(post),
                          onCommentTap: () => _showCommentsBottomSheet(post),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _toggleJoined() {
    if (_group.isJoined) {
      _confirmLeaveGroup();
      return;
    }

    final nextGroup = _group.copyWith(
      isJoined: true,
      hasInvite: false,
      isPinned: _group.isManaged ? true : _group.isPinned,
    );
    updateView(() => _group = nextGroup);
    widget.onGroupUpdated(nextGroup);
  }

  Future<void> _handleSecondaryAction() async {
    if (_group.isManaged) {
      await _openManageSheet();
      return;
    }

    if (!_group.isJoined) {
      _showSnackBar(AppStrings.joinGroupToPostMessage(_group.name));
      return;
    }

    await _openWritePostSheet();
  }

  Future<void> _openManageSheet() async {
    final selectedAction = await showModalBottomSheet<_GroupManageAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupManageBottomSheet(group: _group),
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _GroupManageAction.editDetails:
        await _openEditGroupSheet();
        break;
      case _GroupManageAction.invitePeople:
        await _openInvitePeopleSheet();
        break;
      case _GroupManageAction.togglePin:
        _togglePinnedState();
        break;
      case _GroupManageAction.leaveGroup:
        await _confirmLeaveGroup();
        break;
    }
  }

  Future<void> _openEditGroupSheet() async {
    final draft = await showModalBottomSheet<_CreateGroupDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGroupBottomSheet(
        initialDraft: _CreateGroupDraft(
          name: _group.name,
          about: _group.description,
          topic: _group.category,
          isPrivate: _group.isPrivate,
          imagePath: _group.imagePath,
          coverImagePath: _group.coverImagePath,
        ),
      ),
    );

    if (draft == null) {
      return;
    }

    final updatedGroup = _group.copyWith(
      name: draft.name,
      description: draft.about,
      category: draft.topic,
      isPrivate: draft.isPrivate,
      icon: _iconForTopic(draft.topic),
      accentColor: _accentForTopic(draft.topic),
      imagePath: draft.imagePath,
      coverImagePath: draft.coverImagePath,
      imageUrl: _imageForTopic(draft.topic),
      coverImageUrl: _coverImageForTopic(draft.topic),
    );

    updateView(() => _group = updatedGroup);
    widget.onGroupUpdated(updatedGroup);
    _showSnackBar(AppStrings.groupUpdatedMessage(updatedGroup.name));
  }

  Future<void> _openWritePostSheet() async {
    final draft = await showModalBottomSheet<_GroupCreatePostDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupWritePostBottomSheet(
        groupName: _group.name,
        authorName: widget.currentUser.name,
        authorAvatarImagePath: widget.currentUser.avatarImagePath,
        authorAvatarUrl: widget.currentUser.avatarUrl,
      ),
    );

    if (draft == null) {
      return;
    }

    final trimmedMessage = draft.message.trim();
    final attachments = draft.attachments
        .where((attachment) => attachment.path.trim().isNotEmpty)
        .take(kaizengramMessageAttachmentLimit)
        .toList(growable: false);
    if (trimmedMessage.isEmpty && attachments.isEmpty) {
      return;
    }

    final createdPost = _GroupFeedPost(
      id: '${_group.id}-post-${DateTime.now().microsecondsSinceEpoch}',
      authorName: widget.currentUser.name,
      authorAvatarImagePath: widget.currentUser.avatarImagePath,
      authorAvatarUrl: widget.currentUser.avatarUrl,
      authorRole: widget.currentUser.role,
      timeLabel: AppStrings.justNowTimeLabel,
      content: trimmedMessage,
      reactionCount: 0,
      comments: const <_GroupPostComment>[],
      attachments: attachments,
      showFallbackCoverImage: false,
    );

    final updatedGroup = _group.copyWith(
      weeklyPosts: _group.weeklyPosts + 1,
      newPostsCount: _group.newPostsCount + 1,
      hasInvite: false,
    );

    updateView(() {
      _group = updatedGroup;
      _posts = <_GroupFeedPost>[createdPost, ..._posts];
    });

    widget.onGroupUpdated(updatedGroup);
    widget.onPostCreated(createdPost);
    _showSnackBar(AppStrings.groupPostedMessage(updatedGroup.name));
  }

  Future<void> _showCommentsBottomSheet(_GroupFeedPost post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupCommentsBottomSheet(
        group: _group,
        post: post,
        onPostUpdated: _updatePost,
      ),
    );
  }

  void _updatePost(_GroupFeedPost updatedPost) {
    updateView(() {
      _posts = _posts
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(growable: false);
    });
    widget.onPostUpdated(updatedPost);
  }

  void _togglePostLike(_GroupFeedPost post) {
    _updatePost(post.toggledLike());
  }

  Future<void> _openInvitePeopleSheet() async {
    final invitedPeople = await showModalBottomSheet<List<_GroupPerson>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupInvitePeopleBottomSheet(
        group: _group,
        members: _members,
        directoryPeople: widget.directoryPeople,
      ),
    );

    if (invitedPeople == null || invitedPeople.isEmpty) {
      return;
    }

    final existingEmails = _members
        .map((member) => member.normalizedEmail)
        .toSet();
    final newMembers = invitedPeople
        .where((member) => existingEmails.add(member.normalizedEmail))
        .toList(growable: false);

    if (newMembers.isEmpty) {
      return;
    }

    final updatedGroup = _group.copyWith(
      memberCount: _group.memberCount + newMembers.length,
    );
    final updatedMembers = <_GroupPerson>[..._members, ...newMembers];

    updateView(() {
      _group = updatedGroup;
      _members = updatedMembers;
    });

    widget.onGroupMembersUpdated(updatedGroup, updatedMembers);
    _showSnackBar(
      AppStrings.invitePeopleAddedMessage(_group.name, newMembers.length),
    );
  }

  void _togglePinnedState() {
    final updatedGroup = _group.copyWith(isPinned: !_group.isPinned);
    updateView(() => _group = updatedGroup);
    widget.onGroupUpdated(updatedGroup);
    _showSnackBar(
      updatedGroup.isPinned
          ? AppStrings.groupPinnedMessage(updatedGroup.name)
          : AppStrings.groupUnpinnedMessage(updatedGroup.name),
    );
  }

  IconData _iconForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return Icons.local_hospital_outlined;
      case AppStrings.categoryTraining:
        return Icons.school_outlined;
      case AppStrings.categoryAudit:
        return Icons.fact_check_outlined;
      case AppStrings.categoryLeadership:
        return Icons.workspace_premium_outlined;
      case AppStrings.categoryPeopleOps:
        return Icons.people_outline_rounded;
      case AppStrings.categoryTechnology:
        return Icons.memory_outlined;
      default:
        return Icons.groups_2_outlined;
    }
  }

  Color _accentForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return AppColors.blue;
      case AppStrings.categoryTraining:
        return AppColors.progressColor;
      case AppStrings.categoryAudit:
        return AppColors.hexff8e5d;
      case AppStrings.categoryLeadership:
        return AppColors.hex7ea6ff;
      case AppStrings.categoryPeopleOps:
        return AppColors.hexff7d7d;
      case AppStrings.categoryTechnology:
        return AppColors.secondaryColor;
      default:
        return AppColors.blue;
    }
  }

  String _imageForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return 'https://images.unsplash.com/photo-1584515933487-779824d29309?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryTraining:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryAudit:
        return 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryLeadership:
        return 'https://images.unsplash.com/photo-1552664730-d307ca884978?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryPeopleOps:
        return 'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=300&q=80';
      case AppStrings.categoryTechnology:
        return 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=300&q=80';
      default:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=300&q=80';
    }
  }

  String _coverImageForTopic(String topic) {
    switch (topic) {
      case AppStrings.categoryClinicOps:
        return 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryTraining:
        return 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryAudit:
        return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryLeadership:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryPeopleOps:
        return 'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?auto=format&fit=crop&w=1200&q=80';
      case AppStrings.categoryTechnology:
        return 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80';
      default:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80';
    }
  }

  Future<void> _confirmLeaveGroup() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppConfirmationDialog(
          title: AppStrings.leaveGroupConfirmTitle,
          description: AppStrings.leaveGroupDescription(_group.name),
          confirmText: AppStrings.leaveGroupConfirmButton,
          cancelText: AppStrings.stayGroupAction,
          onCancelCallback: () async {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
          onConfirmCallback: () async {
            Navigator.of(dialogContext, rootNavigator: true).pop();
            _leaveGroup();
          },
        );
      },
    );
  }

  void _leaveGroup() {
    final nextGroup = _group.copyWith(
      isJoined: false,
      isManaged: false,
      isPinned: false,
      hasInvite: false,
    );
    updateView(() => _group = nextGroup);
    widget.onGroupUpdated(nextGroup);
    _showSnackBar(AppStrings.leftGroupMessage(_group.name));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _GroupManageAction { editDetails, invitePeople, togglePin, leaveGroup }

class _GroupDetailHero extends StatelessWidget {
  const _GroupDetailHero({
    required this.group,
    required this.onJoinTap,
    required this.onInviteTap,
    required this.onSecondaryTap,
  });

  final _KaizengramGroupCommunity group;
  final VoidCallback onJoinTap;
  final VoidCallback onInviteTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: _GroupCoverImage(
              imageUrl: group.coverImageUrl,
              imagePath: group.coverImagePath,
              height: 170,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 2,
                    ),
                  ),
                  child: GroupThumbnailImage(
                    imageUrl: group.imageUrl,
                    imagePath: group.imagePath,
                    borderRadius: 16,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextView.body1(
                  group.name,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
                if (group.isPinned) ...<Widget>[
                  const SizedBox(height: 10),
                  const _PinnedGroupIcon(size: 32, iconSize: 18),
                ],
                const SizedBox(height: 6),
                AppTextView.body4(
                  AppStrings.privacyMeta(group.privacyLabel, group.category),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 8),
                AppTextView.body2(
                  group.description,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PrimaryGroupsButton(
                        label: group.isJoined
                            ? AppStrings.joinedAction
                            : AppStrings.joinAction,
                        onTap: onJoinTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryGroupsButton(
                        label: AppStrings.detailInvite,
                        onTap: onInviteTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryGroupsButton(
                        label: group.isManaged
                            ? AppStrings.detailManage
                            : AppStrings.detailWritePost,
                        onTap: onSecondaryTap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCoverImage extends StatelessWidget {
  const _GroupCoverImage({
    required this.imageUrl,
    required this.height,
    this.imagePath,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final String imageUrl;
  final String? imagePath;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolvedGroupAvatarImageProvider(
      imagePath: imagePath,
      imageUrl: imageUrl,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: imageProvider == null
          ? _GroupCoverImageFallback(height: height)
          : Image(
              image: imageProvider,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _GroupCoverImageFallback(height: height),
            ),
    );
  }
}

class _GroupCoverImageFallback extends StatelessWidget {
  const _GroupCoverImageFallback({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: AppColors.hex232834,
    );
  }
}

class _PinnedGroupIcon extends StatelessWidget {
  const _PinnedGroupIcon({this.size = 26, this.iconSize = 14});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondaryColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(
          (size * 0.38).clamp(12.0, double.infinity).toDouble(),
        ),
        border: Border.all(
          color: AppColors.secondaryColor.withValues(alpha: 0.30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.secondaryColor.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.push_pin_rounded,
        size: iconSize,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _GroupManageBottomSheet extends StatelessWidget {
  const _GroupManageBottomSheet({required this.group});

  final _KaizengramGroupCommunity group;

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.hex111317,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const AppTextView.body1(
                  AppStrings.groupManageSheetTitle,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                const SizedBox(height: 6),
                AppTextView.body4(
                  AppStrings.groupManageSheetSubtitle(group.name),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 18),
                _GroupManageActionTile(
                  icon: Icons.edit_outlined,
                  label: AppStrings.groupManageEditAction,
                  onTap: () =>
                      Navigator.of(context).pop(_GroupManageAction.editDetails),
                ),
                const SizedBox(height: 10),
                _GroupManageActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: AppStrings.groupManageInviteAction,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GroupManageAction.invitePeople),
                ),
                const SizedBox(height: 10),
                _GroupManageActionTile(
                  icon: group.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  label: group.isPinned
                      ? AppStrings.groupManageUnpinAction
                      : AppStrings.groupManagePinAction,
                  onTap: () =>
                      Navigator.of(context).pop(_GroupManageAction.togglePin),
                ),
                const SizedBox(height: 10),
                _GroupManageActionTile(
                  icon: Icons.logout_rounded,
                  label: AppStrings.leaveGroupAction,
                  isDestructive: true,
                  onTap: () =>
                      Navigator.of(context).pop(_GroupManageAction.leaveGroup),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryGroupsButton(
                    label: AppStrings.actionClose,
                    onTap: () => Navigator.of(context).pop(),
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

class _GroupManageActionTile extends StatelessWidget {
  const _GroupManageActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isDestructive
        ? AppColors.red
        : AppColors.textPrimary;
    final backgroundColor = isDestructive
        ? AppColors.red.withValues(alpha: 0.12)
        : AppColors.hex1b1e27;
    final borderColor = isDestructive
        ? AppColors.red.withValues(alpha: 0.22)
        : AppColors.textPrimary.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: foregroundColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foregroundColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextView.body2(
                  label,
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: foregroundColor.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCreatePostDraft {
  const _GroupCreatePostDraft({
    required this.message,
    required this.attachments,
  });

  final String message;
  final List<KaizengramMessageAttachment> attachments;
}

class _GroupAttachmentPreviewStrip extends StatelessWidget {
  const _GroupAttachmentPreviewStrip({
    required this.attachments,
    this.removable = false,
    this.onRemoveAttachment,
    this.singleMediaHeight = 164,
  });

  final List<KaizengramMessageAttachment> attachments;
  final bool removable;
  final ValueChanged<String>? onRemoveAttachment;
  final double singleMediaHeight;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    if (removable) {
      const spacing = 8.0;
      const mediaCardSize = 92.0;
      const pdfCardWidth = 220.0;

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark3,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppTextView.body4(
              AppStrings.selectedMediaLabel(
                attachments.length,
                kaizengramMessageAttachmentLimit,
              ),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: mediaCardSize,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List<Widget>.generate(attachments.length * 2 - 1, (
                    index,
                  ) {
                    if (index.isOdd) {
                      return const SizedBox(width: spacing);
                    }

                    final attachmentIndex = index ~/ 2;
                    final attachment = attachments[attachmentIndex];
                    return _GroupAttachmentPreviewCard(
                      attachment: attachment,
                      width: attachment.isPdf ? pdfCardWidth : mediaCardSize,
                      height: mediaCardSize,
                      useDraftStyle: true,
                      onOpen: () => _openAttachment(context, attachmentIndex),
                      onRemove: onRemoveAttachment == null
                          ? null
                          : () => onRemoveAttachment!(attachment.path),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (attachments.length == 1) {
      final selectedAttachment = attachments.first;
      return _GroupAttachmentPreviewCard(
        attachment: selectedAttachment,
        height: selectedAttachment.isPdf ? 104 : singleMediaHeight,
        onOpen: () => _openAttachment(context, 0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const maxSquareSide = 92.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final rawSquareSide =
            (availableWidth - (spacing * (attachments.length - 1))) /
            attachments.length;
        final squareSide = rawSquareSide > maxSquareSide
            ? maxSquareSide
            : rawSquareSide;

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
              final attachment = attachments[attachmentIndex];
              return _GroupAttachmentPreviewCard(
                attachment: attachment,
                width: squareSide,
                height: squareSide,
                onOpen: () => _openAttachment(context, attachmentIndex),
              );
            }),
          ),
        );
      },
    );
  }

  void _openAttachment(BuildContext context, int index) {
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
  }
}

class _GroupAttachmentPreviewCard extends StatelessWidget {
  const _GroupAttachmentPreviewCard({
    required this.attachment,
    required this.height,
    this.width,
    this.useDraftStyle = false,
    this.onOpen,
    this.onRemove,
  });

  final KaizengramMessageAttachment attachment;
  final double height;
  final double? width;
  final bool useDraftStyle;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final useCompactStyle = !useDraftStyle && width != null;
    final mediaChild = attachment.isPdf
        ? _GroupPdfPreviewCard(
            attachment: attachment,
            onOpen: onOpen,
            useDraftStyle: useDraftStyle,
            useCompactStyle: useCompactStyle,
          )
        : attachment.isVideo
        ? ChatVideoPreview(
            videoPath: attachment.path,
            maxHeight: height,
            muted: true,
            playButtonSize: useDraftStyle
                ? 30
                : width == null
                ? 48
                : 34,
            playIconSize: useDraftStyle
                ? 16
                : width == null
                ? 26
                : 18,
            onTapOverride: onOpen,
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
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) =>
                          const _GroupAttachmentFallback(),
                    )
                  : Image.file(
                      File(attachment.path),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) =>
                          const _GroupAttachmentFallback(),
                    ),
            ),
          );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: useDraftStyle
                    ? AppColors.hex111317
                    : AppColors.surfaceDark3,
                child: mediaChild,
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.44),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
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

class _GroupPdfPreviewCard extends StatelessWidget {
  const _GroupPdfPreviewCard({
    required this.attachment,
    this.onOpen,
    this.useDraftStyle = false,
    this.useCompactStyle = false,
  });

  final KaizengramMessageAttachment attachment;
  final VoidCallback? onOpen;
  final bool useDraftStyle;
  final bool useCompactStyle;

  @override
  Widget build(BuildContext context) {
    final fileName = _groupAttachmentFileName(attachment.path);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(useCompactStyle ? 10 : 12),
          child: useDraftStyle
              ? Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.secondaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: useCompactStyle ? 34 : 44,
                      height: useCompactStyle ? 34 : 44,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.secondaryColor,
                        size: useCompactStyle ? 18 : 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      maxLines: useCompactStyle ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: useCompactStyle ? 10 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GroupAttachmentFallback extends StatelessWidget {
  const _GroupAttachmentFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.hex232834,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
        size: 28,
      ),
    );
  }
}

String _groupAttachmentFileName(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return AppStrings.documentMessageLabel;
  }

  final resolvedPath = Uri.tryParse(normalizedPath)?.path ?? normalizedPath;
  final fileName =
      resolvedPath.split('/').where((part) => part.isNotEmpty).isEmpty
      ? normalizedPath
      : resolvedPath.split('/').where((part) => part.isNotEmpty).last;
  return fileName.isEmpty ? AppStrings.documentMessageLabel : fileName;
}

ImageProvider<Object>? _resolvedGroupAvatarImageProvider({
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

class _GroupWritePostBottomSheet extends StatefulWidget {
  const _GroupWritePostBottomSheet({
    required this.groupName,
    required this.authorName,
    this.authorAvatarImagePath,
    required this.authorAvatarUrl,
  });

  final String groupName;
  final String authorName;
  final String? authorAvatarImagePath;
  final String authorAvatarUrl;

  @override
  State<_GroupWritePostBottomSheet> createState() =>
      _GroupWritePostBottomSheetState();
}

class _GroupWritePostBottomSheetState extends State<_GroupWritePostBottomSheet>
    with KaizengramNotifierState<_GroupWritePostBottomSheet> {
  late final TextEditingController _postController;
  List<KaizengramMessageAttachment> _draftAttachments =
      <KaizengramMessageAttachment>[];
  var _isPickingMedia = false;
  var _isPickingAttachment = false;

  @override
  void initState() {
    super.initState();
    _postController = TextEditingController();
    _postController.addListener(notifyView);
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final canSubmit =
          _postController.text.trim().isNotEmpty ||
          _draftAttachments.isNotEmpty;
      final hasLinkPreview =
          kaizengramFirstLinkInText(_postController.text) != null;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final preferredHeight = MediaQuery.sizeOf(context).height * 0.88;
              final targetHeight = constraints.maxHeight < preferredHeight
                  ? constraints.maxHeight
                  : preferredHeight;

              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: targetHeight,
                  child: AppKeyboardBottomSheetSurface(
                    color: AppColors.hex111317,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const AppTextView.body1(
                            AppStrings.kaizengramComposeSheetTitle,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                          const SizedBox(height: 6),
                          AppTextView.body2(
                            AppStrings.groupPostSheetSubtitle(widget.groupName),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          const SizedBox(height: 18),
                          Builder(
                            builder: (context) {
                              final authorImageProvider =
                                  _resolvedGroupAvatarImageProvider(
                                    imagePath: widget.authorAvatarImagePath,
                                    imageUrl: widget.authorAvatarUrl,
                                  );

                              return Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.hex232834,
                                    backgroundImage: authorImageProvider,
                                    child: authorImageProvider == null
                                        ? const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.textPrimary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppTextView.body2(
                                      widget.authorName,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  AppTextView.body4(
                                    AppStrings.kaizengramComposeSourceTitle,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child:
                                            KaizengramComposePostActionButton(
                                              icon:
                                                  Icons.photo_library_outlined,
                                              label: AppStrings
                                                  .attachmentPickerMediaTitle,
                                              isBusy: _isPickingMedia,
                                              onTap:
                                                  _isPickingMedia ||
                                                      _isPickingAttachment
                                                  ? null
                                                  : _pickMedia,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child:
                                            KaizengramComposePostActionButton(
                                              icon:
                                                  Icons.picture_as_pdf_outlined,
                                              label: AppStrings
                                                  .attachmentPickerPdfTitle,
                                              isBusy: _isPickingAttachment,
                                              onTap:
                                                  _isPickingMedia ||
                                                      _isPickingAttachment
                                                  ? null
                                                  : _pickAttachments,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (_draftAttachments.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 14),
                                    _GroupAttachmentPreviewStrip(
                                      attachments: _draftAttachments,
                                      removable: true,
                                      onRemoveAttachment: _removeAttachment,
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.hex1b1e27,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _postController,
                                      minLines: 9,
                                      maxLines: 12,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      cursorColor: AppColors.textPrimary,
                                      decoration: const InputDecoration(
                                        hintText: AppStrings
                                            .kaizengramComposeSheetHint,
                                        hintStyle: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                    ),
                                  ),
                                  if (hasLinkPreview) ...<Widget>[
                                    const SizedBox(height: 12),
                                    KaizengramTextLinkPreview(
                                      text: _postController.text,
                                      topSpacing: 0,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  AppTextView.body4(
                                    AppStrings.kaizengramComposeSubtitle,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: SecondaryGroupsButton(
                                  label:
                                      AppStrings.kaizengramComposeButtonCancel,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: IgnorePointer(
                                  ignoring: !canSubmit,
                                  child: Opacity(
                                    opacity: canSubmit ? 1 : 0.45,
                                    child: PrimaryGroupsButton(
                                      label: AppStrings
                                          .kaizengramComposeButtonPost,
                                      onTap: _submit,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Future<void> _pickMedia() async {
    if (_isPickingMedia || _isPickingAttachment) {
      return;
    }

    final availableSlots =
        kaizengramMessageAttachmentLimit - _draftAttachments.length;
    if (availableSlots <= 0) {
      _showComposerSnackBar(AppStrings.mediaLimitError);
      return;
    }

    updateView(() => _isPickingMedia = true);

    try {
      final nextAttachments = await KaizengramMessageAttachmentPicker.pick(
        source: KaizengramMessageAttachmentPickSource.media,
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
      if (mounted) {
        _showComposerSnackBar(AppStrings.pickMediaError);
      }
    } finally {
      if (mounted) {
        updateView(() => _isPickingMedia = false);
      } else {
        _isPickingMedia = false;
      }
    }
  }

  Future<void> _pickAttachments() async {
    if (_isPickingMedia || _isPickingAttachment) {
      return;
    }

    final availableSlots =
        kaizengramMessageAttachmentLimit - _draftAttachments.length;
    if (availableSlots <= 0) {
      _showComposerSnackBar(AppStrings.mediaLimitError);
      return;
    }

    updateView(() => _isPickingAttachment = true);

    try {
      final nextAttachments = await KaizengramMessageAttachmentPicker.pick(
        source: KaizengramMessageAttachmentPickSource.pdf,
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
      if (mounted) {
        _showComposerSnackBar(AppStrings.kaizengramErrorPickAttachmentFailed);
      }
    } finally {
      if (mounted) {
        updateView(() => _isPickingAttachment = false);
      } else {
        _isPickingAttachment = false;
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

  void _showComposerSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    Navigator.of(context).pop(
      _GroupCreatePostDraft(
        message: _postController.text.trim(),
        attachments: List<KaizengramMessageAttachment>.unmodifiable(
          _draftAttachments,
        ),
      ),
    );
  }
}

class _GroupInvitePeopleBottomSheet extends StatefulWidget {
  const _GroupInvitePeopleBottomSheet({
    required this.group,
    required this.members,
    required this.directoryPeople,
  });

  final _KaizengramGroupCommunity group;
  final List<_GroupPerson> members;
  final List<_GroupPerson> directoryPeople;

  @override
  State<_GroupInvitePeopleBottomSheet> createState() =>
      _GroupInvitePeopleBottomSheetState();
}

class _GroupInvitePeopleBottomSheetState
    extends State<_GroupInvitePeopleBottomSheet>
    with KaizengramNotifierState<_GroupInvitePeopleBottomSheet> {
  late final TextEditingController _emailController;
  final List<_GroupPerson> _selectedPeople = <_GroupPerson>[];
  String? _errorText;

  Set<String> get _memberEmails =>
      widget.members.map((member) => member.normalizedEmail).toSet();

  Set<String> get _selectedEmails =>
      _selectedPeople.map((person) => person.normalizedEmail).toSet();

  String get _query => _emailController.text.trim();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _emailController.addListener(() {
      if (_errorText != null) {
        updateView(() => _errorText = null);
        return;
      }
      notifyView();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;
      final pendingTypedCandidate = _pendingTypedCandidate;
      final suggestedPeople = _suggestedPeople
          .where(
            (person) =>
                pendingTypedCandidate == null ||
                person.normalizedEmail != pendingTypedCandidate.normalizedEmail,
          )
          .toList(growable: false);

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            height: sheetHeight,
            child: AppKeyboardBottomSheetSurface(
              color: AppColors.hex111317,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const AppTextView.body1(
                      AppStrings.invitePeopleSheetTitle,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    const SizedBox(height: 6),
                    AppTextView.body4(
                      AppStrings.invitePeopleSheetSubtitle(widget.group.name),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 18),
                    AppTextView.body3(
                      AppStrings.invitePeopleSearchLabel,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.hex1b1e27,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _errorText == null
                              ? AppColors.textPrimary.withValues(alpha: 0.08)
                              : AppColors.red.withValues(alpha: 0.70),
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.textPrimary,
                        decoration: const InputDecoration(
                          hintText: AppStrings.invitePeopleSearchHint,
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
                    if (_selectedPeople.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      AppTextView.body4(
                        AppStrings.invitePeopleSelectedCountLabel(
                          _selectedPeople.length,
                        ),
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedPeople
                            .map(
                              (person) => _SelectedGroupPersonChip(
                                person: person,
                                onRemove: () => _removeSelectedPerson(person),
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
                          AppTextView.body3(
                            AppStrings.invitePeopleSuggestedHeader,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          const SizedBox(height: 12),
                          if (pendingTypedCandidate != null) ...<Widget>[
                            _GroupInviteSuggestionTile(
                              person: pendingTypedCandidate,
                              subtitle:
                                  pendingTypedCandidate.role ==
                                      AppStrings.invitePeopleExternalRole
                                  ? AppStrings.invitePeopleEmailSubtitle(
                                      pendingTypedCandidate.email,
                                    )
                                  : pendingTypedCandidate.email,
                              actionLabel: AppStrings.invitePeopleAddAction,
                              onTap: () =>
                                  _addSelectedPerson(pendingTypedCandidate),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (suggestedPeople.isEmpty &&
                              pendingTypedCandidate == null)
                            const _GroupInviteEmptyState()
                          else
                            ...suggestedPeople.map(
                              (person) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _GroupInviteSuggestionTile(
                                  person: person,
                                  subtitle: person.email,
                                  actionLabel: _actionLabelForPerson(person),
                                  onTap: _isPersonSelectable(person)
                                      ? () => _addSelectedPerson(person)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SecondaryGroupsButton(
                            label: AppStrings.createCancel,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryGroupsButton(
                            label: AppStrings.invitePeopleConfirmAction,
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

  List<_GroupPerson> get _suggestedPeople {
    final people = widget.directoryPeople
        .where((person) {
          return person.matchesQuery(_query);
        })
        .toList(growable: false);

    people.sort((left, right) {
      final leftCategoryMatch = left.category == widget.group.category;
      final rightCategoryMatch = right.category == widget.group.category;
      if (leftCategoryMatch != rightCategoryMatch) {
        return leftCategoryMatch ? -1 : 1;
      }

      final normalizedQuery = _query.toLowerCase();
      if (normalizedQuery.isNotEmpty) {
        final leftStarts =
            left.name.toLowerCase().startsWith(normalizedQuery) ||
            left.email.toLowerCase().startsWith(normalizedQuery);
        final rightStarts =
            right.name.toLowerCase().startsWith(normalizedQuery) ||
            right.email.toLowerCase().startsWith(normalizedQuery);
        if (leftStarts != rightStarts) {
          return leftStarts ? -1 : 1;
        }
      }

      return left.name.compareTo(right.name);
    });

    return _query.isEmpty ? people.take(8).toList(growable: false) : people;
  }

  _GroupPerson? get _pendingTypedCandidate {
    final normalizedEmail = _normalizeInviteEmail(_query);
    if (normalizedEmail.isEmpty) {
      return null;
    }

    for (final person in widget.directoryPeople) {
      if (person.normalizedEmail == normalizedEmail &&
          _isPersonSelectable(person)) {
        return person;
      }
    }

    if (!_isValidInviteEmail(normalizedEmail) ||
        _memberEmails.contains(normalizedEmail) ||
        _selectedEmails.contains(normalizedEmail)) {
      return null;
    }

    return _GroupPerson(
      id: 'external-$normalizedEmail',
      name: _displayNameFromEmail(normalizedEmail),
      email: normalizedEmail,
      role: AppStrings.invitePeopleExternalRole,
      category: AppStrings.categoryAll,
      avatarUrl: _avatarUrlForSeed('external-$normalizedEmail'),
      phone: AppStrings.profileValueUnavailable,
      dateOfBirth: AppStrings.profileValueUnavailable,
      gender: AppStrings.profileValueUnavailable,
    );
  }

  bool _isPersonSelectable(_GroupPerson person) {
    return !_memberEmails.contains(person.normalizedEmail) &&
        !_selectedEmails.contains(person.normalizedEmail);
  }

  String _actionLabelForPerson(_GroupPerson person) {
    if (_memberEmails.contains(person.normalizedEmail)) {
      return AppStrings.invitePeopleAlreadyMemberLabel;
    }
    if (_selectedEmails.contains(person.normalizedEmail)) {
      return AppStrings.invitePeopleSelectedLabel;
    }
    return AppStrings.invitePeopleAddAction;
  }

  void _addSelectedPerson(_GroupPerson person) {
    if (!_isPersonSelectable(person)) {
      return;
    }

    updateView(() {
      _selectedPeople.add(person);
      _emailController.clear();
      _errorText = null;
    });
  }

  void _removeSelectedPerson(_GroupPerson person) {
    updateView(() {
      _selectedPeople.removeWhere(
        (selected) => selected.normalizedEmail == person.normalizedEmail,
      );
      _errorText = null;
    });
  }

  void _addPendingCandidate() {
    final candidate = _pendingTypedCandidate;
    if (candidate == null) {
      updateView(() {
        _errorText = _query.isEmpty
            ? AppStrings.invitePeopleEmptySelection
            : AppStrings.invitePeopleEmailInvalid;
      });
      return;
    }

    _addSelectedPerson(candidate);
  }

  void _submit() {
    final pendingCandidate = _pendingTypedCandidate;
    final invitees = <_GroupPerson>[
      ..._selectedPeople,
      if (pendingCandidate != null &&
          !_selectedEmails.contains(pendingCandidate.normalizedEmail))
        pendingCandidate,
    ];

    if (invitees.isEmpty) {
      updateView(() {
        _errorText = _query.isEmpty
            ? AppStrings.invitePeopleEmptySelection
            : AppStrings.invitePeopleEmailInvalid;
      });
      return;
    }

    Navigator.of(context).pop(invitees);
  }
}

class _GroupInviteSuggestionTile extends StatelessWidget {
  const _GroupInviteSuggestionTile({
    required this.person,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final _GroupPerson person;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(person.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextView.body3(
                  person.name,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                AppTextView.body4(
                  subtitle,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 4),
                AppTextView.body4(
                  person.role,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
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

class _SelectedGroupPersonChip extends StatelessWidget {
  const _SelectedGroupPersonChip({
    required this.person,
    required this.onRemove,
  });

  final _GroupPerson person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextView.body4(
            person.name,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupInviteEmptyState extends StatelessWidget {
  const _GroupInviteEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.person_search_rounded, color: AppColors.textSecondary),
          SizedBox(height: 10),
          AppTextView.body3(
            AppStrings.invitePeopleNoResultsTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          SizedBox(height: 6),
          AppTextView.body4(
            AppStrings.invitePeopleNoResultsSubtitle,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GroupCommentsBottomSheet extends StatefulWidget {
  const _GroupCommentsBottomSheet({
    required this.group,
    required this.post,
    required this.onPostUpdated,
  });

  final _KaizengramGroupCommunity group;
  final _GroupFeedPost post;
  final ValueChanged<_GroupFeedPost> onPostUpdated;

  @override
  State<_GroupCommentsBottomSheet> createState() =>
      _GroupCommentsBottomSheetState();
}

class _GroupCommentsBottomSheetState extends State<_GroupCommentsBottomSheet>
    with KaizengramNotifierState<_GroupCommentsBottomSheet> {
  late final TextEditingController _commentController;
  late _GroupFeedPost _post;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentController.addListener(notifyView);
    _post = widget.post;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final canSubmit = _commentController.text.trim().isNotEmpty;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: AppKeyboardBottomSheetSurface(
            color: AppColors.hex111317,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppTextView.body1(
                    AppStrings.commentsSheetTitle,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 6),
                  AppTextView.body4(
                    AppStrings.commentsSheetSubtitle(widget.group.name),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: _post.comments.isEmpty
                        ? const _GroupCommentsEmptyState()
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _post.comments.length,
                            itemBuilder: (context, index) {
                              return _GroupCommentTile(
                                comment: _post.comments[index],
                              );
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.hex1b1e27,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 3,
                            minLines: 1,
                            cursorHeight: 17,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            cursorColor: AppColors.textPrimary,
                            decoration: const InputDecoration(
                              hintText: AppStrings.commentInputHint,
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: IgnorePointer(
                          ignoring: !canSubmit,
                          child: Opacity(
                            opacity: canSubmit ? 1 : 0.45,
                            child: PrimaryGroupsButton(
                              label: AppStrings.postCommentAction,
                              onTap: _submitComment,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _submitComment() {
    final message = _commentController.text.trim();
    if (message.isEmpty) {
      return;
    }

    final updatedPost = _post.copyWith(
      comments: <_GroupPostComment>[
        _GroupPostComment(
          authorName: AppStrings.currentUserCommentName,
          authorAvatarUrl:
              'https://i.pravatar.cc/150?u=${Uri.encodeComponent('${widget.group.id}-current-user')}',
          timeLabel: AppStrings.justNowTimeLabel,
          message: message,
        ),
        ..._post.comments,
      ],
    );

    updateView(() {
      _post = updatedPost;
      _commentController.clear();
    });

    widget.onPostUpdated(updatedPost);
  }
}

class _GroupCommentTile extends StatelessWidget {
  const _GroupCommentTile({required this.comment});

  final _GroupPostComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(comment.authorAvatarUrl),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.hex1b1e27,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextView.body4(
                  AppStrings.authorMeta(comment.authorName, comment.timeLabel),
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 6),
                AppTextView.body4(
                  comment.message,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupCommentsEmptyState extends StatelessWidget {
  const _GroupCommentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.hex1b1e27,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: const <Widget>[
          Icon(Icons.forum_outlined, color: AppColors.textSecondary),
          SizedBox(height: 10),
          AppTextView.body3(
            AppStrings.commentsEmptyTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          SizedBox(height: 6),
          AppTextView.body4(
            AppStrings.commentsEmptySubtitle,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CreateGroupBottomSheet extends StatelessWidget {
  const _CreateGroupBottomSheet();

  @override
  Widget build(BuildContext context) {
    return const _GroupDraftBottomSheet(
      title: AppStrings.createSheetTitle,
      subtitle: AppStrings.createSheetSubtitle,
      submitLabel: AppStrings.createSubmit,
    );
  }
}

class _EditGroupBottomSheet extends StatelessWidget {
  const _EditGroupBottomSheet({required this.initialDraft});

  final _CreateGroupDraft initialDraft;

  @override
  Widget build(BuildContext context) {
    return _GroupDraftBottomSheet(
      title: AppStrings.groupEditSheetTitle,
      subtitle: AppStrings.groupEditSheetSubtitle,
      submitLabel: AppStrings.groupSaveAction,
      initialDraft: initialDraft,
    );
  }
}

class _GroupDraftBottomSheet extends StatefulWidget {
  const _GroupDraftBottomSheet({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    this.initialDraft,
  });

  final String title;
  final String subtitle;
  final String submitLabel;
  final _CreateGroupDraft? initialDraft;

  @override
  State<_GroupDraftBottomSheet> createState() => _GroupDraftBottomSheetState();
}

class _GroupDraftBottomSheetState extends State<_GroupDraftBottomSheet>
    with KaizengramNotifierState<_GroupDraftBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  late bool _isPrivate;
  late String _selectedTopic;
  String? _selectedImagePath;
  String? _selectedCoverImagePath;
  bool _isPickingImage = false;
  bool _isPickingCoverImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft?.name);
    _aboutController = TextEditingController(text: widget.initialDraft?.about);
    _isPrivate = widget.initialDraft?.isPrivate ?? true;
    _selectedTopic = widget.initialDraft?.topic ?? AppStrings.categoryClinicOps;
    final normalizedSelectedImagePath = widget.initialDraft?.imagePath?.trim();
    _selectedImagePath =
        normalizedSelectedImagePath == null ||
            normalizedSelectedImagePath.isEmpty
        ? null
        : normalizedSelectedImagePath;
    final normalizedSelectedCoverImagePath = widget.initialDraft?.coverImagePath
        ?.trim();
    _selectedCoverImagePath =
        normalizedSelectedCoverImagePath == null ||
            normalizedSelectedCoverImagePath.isEmpty
        ? null
        : normalizedSelectedCoverImagePath;
    _nameController.addListener(notifyView);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final canSubmit = _nameController.text.trim().isNotEmpty;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppKeyboardBottomSheetSurface(
          color: AppColors.hex111317,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppTextView.body1(
                    widget.title,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 6),
                  AppTextView.body2(
                    widget.subtitle,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 18),
                  _GroupImagePickerTile(
                    label: AppStrings.groupImageLabel,
                    emptyTitle: AppStrings.groupImageHint,
                    selectedSubtitle: AppStrings.groupImageSelectedHint,
                    placeholderIcon: Icons.groups_2_rounded,
                    selectedImagePath: _selectedImagePath,
                    isPickingImage: _isPickingImage,
                    onTap: _pickImage,
                    onRemoveTap: _selectedImagePath == null
                        ? null
                        : _removeImage,
                  ),
                  const SizedBox(height: 14),
                  _GroupImagePickerTile(
                    label: AppStrings.groupBackgroundImageLabel,
                    emptyTitle: AppStrings.groupBackgroundImageHint,
                    selectedSubtitle:
                        AppStrings.groupBackgroundImageSelectedHint,
                    placeholderIcon: Icons.wallpaper_rounded,
                    selectedImagePath: _selectedCoverImagePath,
                    isPickingImage: _isPickingCoverImage,
                    onTap: _pickCoverImage,
                    onRemoveTap: _selectedCoverImagePath == null
                        ? null
                        : _removeCoverImage,
                  ),
                  const SizedBox(height: 14),
                  _LabeledTextField(
                    label: AppStrings.nameLabel,
                    hint: AppStrings.nameHint,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 14),
                  _LabeledTextField(
                    label: AppStrings.aboutLabel,
                    hint: AppStrings.aboutHint,
                    controller: _aboutController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  AppTextView.body3(
                    AppStrings.privacyLabel,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SelectableOptionTile(
                          label: AppStrings.privacyPrivate,
                          isSelected: _isPrivate,
                          onTap: () => updateView(() => _isPrivate = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SelectableOptionTile(
                          label: AppStrings.privacyPublic,
                          isSelected: !_isPrivate,
                          onTap: () => updateView(() => _isPrivate = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextView.body3(
                    AppStrings.topicLabel,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppStrings.browseTopics
                        .where((topic) => topic != AppStrings.categoryAll)
                        .map(
                          (topic) => _SelectableChip(
                            label: topic,
                            isSelected: _selectedTopic == topic,
                            onTap: () =>
                                updateView(() => _selectedTopic = topic),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SecondaryGroupsButton(
                          label: AppStrings.createCancel,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: !canSubmit,
                          child: Opacity(
                            opacity: canSubmit ? 1 : 0.45,
                            child: PrimaryGroupsButton(
                              label: widget.submitLabel,
                              onTap: _submit,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _pickImage() async {
    await _pickDraftImage(forCover: false);
  }

  Future<void> _pickCoverImage() async {
    await _pickDraftImage(forCover: true);
  }

  Future<void> _pickDraftImage({required bool forCover}) async {
    final isPicking = forCover ? _isPickingCoverImage : _isPickingImage;
    if (isPicking) {
      return;
    }

    updateView(() {
      if (forCover) {
        _isPickingCoverImage = true;
      } else {
        _isPickingImage = true;
      }
    });

    try {
      final currentPath = forCover
          ? _selectedCoverImagePath
          : _selectedImagePath;
      final pickedImages = await KaizengramMessageAttachmentPicker.pickImages(
        availableSlots: 1,
        existingPaths: currentPath == null
            ? const <String>[]
            : <String>[currentPath],
      );
      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      updateView(() {
        if (forCover) {
          _selectedCoverImagePath = pickedImages.first.path;
        } else {
          _selectedImagePath = pickedImages.first.path;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.pickImageError)),
        );
    } finally {
      if (mounted) {
        updateView(() {
          if (forCover) {
            _isPickingCoverImage = false;
          } else {
            _isPickingImage = false;
          }
        });
      } else if (forCover) {
        _isPickingCoverImage = false;
      } else {
        _isPickingImage = false;
      }
    }
  }

  void _removeCoverImage() {
    updateView(() {
      _selectedCoverImagePath = null;
    });
  }

  void _removeImage() {
    updateView(() {
      _selectedImagePath = null;
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      _CreateGroupDraft(
        name: _nameController.text.trim(),
        about: _aboutController.text.trim().isEmpty
            ? AppStrings.focusSummary(
                _nameController.text.trim(),
                _selectedTopic,
              )
            : _aboutController.text.trim(),
        topic: _selectedTopic,
        isPrivate: _isPrivate,
        imagePath: _selectedImagePath,
        coverImagePath: _selectedCoverImagePath,
      ),
    );
  }
}

class _CreateGroupDraft {
  const _CreateGroupDraft({
    required this.name,
    required this.about,
    required this.topic,
    required this.isPrivate,
    this.imagePath,
    this.coverImagePath,
  });

  final String name;
  final String about;
  final String topic;
  final bool isPrivate;
  final String? imagePath;
  final String? coverImagePath;
}

class _GroupImagePickerTile extends StatelessWidget {
  const _GroupImagePickerTile({
    required this.label,
    required this.emptyTitle,
    required this.selectedSubtitle,
    required this.placeholderIcon,
    required this.selectedImagePath,
    required this.isPickingImage,
    required this.onTap,
    this.onRemoveTap,
  });

  final String label;
  final String emptyTitle;
  final String selectedSubtitle;
  final IconData placeholderIcon;
  final String? selectedImagePath;
  final bool isPickingImage;
  final VoidCallback onTap;
  final VoidCallback? onRemoveTap;

  @override
  Widget build(BuildContext context) {
    final hasSelectedImage =
        selectedImagePath != null && selectedImagePath!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextView.body3(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isPickingImage ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.hex1b1e27,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: hasSelectedImage
                          ? Image.file(
                              File(selectedImagePath!),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.hex232834,
                              alignment: Alignment.center,
                              child: Icon(
                                placeholderIcon,
                                color: AppColors.secondaryColor,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppTextView.body2(
                          hasSelectedImage
                              ? AppStrings.actionChangeImage
                              : emptyTitle,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(height: 4),
                        AppTextView.body4(
                          hasSelectedImage
                              ? selectedSubtitle
                              : AppStrings.actionAddImage,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  isPickingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Icon(
                          hasSelectedImage
                              ? Icons.edit_outlined
                              : Icons.add_photo_alternate_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                ],
              ),
            ),
          ),
        ),
        if (hasSelectedImage && onRemoveTap != null) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onRemoveTap,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: AppTextView.body4(
                  AppStrings.actionRemoveImage,
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextView.body3(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.hex1b1e27,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.textPrimary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.16)
              : AppColors.hex1b1e27,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.secondaryColor.withValues(alpha: 0.50)
                : AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: AppTextView.body3(
            label,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue.withValues(alpha: 0.18)
              : AppColors.hex1b1e27,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.blue.withValues(alpha: 0.42)
                : AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: AppTextView.body4(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
