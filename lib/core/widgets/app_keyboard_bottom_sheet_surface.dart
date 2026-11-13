import 'package:flutter/material.dart';

/// Keeps the lower sheet corners visually connected to the keyboard.
class AppKeyboardBottomSheetSurface extends StatelessWidget {
  const AppKeyboardBottomSheetSurface({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.width,
    this.height,
    this.border,
    this.clipBehavior = Clip.antiAlias,
    this.keyboardCornerExtent = 24,
  });

  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;
  final BoxBorder? border;
  final Clip clipBehavior;
  final double keyboardCornerExtent;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height,
          clipBehavior: clipBehavior,
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
        if (keyboardVisible)
          Positioned(
            key: const ValueKey('app-keyboard-bottom-sheet-corner-fill'),
            left: 0,
            right: 0,
            bottom: -keyboardCornerExtent,
            height: keyboardCornerExtent,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _KeyboardCornerFillPainter(color: color),
              ),
            ),
          ),
      ],
    );
  }
}

class _KeyboardCornerFillPainter extends CustomPainter {
  const _KeyboardCornerFillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height.clamp(0, size.width / 2).toDouble();
    final corners = Path()
      ..moveTo(0, 0)
      ..lineTo(radius, 0)
      ..arcToPoint(
        Offset(0, radius),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..close()
      ..moveTo(size.width, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
      ..close();
    canvas.drawPath(corners, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _KeyboardCornerFillPainter oldDelegate) =>
      oldDelegate.color != color;
}
