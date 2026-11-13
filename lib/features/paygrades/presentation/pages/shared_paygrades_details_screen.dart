import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/paygrade_detail_controller.dart';
import 'paygrade_detail_screen.dart';

class SharedPaygradesDetailsScreen extends StatelessWidget {
  const SharedPaygradesDetailsScreen({super.key, required this.controller});

  final PaygradeDetailController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaygradeDetailController>.value(
      value: controller,
      child: const PaygradeDetailView(isShared: true),
    );
  }
}
