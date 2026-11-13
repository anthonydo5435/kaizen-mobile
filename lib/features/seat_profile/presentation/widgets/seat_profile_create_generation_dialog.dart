part of '../pages/seat_profile_create_screen.dart';

class _GenerateSeatContentDialog extends StatelessWidget {
  const _GenerateSeatContentDialog();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileCreateController>();

    return PopScope<Object?>(
      canPop: !controller.isGeneratingSeatContent,
      child: Dialog(
        backgroundColor: AppColors.surfaceDark,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: AppDialogStyle.shape(radius: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppTextView.body1(
                        AppStrings.seatProfileGenerateSeatContentDialogTitle,
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _SeatContentDialogCloseButton(
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SeatContentDialogDivider(),
                const SizedBox(height: 24),
                const Center(
                  child: AppTextView.body(
                    AppStrings.seatProfileGenerateSeatContentDialogDescription,
                    color: AppColors.lightPurple1,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                _SeatContentGenerationOptionsCard(controller: controller),
                if (controller.seatContentGenerationErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  _CreateMessageCard(
                    message: controller.seatContentGenerationErrorMessage!,
                  ),
                ],
                const SizedBox(height: 22),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: AppAiGenerateButton(
                      expand: true,
                      minHeight: 48,
                      textSize: 15,
                      fontWeight: FontWeight.w700,
                      label: AppStrings.seatProfileGenerateAction,
                      isLoading: controller.isGeneratingSeatContent,
                      onTap: () async {
                        final didGenerate = await context
                            .read<SeatProfileCreateController>()
                            .generateSeatContentWithAi();
                        if (!context.mounted || !didGenerate) {
                          return;
                        }

                        Navigator.of(context).pop(true);
                      },
                    ),
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

class _SeatContentGenerationOptionsCard extends StatelessWidget {
  const _SeatContentGenerationOptionsCard({required this.controller});

  final SeatProfileCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const AppTextView.body1(
            AppStrings.seatProfileSpecificityLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 16),
          Row(
            children: SeatContentSpecificity.values
                .map(
                  (value) => Expanded(
                    child: _SeatContentOptionChip(
                      label: value.label,
                      isSelected: controller.selectedSpecificity == value,
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => controller.selectSpecificity(value),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
          const AppTextView.body1(
            AppStrings.seatProfileToneLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 16),
          Row(
            children: SeatContentTone.values
                .map(
                  (value) => Expanded(
                    child: _SeatContentOptionChip(
                      label: value.label,
                      isSelected: controller.selectedTone == value,
                      labelFontSize: 11,
                      horizontalPadding: 0,
                      labelSpacing: 4,
                      indicatorSize: 14,
                      selectedDotSize: 6,
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => controller.selectTone(value),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SeatContentOptionChip extends StatelessWidget {
  const _SeatContentOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.labelFontSize = 14,
    this.horizontalPadding = 4,
    this.labelSpacing = 8,
    this.indicatorSize = 16,
    this.selectedDotSize = 8,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double labelFontSize;
  final double horizontalPadding;
  final double labelSpacing;
  final double indicatorSize;
  final double selectedDotSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.secondaryColor
                        : AppColors.lightPurple1,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: selectedDotSize,
                          height: selectedDotSize,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: labelSpacing),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppTextView.body(
                    label,
                    color: AppColors.textPrimary,
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatContentDialogCloseButton extends StatelessWidget {
  const _SeatContentDialogCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1 : 0.55,
      child: AppOverlayCloseButton(onTap: onTap),
    );
  }
}

class _SeatContentDialogDivider extends StatelessWidget {
  const _SeatContentDialogDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SeatContentDialogDividerDot(),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.fieldBorder.withValues(alpha: 0.34),
          ),
        ),
        const _SeatContentDialogDividerDot(),
      ],
    );
  }
}

class _SeatContentDialogDividerDot extends StatelessWidget {
  const _SeatContentDialogDividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: AppColors.hex51597a,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SeatProfileDottedRoundedBorderPainter extends CustomPainter {
  const _SeatProfileDottedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + 6;
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + 4;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _SeatProfileDottedRoundedBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
