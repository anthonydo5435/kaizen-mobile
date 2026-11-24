import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_view.dart';

class AppListingTabs extends StatelessWidget {
  const AppListingTabs({super.key, required this.tabs, this.maxLabelLines = 1});

  final List<({String title, bool isSelected, VoidCallback onTap})> tabs;
  final int maxLabelLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 6,
        children: tabs
            .map(
              (tab) => Expanded(
                child: Semantics(
                  button: true,
                  selected: tab.isSelected,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: tab.onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: tab.isSelected
                            ? AppColors.secondaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppTextView.body3(
                        tab.title,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        textAlign: TextAlign.center,
                        maxLines: maxLabelLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
