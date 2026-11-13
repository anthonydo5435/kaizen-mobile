part of '../pages/check_in_single_description.dart';

class _CheckInProfileCard extends StatelessWidget {
  const _CheckInProfileCard({required this.profile});

  final CheckInDescriptionProfileData profile;

  @override
  Widget build(BuildContext context) {
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
                  profile.jobTitle,
                  color: AppColors.secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                AppTextView.body(
                  profile.profileName,
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
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(
                        text: profile.lastAuditDate,
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
          _Avatar(size: 82, imageUrl: profile.imageUrl),
        ],
      ),
    );
  }
}

class _SeatDescriptionCard extends StatelessWidget {
  const _SeatDescriptionCard({required this.seatDescription});

  final String seatDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            AppStrings.auditSeatDescription,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          AppTextView.body(
            seatDescription,
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatefulWidget {
  const _ExpandableCard({
    required this.title,
    required this.body,
    this.trailing,
    this.footer,
  });

  final String title;
  final String body;
  final Widget? trailing;
  final Widget? footer;

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  static const _collapsedLineCount = 4;
  static const _bodyTextStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  late final ValueNotifier<bool> _isExpandedNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  void didUpdateWidget(covariant _ExpandableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _isExpandedNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _isExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextView.body1(
                  widget.title,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final hasMoreThanFourLines = _hasMoreThanFourLines(
                context,
                constraints.maxWidth,
              );

              return ValueListenableBuilder<bool>(
                valueListenable: _isExpandedNotifier,
                builder: (context, isExpanded, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextView.body(
                        widget.body,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        maxLines: isExpanded ? null : _collapsedLineCount,
                        overflow: isExpanded ? null : TextOverflow.ellipsis,
                      ),
                      if (hasMoreThanFourLines) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: _SeeAllAction(
                            isExpanded: isExpanded,
                            onTap: () {
                              _isExpandedNotifier.value = !isExpanded;
                            },
                          ),
                        ),
                      ],
                      if (widget.footer != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: widget.footer!,
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  bool _hasMoreThanFourLines(BuildContext context, double maxWidth) {
    if (maxWidth <= 0 || widget.body.isEmpty) {
      return false;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: widget.body, style: _bodyTextStyle),
      textDirection: Directionality.of(context),
      maxLines: _collapsedLineCount,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    final didExceedMaxLines = textPainter.didExceedMaxLines;
    textPainter.dispose();
    return didExceedMaxLines;
  }
}

class _SeatSpecificsCard extends StatelessWidget {
  const _SeatSpecificsCard({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  Widget build(BuildContext context) {
    return _ExpandableCard(
      title: AppStrings.auditSeatSpecifics,
      body: controller.seatSpecifics,
      trailing: _PillLabel(text: controller.auditTypeLabel),
      footer: _ViewTrainingAction(controller: controller),
    );
  }
}

class _ViewTrainingAction extends StatelessWidget {
  const _ViewTrainingAction({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditTrainingScreen(
              trainingRoute: controller.trainingRoute,
              initialModuleId: controller.trainingRoute.initialModuleId,
              canManageTraining: controller.canManageTraining,
              useNonBlockingVideoUpload: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          AppStrings.seatProfileViewTrainings,
          style: TextStyle(
            color: AppColors.secondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.secondaryColor,
          ),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.orange1,
        borderRadius: BorderRadius.circular(50),
      ),
      child: AppTextView.body2(
        text,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SeeAllAction extends StatelessWidget {
  const _SeeAllAction({this.isExpanded = false, this.onTap});

  final bool isExpanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTextView.body2(
              isExpanded ? AppStrings.auditShowLess : AppStrings.seeAllAction,
              color: AppColors.lightPurple1,
              fontWeight: FontWeight.w500,
            ),
            Icon(
              isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: imageUrl == null
              ? const AssetImage(AppStrings.dummyProfileImagePath)
              : NetworkImage(imageUrl!),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
