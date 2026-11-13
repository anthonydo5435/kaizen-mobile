import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../core/widgets/app_text_view.dart';

class CheckInTeamMemberFilterOption {
  const CheckInTeamMemberFilterOption({
    required this.selectionId,
    required this.name,
    required this.email,
    this.imageUrl,
    this.profileUuid,
    required this.onboarded,
  });

  final String selectionId;
  final String name;
  final String email;
  final String? imageUrl;
  final String? profileUuid;
  final bool onboarded;
}

class CheckInTeamMemberFilterSheet extends StatefulWidget {
  const CheckInTeamMemberFilterSheet({
    super.key,
    required this.options,
    this.initialSelectionId,
  });

  final List<CheckInTeamMemberFilterOption> options;
  final String? initialSelectionId;

  @override
  State<CheckInTeamMemberFilterSheet> createState() =>
      _CheckInTeamMemberFilterSheetState();
}

class _CheckInTeamMemberFilterSheetState
    extends State<CheckInTeamMemberFilterSheet> {
  String? _selectedSelectionId;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _selectedSelectionId = widget.initialSelectionId;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.options
        .where((option) {
          if (_searchQuery.trim().isEmpty) {
            return true;
          }

          final normalizedQuery = _searchQuery.trim().toLowerCase();
          return option.name.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return SafeArea(
      top: false,
      bottom: false,
      child: AppKeyboardBottomSheetSurface(
        height: MediaQuery.of(context).size.height * 0.7,
        color: AppColors.mainBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              _SelectionHeader(
                title: AppStrings.selectTeamMember,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 22),
              const AppDotDivider(),
              const SizedBox(height: 24),
              _TeamMemberSearchBar(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: filteredOptions
                        .map(
                          (option) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _SelectionOptionTile(
                              title: option.name,
                              isSelected:
                                  _selectedSelectionId == option.selectionId,
                              onTap: () {
                                setState(() {
                                  _selectedSelectionId = option.selectionId;
                                });
                              },
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const AppDotDivider(),
              const SizedBox(height: 22),
              AppButton(
                text: AppStrings.done,
                onPressed: _selectedSelectionId == null ? null : _handleDoneTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  CheckInTeamMemberFilterOption? get _selectedOption {
    final selectedSelectionId = _selectedSelectionId;
    if (selectedSelectionId == null) {
      return null;
    }

    for (final option in widget.options) {
      if (option.selectionId == selectedSelectionId) {
        return option;
      }
    }

    return null;
  }

  void _handleDoneTap() {
    final selectedOption = _selectedOption;
    if (_isClosing || selectedOption == null) {
      return;
    }

    _isClosing = true;
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).maybePop(selectedOption);
    });
  }
}

class _TeamMemberSearchBar extends StatelessWidget {
  const _TeamMemberSearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.75),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorHeight: 16,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        cursorColor: AppColors.textPrimary,
        decoration: const InputDecoration(
          hintText: AppStrings.selectTeamMember,
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: SvgPicture.asset(
            '${AppStrings.imagePath}back.svg',
            width: 24,
            height: 24,
          ),
        ),
        Expanded(
          child: AppTextView.title(
            title,
            color: AppColors.secondaryColor,
            fontSize: 20,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}

class _SelectionOptionTile extends StatelessWidget {
  const _SelectionOptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.secondaryColor
                    : AppColors.hexd9d4f0,
                border: Border.all(
                  color: isSelected ? AppColors.hex7747e6 : AppColors.hexd9d4f0,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: AppTextView.body(
                title,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
