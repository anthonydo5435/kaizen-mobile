import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_text_view.dart';

class SeatProfileDottedActionButton extends StatelessWidget {
  const SeatProfileDottedActionButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final borderColor = isEnabled
        ? AppColors.secondaryColor
        : AppColors.fieldBorder.withValues(alpha: 0.28);
    const minimumHeight = 48.0;

    return Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: CustomPaint(
        painter: _SeatProfileDottedRoundedBorderPainter(color: borderColor, radius: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: double.infinity,
              height: minimumHeight,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark3.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AppTextView.body(
                  label,
                  color: isEnabled ? AppColors.secondaryColor : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatProfileDottedRoundedBorderPainter extends CustomPainter {
  const _SeatProfileDottedRoundedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final inset = paint.strokeWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - (inset * 2), size.height - (inset * 2)),
      Radius.circular(radius > inset ? radius - inset : radius),
    );
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeatProfileDottedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
