import 'package:flutter/material.dart';

import 'app_gradient_action_button.dart';

class AppBarGradientAction extends StatelessWidget {
  const AppBarGradientAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.endPadding = 8,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double endPadding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: endPadding),
      child: Center(
        child: SizedBox.square(
          dimension: compact ? 30 : 35,
          child: AppGradientActionButton(
            label: label,
            icon: icon,
            iconOnly: true,
            iconSize: compact ? 20 : 24,
            minHeight: compact ? 30 : 35,
            borderRadius: compact ? 10 : 12,
            boxShadows: const <BoxShadow>[],
            padding: EdgeInsets.zero,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
