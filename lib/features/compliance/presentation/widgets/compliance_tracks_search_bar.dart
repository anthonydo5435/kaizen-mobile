import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_listing_search_bar.dart';

class ComplianceTracksSearchBar extends StatelessWidget {
  const ComplianceTracksSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AppListingSearchBar(
        controller: controller,
        onChanged: onChanged,
        hintText: AppStrings.complianceSearchHint,
        onFilterTap: onFilterTap,
        showClearButton: false,
      ),
    );
  }
}
