part of '../pages/check_in_single_description.dart';

class _DescriptionAssignmentCard extends StatelessWidget {
  const _DescriptionAssignmentCard({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppTextView.body(
            AppStrings.auditAssignTo,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AssignmentChoice(
                    title: AppStrings.auditAssignToTeamMember,
                    subtitle: controller.assignmentSummary,
                    subtitleSpan: controller.isAssignedToGeneral
                        ? null
                        : TextSpan(
                            text: AppStrings.auditAssignedToPrefix,
                            children: [
                              TextSpan(
                                text: AppStrings.auditAssignedTeamMemberCount(
                                  controller.assignedTeamMemberCount,
                                ),
                                style: const TextStyle(color: AppColors.orange1),
                              ),
                            ],
                          ),
                    icon: Icons.people_alt_outlined,
                    color: AppColors.orange1,
                    isSelected: !controller.isAssignedToGeneral,
                    onTap: controller.canOpenAssignmentSelection
                        ? () => _openPeopleDialog(context)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AssignmentChoice(
                    title: AppStrings.auditAddToGeneralCheckIn,
                    subtitle: AppStrings.auditAddToGeneralCheckInHint,
                    icon: Icons.fact_check_outlined,
                    color: AppColors.progressColor,
                    isSelected: controller.isAssignedToGeneral,
                    onTap: controller.canAssignCheckIn
                        ? () => _confirmGeneralAssignment(context)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (controller.isAssigning) ...[
            const SizedBox(height: 12),
            const Center(child: FastCircularProgressIndicator(width: 18, height: 18)),
          ],
        ],
      ),
    );
  }

  Future<void> _openPeopleDialog(BuildContext context) async {
    controller.beginAssignmentSelection();
    await showDialog<void>(
      context: context,
      builder: (_) => _DescriptionAssignmentDialog(controller: controller),
    );
  }

  Future<void> _confirmGeneralAssignment(BuildContext context) async {
    if (controller.isAssignedToGeneral) return;
    final confirmed = await _showAssignmentConfirmation(
      context,
      title: AppStrings.auditGeneralAssignmentConfirmTitle,
      description: AppStrings.auditGeneralAssignmentConfirmMessage,
    );
    if (!confirmed || !context.mounted) return;
    await controller.assignToGeneral();
  }
}

class _AssignmentChoice extends StatelessWidget {
  const _AssignmentChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.subtitleSpan,
  });

  final String title;
  final String subtitle;
  final TextSpan? subtitleSpan;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: AppColors.trainingLessonActionSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? color : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 12),
                AppTextView.body(
                  title,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  subtitleSpan ?? TextSpan(text: subtitle),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionAssignmentDialog extends StatefulWidget {
  const _DescriptionAssignmentDialog({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  State<_DescriptionAssignmentDialog> createState() => _DescriptionAssignmentDialogState();
}

class _DescriptionAssignmentDialogState extends State<_DescriptionAssignmentDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return PopScope(
          canPop: !controller.isAssigning,
          child: Dialog(
            backgroundColor: AppColors.surfaceDark,
            shape: AppDialogStyle.shape(radius: 20),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: AppTextView.body(
                              AppStrings.selectTeamMember,
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Tooltip(
                            message: AppStrings.auditAssignmentClose,
                            child: AppOverlayCloseButton(
                              onTap: controller.isAssigning
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppListingSearchBar(
                        controller: _searchController,
                        hintText: AppStrings.auditSearchTeamMembersHint,
                        onChanged: controller.updateAssignmentSearch,
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _AssignmentPeopleList(controller: controller)),
                      if (controller.assignmentSaveError != null) ...[
                        const SizedBox(height: 12),
                        AppTextView.body2(
                          controller.assignmentSaveError!,
                          color: AppColors.red1,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        text: AppStrings.auditAssignTeamMembers,
                        isLoading: controller.isAssigning,
                        onPressed: controller.canConfirmAssignment ? _confirmAssignment : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAssignment() async {
    FocusScope.of(context).unfocus();
    final confirmed = await _showAssignmentConfirmation(
      context,
      title: AppStrings.auditMemberAssignmentConfirmTitle,
      description: AppStrings.auditMemberAssignmentConfirmMessage,
    );
    if (!confirmed || !mounted) return;
    final saved = await widget.controller.confirmAssignment();
    if (saved && mounted) Navigator.of(context).pop();
  }
}

class _AssignmentPeopleList extends StatelessWidget {
  const _AssignmentPeopleList({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingAssignmentMembers ||
        (controller.isLoading && !controller.hasLoadedAudit)) {
      return const Center(child: FastCircularProgressIndicator());
    }
    final hasAuditLoadError = controller.hasLoadError && !controller.hasLoadedAudit;
    final error = hasAuditLoadError
        ? AppStrings.auditUnableToLoadDescriptionDetails
        : controller.assignmentMembersError;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextView.body2(error, color: AppColors.textSecondary, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: hasAuditLoadError
                  ? controller.retryAssignmentAudit
                  : controller.loadAssignmentMembers,
              child: const Text(AppStrings.auditAssignmentRetry),
            ),
          ],
        ),
      );
    }
    final members = controller.visibleAssignmentMembers;
    if (members.isEmpty) {
      return const Center(
        child: AppTextView.body2(
          AppStrings.auditNoTeamMembersFound,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ListView.separated(
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final member = members[index];
          return _AssignmentMemberCard(
            isSelected: controller.isDraftAssigneeSelected(member.uuid),
            onTap: controller.canAssignCheckIn
                ? () => controller.toggleDraftAssignee(member)
                : null,
            name: member.profile.name.trim().isEmpty ? AppStrings.noProfile : member.profile.name,
            imageUrl: CustomFunctions.resolveImageUrl(member.profile.image),
          );
        },
      ),
    );
  }
}

class _AssignmentMemberCard extends StatelessWidget {
  const _AssignmentMemberCard({
    required this.name,
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      checked: isSelected,
      enabled: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 45),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cardBg, AppColors.hex1b1e27],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: onTap == null ? null : (_) => onTap!(),
                    activeColor: AppColors.secondaryColor,
                    checkColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
                const SizedBox(width: 12),
                _AssignmentMemberAvatar(imageUrl: imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextView.body(
                    name,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

class _AssignmentMemberAvatar extends StatelessWidget {
  const _AssignmentMemberAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.person_rounded, size: 34, color: AppColors.textPrimary);
    return ClipOval(
      child: SizedBox.square(
        dimension: 40,
        child: ColoredBox(
          color: AppColors.trainingNavigationInactive,
          child: imageUrl == null
              ? fallback
              : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
        ),
      ),
    );
  }
}

Future<bool> _showAssignmentConfirmation(
  BuildContext context, {
  required String title,
  required String description,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _AssignmentConfirmationDialog(title: title, description: description),
    ) ??
    false;

class _AssignmentConfirmationDialog extends StatelessWidget {
  const _AssignmentConfirmationDialog({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 18),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: AppTextView.body1(
        title,
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      content: AppTextView.body2(
        description,
        color: AppColors.textSecondary,
        fontSize: 14,
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: AppStrings.auditAssignmentConfirmNo,
                onPressed: () => Navigator.of(context).pop(false),
                backgroundColor: AppColors.surfaceDark3,
                borderRadius: 12,
                minimumHeight: 44,
                textSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppGradientActionButton(
                label: AppStrings.auditAssignmentConfirmYes,
                icon: Icons.check_rounded,
                onTap: () => Navigator.of(context).pop(true),
                borderRadius: 12,
                minHeight: 44,
                textSize: 14,
                boxShadows: const [],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
