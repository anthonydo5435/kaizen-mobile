import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_bar_create_action.dart';

class TrainingLibraryCreateAction extends StatelessWidget {
  const TrainingLibraryCreateAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppBarCreateAction(label: AppStrings.trainingLibraryCreate, onTap: onTap);
  }
}
