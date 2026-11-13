import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared outline for dialog surfaces, preserving each dialog's corner radius.
abstract final class AppDialogStyle {
  static final BorderSide borderSide = BorderSide(
    color: AppColors.purple2.withValues(alpha: 0.4),
    width: 0.5,
  );

  static final Border border = Border.fromBorderSide(borderSide);

  static RoundedRectangleBorder shape({double radius = 16}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderSide,
      );
}
