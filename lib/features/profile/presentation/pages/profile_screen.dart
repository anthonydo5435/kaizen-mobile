import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/profile/presentation/providers/profile_controller.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_full_screen.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';

//
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileController>(
      create: (_) => ProfileController()..initialize(),
      child: const _ProfileScreenView(),
    );
  }
}

class _ProfileScreenView extends StatelessWidget {
  const _ProfileScreenView();

  @override
  Widget build(BuildContext context) {
    return AppFullScreen(
      backgroundColor: AppColors.mainBg,
      useSafeArea: false,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Consumer<ProfileController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return FastCircularProgressIndicator();
            }

            final user = controller.user;
            if (user == null) {
              return const _ProfileUnavailableState();
            }

            return _ProfileContent(controller: controller, user: user);
          },
        ),
      ),
    );
  }
}

class _ProfileUnavailableState extends StatelessWidget {
  const _ProfileUnavailableState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: AppTextView.body(
          'Profile data is not available right now.',
          color: AppColors.textPrimary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.controller, required this.user});

  final ProfileController controller;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: const _ProfileHeaderBar(),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            children: [
              _ProfileHeroCard(
                controller: controller,
                user: user,
                onEditImage: () => _handleProfileImageUpdate(context),
              ),
              const SizedBox(height: 18),
              _ProfileInfoSection(
                controller: controller,
                user: user,
                onEditDateOfBirth: () => _pickDateOfBirth(context, controller),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleProfileImageUpdate(BuildContext context) async {
    try {
      await context.read<ProfileController>().pickAndUpdateProfileImage();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to upload profile image right now.'),
        ),
      );
    }
  }

  Future<void> _pickDateOfBirth(
    BuildContext context,
    ProfileController controller,
  ) async {
    final initialDate =
        _ProfileViewData.tryParseDate(controller.user?.dateOfBirth) ??
        DateTime(1995, 6, 8);
    final now = DateTime.now();
    final pickedDate = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _DateOfBirthDialogContent(
        initialDate: initialDate.isAfter(now) ? now : initialDate,
        minDate: DateTime(1900),
        maxDate: now,
      ),
    );

    if (pickedDate == null || !context.mounted) {
      return;
    }

    try {
      await controller.updateDateOfBirth(
        _ProfileViewData.formatApiDate(pickedDate),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update date of birth right now.'),
        ),
      );
    }
  }
}

class _ProfileHeaderBar extends StatelessWidget {
  const _ProfileHeaderBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _ProfileHeaderAction(
            onTap: () => Navigator.of(context).pop(),
            child: SvgPicture.asset(
              '${AppStrings.imagePath}back.svg',
              width: 22,
              height: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: AppTextView.body1(
              AppStrings.profile,
              color: AppColors.secondaryColor,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

class _ProfileHeaderAction extends StatelessWidget {
  const _ProfileHeaderAction({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.controller,
    required this.user,
    required this.onEditImage,
  });

  final ProfileController controller;
  final User user;
  final VoidCallback onEditImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              _ProfileAvatar(imagePath: user.image, imageUrl: user.imageUrl),
              Positioned(
                right: 0,
                bottom: 0,
                child: _ProfileImageEditButton(
                  isBusy: controller.isProcessingImageUpdate,
                  onTap: onEditImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_ProfileViewData.resolveStatus(user)
              case final String status) ...[
            AppTextView.body2(
              status,
              color: AppColors.green1,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          AppTextView.body1(
            CustomFunctions.resolveName(user),
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          AppTextView.body2(
            _ProfileViewData.fallback(user.email),
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileImageEditButton extends StatelessWidget {
  const _ProfileImageEditButton({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondaryColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isBusy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
        ),
      ),
    );
  }
}

class _ProfileInfoSection extends StatelessWidget {
  const _ProfileInfoSection({
    required this.controller,
    required this.user,
    required this.onEditDateOfBirth,
  });

  final ProfileController controller;
  final User user;
  final VoidCallback onEditDateOfBirth;

  @override
  Widget build(BuildContext context) {
    final personality = _ProfileViewData.resolvePersonality(user);

    return Column(
      children: [
        _InfoCard(
          title: 'Email',
          value: _ProfileViewData.fallback(user.email),
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Contact',
          value: _ProfileViewData.fallback(user.contactNo),
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Gender',
          value: _ProfileViewData.resolveGender(user),
          icon: Icons.wc_outlined,
        ),
        const SizedBox(height: 14),
        if (personality != null) ...[
          _InfoCard(
            title: 'Personality',
            value: personality,
            icon: Icons.psychology_outlined,
          ),
          const SizedBox(height: 14),
        ],
        _InfoCard(
          title: 'Date Of Birth',
          value: _ProfileViewData.resolveDateOfBirth(user),
          icon: Icons.cake_outlined,
          trailing: controller.isUpdatingDateOfBirth
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondaryColor,
                    ),
                  ),
                )
              : const Icon(
                  Icons.edit_calendar_outlined,
                  color: AppColors.secondaryColor,
                  size: 20,
                ),
          onTap: controller.isUpdatingDateOfBirth ? null : onEditDateOfBirth,
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Address',
          value: _ProfileViewData.resolveAddress(user),
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }
}

class _DateOfBirthDialogContent extends StatelessWidget {
  const _DateOfBirthDialogContent({
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_ProfileDatePickerController>(
      create: (_) => _ProfileDatePickerController(
        initialDate: initialDate,
        minDate: minDate,
        maxDate: maxDate,
      ),
      child: Consumer<_ProfileDatePickerController>(
        builder: (context, controller, _) {
          return Dialog(
            backgroundColor: AppColors.surfaceDark,
            shape: AppDialogStyle.shape(radius: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppTextView.body1(
                    'Choose Date Of Birth',
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 14),
                  _ProfileDateSelectionChip(
                    label: 'Date',
                    value: _ProfileViewData.formatDisplayDate(
                      controller.selectedDate,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProfileCalendar(
                    visibleMonth: controller.visibleMonth,
                    minDate: minDate,
                    maxDate: maxDate,
                    selectedDate: controller.selectedDate,
                    isSelectingYear: controller.isSelectingYear,
                    onMonthChanged: controller.updateVisibleMonth,
                    onHeaderTap: controller.toggleYearSelection,
                    onYearSelected: controller.selectYear,
                    onDateSelected: controller.selectDate,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.selectedDate),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileDatePickerController extends ChangeNotifier {
  _ProfileDatePickerController({
    required DateTime initialDate,
    required this.minDate,
    required this.maxDate,
  }) : selectedDate = _profileDateOnly(initialDate),
       visibleMonth = DateTime(initialDate.year, initialDate.month);

  final DateTime minDate;
  final DateTime maxDate;
  DateTime selectedDate;
  DateTime visibleMonth;
  bool isSelectingYear = false;

  void updateVisibleMonth(DateTime value) {
    visibleMonth = value;
    notifyListeners();
  }

  void toggleYearSelection() {
    isSelectingYear = !isSelectingYear;
    notifyListeners();
  }

  void selectYear(int year) {
    visibleMonth = DateTime(year, visibleMonth.month, 1);
    isSelectingYear = false;
    notifyListeners();
  }

  void selectDate(DateTime value) {
    selectedDate = value;
    visibleMonth = DateTime(value.year, value.month);
    notifyListeners();
  }
}

class _ProfileDateSelectionChip extends StatelessWidget {
  const _ProfileDateSelectionChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body4(
            label,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 4),
          AppTextView.body3(
            value,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

class _ProfileCalendar extends StatelessWidget {
  const _ProfileCalendar({
    required this.visibleMonth,
    required this.minDate,
    required this.maxDate,
    required this.selectedDate,
    required this.isSelectingYear,
    required this.onMonthChanged,
    required this.onHeaderTap,
    required this.onYearSelected,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime selectedDate;
  final bool isSelectingYear;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onHeaderTap;
  final ValueChanged<int> onYearSelected;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final resolvedMinDate = _profileDateOnly(minDate);
    final resolvedMaxDate = _profileDateOnly(maxDate);
    final startOffset = firstDayOfMonth.weekday % 7;
    final gridStart = firstDayOfMonth.subtract(Duration(days: startOffset));
    final days = List<DateTime>.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
      growable: false,
    );
    final previousMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month - 1,
      1,
    );
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 1);
    final canGoPrevious = !_isProfileMonthBefore(
      previousMonth,
      resolvedMinDate,
    );
    final canGoNext = !_isProfileMonthAfter(nextMonth, resolvedMaxDate);
    final years = List<int>.generate(
      resolvedMaxDate.year - resolvedMinDate.year + 1,
      (index) => resolvedMinDate.year + index,
      growable: false,
    ).reversed.toList(growable: false);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isSelectingYear
                  ? null
                  : canGoPrevious
                  ? () => onMonthChanged(previousMonth)
                  : null,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onHeaderTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppTextView.body2(
                        isSelectingYear
                            ? '${visibleMonth.year}'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMonthYear(visibleMonth),
                        color: AppColors.textPrimary,
                        textAlign: TextAlign.center,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isSelectingYear
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: isSelectingYear
                  ? null
                  : canGoNext
                  ? () => onMonthChanged(nextMonth)
                  : null,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isSelectingYear)
          SizedBox(
            height: 280,
            child: GridView.builder(
              itemCount: years.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                final year = years[index];
                return _ProfileYearCell(
                  year: year,
                  isSelected: year == selectedDate.year,
                  isVisibleYear: year == visibleMonth.year,
                  onTap: () => onYearSelected(year),
                );
              },
            ),
          )
        else ...[
          const Row(
            children: [
              _ProfileWeekdayLabel('S'),
              _ProfileWeekdayLabel('M'),
              _ProfileWeekdayLabel('T'),
              _ProfileWeekdayLabel('W'),
              _ProfileWeekdayLabel('T'),
              _ProfileWeekdayLabel('F'),
              _ProfileWeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final isEnabled =
                  !date.isBefore(resolvedMinDate) &&
                  !date.isAfter(resolvedMaxDate);
              return _ProfileCalendarDayCell(
                date: date,
                isCurrentMonth: date.month == visibleMonth.month,
                isEnabled: isEnabled,
                isSelected: _isSameProfileDate(date, selectedDate),
                onTap: isEnabled ? () => onDateSelected(date) : null,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ProfileYearCell extends StatelessWidget {
  const _ProfileYearCell({
    required this.year,
    required this.isSelected,
    required this.isVisibleYear,
    required this.onTap,
  });

  final int year;
  final bool isSelected;
  final bool isVisibleYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.secondaryColor
        : isVisibleYear
        ? AppColors.secondaryColor.withValues(alpha: 0.18)
        : AppColors.surfaceDark2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondaryColor
                  : isVisibleYear
                  ? AppColors.secondaryColor.withValues(alpha: 0.6)
                  : AppColors.fieldBorder.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: AppTextView.body3(
            '$year',
            color: AppColors.textPrimary,
            fontWeight: isSelected || isVisibleYear
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ProfileWeekdayLabel extends StatelessWidget {
  const _ProfileWeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AppTextView.body4(
          label,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileCalendarDayCell extends StatelessWidget {
  const _ProfileCalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !isEnabled
        ? AppColors.surfaceDark2.withValues(alpha: 0.45)
        : isSelected
        ? AppColors.secondaryColor
        : AppColors.surfaceDark2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !isEnabled
                  ? AppColors.fieldBorder.withValues(alpha: 0.08)
                  : isSelected
                  ? AppColors.secondaryColor
                  : AppColors.fieldBorder.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: AppTextView.body3(
            '${date.day}',
            color: !isEnabled
                ? AppColors.textSecondary.withValues(alpha: 0.45)
                : isCurrentMonth
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

bool _isProfileMonthBefore(DateTime month, DateTime minDate) {
  return month.year < minDate.year ||
      (month.year == minDate.year && month.month < minDate.month);
}

bool _isProfileMonthAfter(DateTime month, DateTime maxDate) {
  return month.year > maxDate.year ||
      (month.year == maxDate.year && month.month > maxDate.month);
}

DateTime _profileDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameProfileDate(DateTime date, DateTime other) {
  return date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImageProvider();

    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark3,
        border: Border.all(color: AppColors.secondaryColor, width: 2),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? const Icon(
              Icons.person_outline_rounded,
              color: AppColors.textPrimary,
              size: 48,
            )
          : null,
    );
  }

  ImageProvider<Object>? _resolveImageProvider() {
    final candidates = [imagePath, imageUrl];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      if (value.startsWith('http')) {
        return CachedNetworkImageProvider(value);
      }

      final file = File(value);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    return null;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.secondaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body3(
                      title,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 6),
                    AppTextView.body2(
                      value,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _ProfileViewData {
  static String resolveAddress(User user) {
    final address = user.profileAddress;
    if (address == null) {
      return 'Address not available';
    }

    final parts = [
      address.address,
      address.city,
      address.state,
      address.country,
      address.zipCode,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Address not available';
    }

    return parts.join(', ');
  }

  static String fallback(String? value) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty) {
      return 'Not available';
    }

    return resolved;
  }

  static String resolveGender(User user) {
    final rawValue = user.gender?.trim().toLowerCase();
    if (rawValue == null || rawValue.isEmpty) {
      return 'Not available';
    }

    return '${rawValue[0].toUpperCase()}${rawValue.substring(1)}';
  }

  static String? resolvePersonality(User user) {
    final rawValue = user.personalityType?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final separatorIndex = rawValue.indexOf('_');
    final resolved = separatorIndex >= 0 && separatorIndex < rawValue.length - 1
        ? rawValue.substring(separatorIndex + 1).trim()
        : rawValue;

    if (resolved.isEmpty) {
      return null;
    }

    return resolved;
  }

  static String resolveDateOfBirth(User user) {
    final rawValue = user.dateOfBirth?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return 'Not available';
    }

    final parsedDate = tryParseDate(rawValue);
    if (parsedDate == null) {
      return rawValue;
    }

    return formatDisplayDate(parsedDate);
  }

  static String? resolveStatus(User user) {
    final rawValue = user.status?.trim().toLowerCase();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return '${rawValue[0].toUpperCase()}${rawValue.substring(1)}';
  }

  static DateTime? tryParseDate(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    final parsedDate = DateTime.tryParse(trimmedValue);
    if (parsedDate != null) {
      return parsedDate;
    }

    final numericValue = int.tryParse(trimmedValue);
    if (numericValue == null) {
      return null;
    }

    final timestamp = trimmedValue.length <= 10
        ? numericValue * 1000
        : numericValue;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static String formatApiDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String formatDisplayDate(DateTime value) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthName = monthNames[value.month - 1];
    return '$monthName ${value.day}, ${value.year}';
  }
}
