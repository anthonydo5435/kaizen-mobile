import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/seat_audit.dart';
import '../pages/check_in_filter_sheet.dart';
import '../providers/general_seats_controller.dart';
import 'check_in_details_period_controls.dart';
import 'general_seat_audit_card.dart';

class GeneralSeatsList extends StatefulWidget {
  const GeneralSeatsList({
    super.key,
    required this.yearQuarterOptions,
    required this.onSeatTap,
    required this.bottomInset,
  });

  final List<String> yearQuarterOptions;
  final ValueChanged<SeatAudit> onSeatTap;
  final double bottomInset;

  @override
  State<GeneralSeatsList> createState() => _GeneralSeatsListState();
}

class _GeneralSeatsListState extends State<GeneralSeatsList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    final controller = context.read<GeneralSeatsController>();
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter <= 360 &&
        controller.paginationError == null) {
      controller.loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GeneralSeatsController>();
    return RefreshIndicator(
      color: AppColors.purple2,
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey('general-seats-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            sliver: SliverToBoxAdapter(
              child: _PeriodFilterRow(
                controller: controller,
                onFilterTap: () => _openFilterSheet(controller),
                onQuarterChanged: (label) => _changeQuarter(controller, label),
              ),
            ),
          ),
          if (controller.isLoading && controller.seats.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: FastCircularProgressIndicator()),
            )
          else if (controller.seats.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ListMessage(
                message: controller.error ?? AppStrings.auditGeneralSeatsEmpty,
                onRetry: controller.error == null ? null : controller.refresh,
              ),
            )
          else ...[
            if (controller.error != null)
              SliverToBoxAdapter(
                child: _ListMessage(
                  message: controller.error!,
                  onRetry: controller.refresh,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverList.separated(
                itemCount: controller.seats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, index) {
                  final seat = controller.seats[index];
                  return GeneralSeatAuditCard(
                    seat: seat,
                    scoreLabel: controller.scoreLabel(seat),
                    onView: () => widget.onSeatTap(seat),
                  );
                },
              ),
            ),
            if (controller.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: FastCircularProgressIndicator()),
                ),
              ),
            if (controller.paginationError != null)
              SliverToBoxAdapter(
                child: _ListMessage(
                  message: controller.paginationError!,
                  onRetry: controller.loadNextPage,
                ),
              ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset + 24)),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(GeneralSeatsController controller) async {
    final result = await showModalBottomSheet<CheckInFilterResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CheckInFilterSheet(
        yearQuarterOptions: widget.yearQuarterOptions,
        seatProfileOptions: const [],
        initialYearQuarter: controller.yearQuarterLabel,
        showSeatProfile: false,
      ),
    );
    if (!mounted || result == null) return;
    _scrollController.jumpTo(0);
    await controller.applyYearQuarter(result.yearQuarter);
  }

  Future<void> _changeQuarter(
    GeneralSeatsController controller,
    String? label,
  ) async {
    if (label == null || label == controller.yearQuarterLabel) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await controller.applyYearQuarter(label);
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({
    required this.controller,
    required this.onFilterTap,
    required this.onQuarterChanged,
  });

  final GeneralSeatsController controller;
  final VoidCallback onFilterTap;
  final ValueChanged<String?> onQuarterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CheckInQuarterSelector(
            key: const ValueKey('general-seats-quarter-selector'),
            year: controller.year,
            quarter: controller.quarter,
            yearOptions: controller.yearOptions,
            onChanged: onQuarterChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: AppStrings.auditFiltersTitle,
          onPressed: onFilterTap,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(
            Icons.tune_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppTextView.body(
            message,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text(AppStrings.finalCheckInReportTryAgain),
            ),
        ],
      ),
    );
  }
}
