import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/seat_audit.dart';
import '../providers/check_in_controller.dart';
import '../providers/general_seats_controller.dart';

class CheckInSeatProfileSwitcher extends StatelessWidget {
  const CheckInSeatProfileSwitcher({super.key, required this.onSelected});

  final ValueChanged<SeatAudit> onSelected;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GeneralSeatsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppTextView.body1(
                AppStrings.auditSwitchSeatProfile,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (controller.seats.length > 4 || controller.hasMoreSeats)
              TextButton(
                onPressed: () => _openAllSeats(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const AppTextView.body2(
                  AppStrings.auditSeeMore,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: _SeatCards(onSelected: onSelected, preview: true),
        ),
      ],
    );
  }

  Future<void> _openAllSeats(BuildContext context) async {
    final seats = context.read<GeneralSeatsController>();
    final audit = context.read<CheckInController>();
    final selected = await showDialog<SeatAudit>(
      context: context,
      useSafeArea: false,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GeneralSeatsController>.value(value: seats),
          ChangeNotifierProvider<CheckInController>.value(value: audit),
        ],
        child: Dialog.fullscreen(
          backgroundColor: AppColors.mainBg,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Builder(
                    builder: (dialogContext) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: AppTextView.body1(
                              AppStrings.auditSwitchSeatProfile,
                              color: AppColors.secondaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppOverlayCloseButton(
                            onTap: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (dialogContext) => _SeatCards(
                        onSelected: (seat) =>
                            Navigator.of(dialogContext).pop(seat),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (context.mounted && selected != null) onSelected(selected);
  }
}

class _SeatCards extends StatelessWidget {
  const _SeatCards({required this.onSelected, this.preview = false});

  final ValueChanged<SeatAudit> onSelected;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GeneralSeatsController>();
    final auditController = context.watch<CheckInController>();
    final seats = preview
        ? controller.seats.take(4).toList(growable: false)
        : controller.seats;
    if (seats.isEmpty) {
      return Center(
        child: controller.isLoading
            ? const FastCircularProgressIndicator()
            : _SeatLoadMessage(
                message: controller.error ?? AppStrings.auditGeneralSeatsEmpty,
                onRetry: controller.error == null ? null : controller.refresh,
              ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!preview &&
            notification.metrics.extentAfter <= 360 &&
            controller.paginationError == null) {
          controller.loadNextPage();
        }
        return false;
      },
      child: ListView.separated(
        scrollDirection: preview ? Axis.horizontal : Axis.vertical,
        padding: EdgeInsets.zero,
        itemCount: seats.length + (!preview && controller.hasMoreSeats ? 1 : 0),
        separatorBuilder: (_, __) =>
            SizedBox(width: preview ? 12 : 0, height: preview ? 0 : 12),
        itemBuilder: (_, index) {
          if (index == seats.length) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: controller.isLoadingMore
                  ? const Center(child: FastCircularProgressIndicator())
                  : _SeatLoadMessage(
                      message: controller.paginationError,
                      onRetry: controller.loadNextPage,
                      actionLabel: controller.paginationError == null
                          ? AppStrings.auditSeeMore
                          : AppStrings.finalCheckInReportTryAgain,
                    ),
            );
          }
          final seat = seats[index];
          final isSelected = auditController.isCurrentAuditSeat(seat);
          return Semantics(
            selected: isSelected,
            button: true,
            child: GestureDetector(
              key: ValueKey('check-in-seat-profile-${seat.uuid}'),
              onTap: () => onSelected(seat),
              child: Container(
                width: preview ? 120 : null,
                height: preview ? null : 80,
                padding: const EdgeInsets.all(10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.secondaryColor
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: AppTextView.body3(
                  seat.job.title,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeatLoadMessage extends StatelessWidget {
  const _SeatLoadMessage({
    this.message,
    this.onRetry,
    this.actionLabel = AppStrings.finalCheckInReportTryAgain,
  });

  final String? message;
  final VoidCallback? onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (message != null)
          AppTextView.body3(
            message!,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(actionLabel)),
      ],
    );
  }
}
