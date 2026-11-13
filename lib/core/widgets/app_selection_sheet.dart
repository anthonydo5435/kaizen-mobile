import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_dot_divider.dart';
import 'app_keyboard_bottom_sheet_surface.dart';
import 'app_overlay_close_button.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

class AppSelectionSheet extends StatelessWidget {
  const AppSelectionSheet({
    super.key,
    required this.child,
    this.isBusy = false,
    this.heightFactor = 0.7,
    this.safeAreaBottom = true,
  });

  final Widget child;
  final bool isBusy;
  final double heightFactor;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isBusy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: AppKeyboardBottomSheetSurface(
            color: AppColors.mainBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: Colors.transparent,
              child: ListTileTheme.merge(
                tileColor: AppColors.cardBg,
                selectedTileColor: AppColors.cardBg,
                child: SafeArea(
                  top: false,
                  bottom: safeAreaBottom,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSelectionHeader extends StatelessWidget {
  const AppSelectionHeader({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    this.enabled = true,
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppFilterSheetHeader(
          title: title,
          onClose: enabled ? () => Navigator.of(context).pop() : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            enabled: enabled,
            onChanged: onSearchChanged,
            cursorHeight: 15,
            cursorColor: AppColors.textPrimary,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey1),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.secondaryColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Owns the full header inset so listing filters do not stack extra top gaps.
class AppFilterSheetHeader extends StatelessWidget {
  const AppFilterSheetHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.centerTitle = false,
  });

  final String title;
  final VoidCallback? onClose;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: AppSelectionHeading(
        title: title,
        onClose: onClose,
        centerTitle: centerTitle,
      ),
    );
  }
}

class AppSelectionHeading extends StatelessWidget {
  const AppSelectionHeading({
    super.key,
    required this.title,
    required this.onClose,
    this.centerTitle = false,
  });

  final String title;
  final VoidCallback? onClose;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (centerTitle) const SizedBox(width: 28),
            Expanded(
              child: AppTextView.body1(
                title,
                color: AppColors.secondaryColor,
                fontSize: 18,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              ),
            ),
            AppOverlayCloseButton(onTap: onClose, size: 28),
          ],
        ),
        const SizedBox(height: 12),
        const AppDotDivider(),
      ],
    );
  }
}

class AppSelectionTile extends StatelessWidget {
  const AppSelectionTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
  });

  final String title;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        onTap: isLoading ? null : onTap,
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.secondaryColor : Colors.transparent,
          ),
        ),
        minTileHeight: 44,
        minVerticalPadding: 6,
        minLeadingWidth: 20,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: FastCircularProgressIndicator(width: 20, height: 20),
              )
            : Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.secondaryColor
                    : AppColors.textPrimary,
                size: 20,
              ),
        title: AppTextView.body2(
          title,
          color: AppColors.textPrimary,
          maxLines: 2,
          fontWeight: FontWeight.w500,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class AppSelectionError extends StatelessWidget {
  const AppSelectionError({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: AppTextView.body3(message!, color: AppColors.red1),
    );
  }
}
