part of '../pages/seat_description_final_check_in_report.dart';

class _FinalReportContent extends StatelessWidget {
  const _FinalReportContent({required this.controller});

  final SeatDescriptionFinalCheckInReportController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: FastCircularProgressIndicator());
    }
    if (controller.hasLoadError || !controller.hasReport) {
      return _FinalReportFeedback(
        title: controller.hasLoadError
            ? AppStrings.finalCheckInReportLoadError
            : AppStrings.finalCheckInReportEmpty,
        actionLabel: controller.hasLoadError
            ? AppStrings.finalCheckInReportTryAgain
            : AppStrings.finalCheckInReportRefresh,
        onAction: controller.refresh,
      );
    }
    final trainingRoute = controller.trainingRoute;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      child: Column(
        children: [
          _ReportIdentityCard(
            seatTitle: controller.seatTitle,
            profileNames: controller.profileNames,
            auditFactorLabel: controller.auditFactorLabel,
            seatTypeLabel: controller.seatTypeLabel,
          ),
          const SizedBox(height: 16),
          _ConfidenceLevelCard(
            confidenceLevel: controller.confidenceLevel,
            performancePercentage: controller.performancePercentage,
            ratings: controller.ratings,
          ),
          const SizedBox(height: 16),
          _DetailTextCard(
            title: AppStrings.finalCheckInReportDescription,
            body: controller.description,
            bottomActionLabel: trainingRoute == null
                ? null
                : AppStrings.seatProfileViewTrainings,
            onBottomActionTap: trainingRoute == null
                ? null
                : () => _openTrainingEditor(
                    context,
                    trainingRoute,
                    controller.canManageTraining,
                  ),
          ),
          const SizedBox(height: 16),
          _DetailTextCard(
            title: AppStrings.finalCheckInReportSpecifics,
            body: controller.specifics,
          ),
          const SizedBox(height: 16),
          _PerformanceTrendCard(data: controller.trendData),
          const SizedBox(height: 16),
          _CommentsCard(
            comments: controller.comments,
            hasComments: controller.hasComments,
            isLoading: controller.isLoadingComments,
            searchController: controller.commentsSearchController,
            onSearchChanged: controller.updateCommentsQuery,
          ),
        ],
      ),
    );
  }

  Future<void> _openTrainingEditor(
    BuildContext context,
    SeatDescriptionTrainingRoute route,
    bool canManageTraining,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EditTrainingScreen(
        trainingRoute: route,
        initialModuleId: route.initialModuleId,
        canManageTraining: canManageTraining,
        useNonBlockingVideoUpload: true,
      ),
    ),
  );
}

class _ReportIdentityCard extends StatelessWidget {
  const _ReportIdentityCard({
    required this.seatTitle,
    required this.profileNames,
    required this.auditFactorLabel,
    required this.seatTypeLabel,
  });

  final String seatTitle;
  final String profileNames;
  final String auditFactorLabel;
  final String seatTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.finalCheckInReportSeat,
                  value: seatTitle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.finalCheckInReportName,
                  value: profileNames,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.finalCheckInReportAuditFactor,
                  value: auditFactorLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.finalCheckInReportSeatType,
                  value: seatTypeLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportMetaItem extends StatelessWidget {
  const _ReportMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextView.body3(
          label,
          color: AppColors.grey1,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 6),
        AppTextView.body1(
          value,
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

class _ConfidenceLevelCard extends StatelessWidget {
  const _ConfidenceLevelCard({
    required this.confidenceLevel,
    required this.performancePercentage,
    required this.ratings,
  });

  final String confidenceLevel;
  final String performancePercentage;
  final List<FinalCheckInReportRatingData> ratings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.confidenceLevel,
                  value: confidenceLevel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportMetaItem(
                  label: AppStrings.finalCheckInReportPercentage,
                  value: performancePercentage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppTextView.body1(
            AppStrings.finalCheckInReportRating,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 16),
          ...ratings.indexed.map(
            (entry) => Padding(
              padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 12),
              child: _RatingBarRow(data: entry.$2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({required this.data});

  final FinalCheckInReportRatingData data;

  @override
  Widget build(BuildContext context) {
    final color = switch (data.rating) {
      AuditRating.great => AppColors.green1,
      AuditRating.almostThere => AppColors.orange1,
      _ => AppColors.red1,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextView.body2(
                data.label,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppTextView.body2(
              data.count.toString(),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          value: data.percentageLabel,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: Colors.white12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: data.ratio,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTextCard extends StatelessWidget {
  const _DetailTextCard({
    required this.title,
    required this.body,
    this.bottomActionLabel,
    this.onBottomActionTap,
  });

  final String title;
  final String body;
  final String? bottomActionLabel;
  final VoidCallback? onBottomActionTap;

  @override
  Widget build(BuildContext context) {
    final resolvedActionLabel = bottomActionLabel?.trim() ?? '';
    final showBottomAction =
        resolvedActionLabel.isNotEmpty && onBottomActionTap != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            title,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          AppTextView.body(
            body,
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          if (showBottomAction) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onBottomActionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    resolvedActionLabel,
                    style: const TextStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.secondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
