part of '../pages/check_in_single_description.dart';

class _PassSelectionCard extends StatelessWidget {
  const _PassSelectionCard({required this.controller});

  final CheckInSingleDescriptionController controller;

  @override
  Widget build(BuildContext context) {
    final ratings = controller.ratings;
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
          const AppTextView.body(
            AppStrings.auditSelectRatings,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          if (!controller.isLoading) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              children: ratings
                  .map(
                    (rating) =>
                        _LegendItem(color: rating.color, label: rating.label),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(ratings.length, (index) {
                final rating = ratings[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == ratings.length - 1 ? 0 : 25,
                  ),
                  child: _SelectionCounter(
                    color: controller.canEditRatings
                        ? rating.color
                        : rating.color.withValues(alpha: 0.5),
                    count: rating.count,
                    hasReachedLimit: rating.hasReachedLimit,
                    showDecrementControl: controller.showDecrementControl,
                    onTapCount: controller.canEditRatings
                        ? () => controller.incrementRating(rating.rating)
                        : null,
                    onTapArrow: controller.canEditRatings
                        ? () => controller.decrementRating(rating.rating)
                        : null,
                    canEditBlocks: controller.canEditRatings,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionCounter extends StatelessWidget {
  const _SelectionCounter({
    required this.color,
    required this.count,
    required this.hasReachedLimit,
    this.onTapCount,
    this.onTapArrow,
    required this.canEditBlocks,
    required this.showDecrementControl,
  });

  final Color color;
  final int count;
  final bool hasReachedLimit;
  final VoidCallback? onTapCount;
  final VoidCallback? onTapArrow;
  final bool canEditBlocks;
  final bool showDecrementControl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasReachedLimit ? null : onTapCount,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasReachedLimit ? color.withValues(alpha: 0.5) : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppTextView.body2(
              '$count',
              color: hasReachedLimit ? Colors.white60 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        if (showDecrementControl) ...[
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapArrow,
            child: Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: canEditBlocks
                    ? AppColors.grey1
                    : AppColors.grey1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                canEditBlocks
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.lock_rounded,
                color: Colors.white,
                size: canEditBlocks ? 28 : 18,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
