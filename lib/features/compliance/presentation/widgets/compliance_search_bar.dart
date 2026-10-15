import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_listing_search_bar.dart';

class ComplianceSearchBar extends StatelessWidget {
  const ComplianceSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClearTap,
    this.showClearButton = false,
    this.onFilterTap,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClearTap;
  final bool showClearButton;
  final VoidCallback? onFilterTap;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return AppListingSearchBar(
      controller: controller,
      onChanged: onChanged,
      hintText: hintText ?? AppStrings.auditSearchHint,
      onFilterTap: onFilterTap,
      onClearTap: onClearTap,
      showClearButton: showClearButton,
    );
  }
}
