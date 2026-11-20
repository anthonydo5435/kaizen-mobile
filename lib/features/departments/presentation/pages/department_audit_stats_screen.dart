import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../seat_profile/domain/entities/department.dart';
import '../../domain/entities/department_audit_stats.dart';
import '../../domain/usecases/manage_departments_use_case.dart';
import '../providers/department_audit_stats_controller.dart';

class DepartmentAuditStatsScreen extends StatelessWidget {
  const DepartmentAuditStatsScreen({
    super.key,
    required this.department,
    required this.manageDepartments,
  });

  final Department department;
  final ManageDepartmentsUseCase manageDepartments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          DepartmentAuditStatsController(manageDepartments, department.id)
            ..load(),
      child: Scaffold(
        backgroundColor: AppColors.hex111317,
        appBar: AppBar(
          backgroundColor: AppColors.hex1b1e27,
          centerTitle: true,
          leading: const AppBackButton(),
          title: AppTextView.title1(
            department.name,
            color: AppColors.secondaryColor,
            fontSize: 20,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.hex1b1e27, AppColors.hex111317],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: _DepartmentAuditStatsBody(),
          ),
        ),
      ),
    );
  }
}

class _DepartmentAuditStatsBody extends StatelessWidget {
  const _DepartmentAuditStatsBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DepartmentAuditStatsController>();
    final stats = controller.stats;
    if (controller.isLoading) {
      return const Center(child: FastCircularProgressIndicator());
    }
    if (stats == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextView.body2(
                controller.errorMessage ??
                    AppStrings.departmentAuditStatsLoadError,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                text: AppStrings.departmentsRetryAction,
                onPressed: controller.load,
              ),
            ],
          ),
        ),
      );
    }

    final seats = stats.jobStats;
    final header = _DepartmentAuditStatsHeader(stats: stats);
    if (seats.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            sliver: SliverToBoxAdapter(child: header),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment(0, -0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: AppTextView.body2(
                  AppStrings.departmentAuditNoJobStats,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      itemCount: seats.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final seat = seats[index - 1];
        return _SeatAuditStatsCard(key: ValueKey(seat.id), seat: seat);
      },
    );
  }
}

class _DepartmentAuditStatsHeader extends StatelessWidget {
  const _DepartmentAuditStatsHeader({required this.stats});

  final DepartmentAuditStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuditMetricRow(
          score: _AuditMetric(
            label: AppStrings.departmentAuditScore,
            value: stats.score.toStringAsFixed(stats.score == 0 ? 0 : 1),
            valueColor: AppColors.progressColor,
            help: AppStrings.departmentAuditScoreHelp,
          ),
          confidence: _AuditMetric(
            label: AppStrings.confidenceLevel,
            value: AppStrings.departmentAuditConfidenceValue(
              stats.confidenceLevel,
            ),
            valueColor: AppColors.orange1,
            help: AppStrings.departmentAuditConfidenceHelp,
          ),
        ),
        if (stats.jobStats.isNotEmpty) ...[
          const SizedBox(height: 24),
          const AppTextView.body1(
            AppStrings.homeSeatProfiles,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ],
      ],
    );
  }
}

class _SeatAuditStatsCard extends StatelessWidget {
  const _SeatAuditStatsCard({super.key, required this.seat});

  final DepartmentJobAuditStats seat;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceDark2),
        gradient: const LinearGradient(
          colors: [AppColors.cardBg, AppColors.hex111317],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextView.body1(
              seat.name,
              color: AppColors.secondaryColor,
              fontSize: 16,
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${seat.totalMembers}',
                    style: const TextStyle(color: AppColors.progressColor),
                  ),
                  TextSpan(
                    text: AppStrings.departmentAuditMemberSuffix(
                      seat.totalMembers,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            const AppDotDivider(
              color: AppColors.hex51597a,
              opacity: 0.8,
              dotSize: 5,
            ),
            const SizedBox(height: 14),
            _AuditMetricRow(
              score: _AuditMetric(
                label: AppStrings.auditGeneralSeatOverallScore,
                value: seat.score.toStringAsFixed(1),
              ),
              confidence: _AuditMetric(
                label: AppStrings.confidenceLevel,
                value: AppStrings.departmentAuditConfidenceValue(
                  seat.confidenceLevel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditMetricRow extends StatelessWidget {
  const _AuditMetricRow({required this.score, required this.confidence});

  final _AuditMetric score;
  final _AuditMetric confidence;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: score),
          const SizedBox(width: 10),
          Expanded(child: confidence),
        ],
      ),
    );
  }
}

class _AuditMetric extends StatelessWidget {
  const _AuditMetric({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.help,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final helpMessage = help;
    final isSummary = helpMessage != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceDark2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: isSummary
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: isSummary
                        ? AlignmentDirectional.centerStart
                        : Alignment.center,
                    child: AppTextView.title1(
                      value,
                      fontSize: isSummary ? 30 : 22,
                      color: valueColor,
                    ),
                  ),
                ),
                if (helpMessage != null)
                  Tooltip(
                    message: helpMessage,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const SizedBox.square(
                      dimension: 28,
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 19,
                        color: AppColors.secondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AppTextView.body2(
              label,
              fontSize: isSummary ? 13 : 12,
              color: isSummary
                  ? AppColors.textPrimary
                  : AppColors.secondaryColor,
              textAlign: isSummary ? TextAlign.start : TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
