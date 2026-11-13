import 'package:flutter/material.dart';

import 'app_bar_gradient_action.dart';

class AppBarCreateAction extends StatelessWidget {
  const AppBarCreateAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppBarGradientAction(
      label: label,
      icon: Icons.add_rounded,
      onTap: onTap,
    );
  }
}
