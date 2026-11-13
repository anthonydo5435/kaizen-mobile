import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

class AppRadioSelectionTile extends StatelessWidget {
  const AppRadioSelectionTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.contentPadding = EdgeInsets.zero,
    this.isLoading = false,
  });

  final String title;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: isLoading ? null : onTap,
        selected: isSelected,
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        shape: const Border(),
        minTileHeight: 44,
        minVerticalPadding: 6,
        minLeadingWidth: 20,
        horizontalTitleGap: 12,
        contentPadding: contentPadding,
        leading: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: FastCircularProgressIndicator(width: 20, height: 20),
              )
            : Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.secondaryColor : AppColors.textPrimary,
                size: 20,
              ),
        title: AppTextView.body2(
          title,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
