import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/seat_profile_detail.dart';

//
typedef SeatProfileDescriptionSaveCallback =
    Future<void> Function(SeatProfileDescriptionFormData formData);

class SeatProfileDescriptionFormData {
  const SeatProfileDescriptionFormData({
    required this.descriptionName,
    required this.auditSpecifics,
    required this.auditFactorType,
    required this.milestoneDays,
  });

  final String descriptionName;
  final String auditSpecifics;
  final String auditFactorType;
  final String milestoneDays;
}

class SeatProfileDescriptionCheckInTypeOption {
  const SeatProfileDescriptionCheckInTypeOption({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;
}

const List<SeatProfileDescriptionCheckInTypeOption>
seatProfileDescriptionCheckInTypeOptions =
    <SeatProfileDescriptionCheckInTypeOption>[
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'observation',
        label: AppStrings.seatProfileCheckInObservation,
      ),
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'examination',
        label: AppStrings.seatProfileCheckInExamination,
      ),
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'administrative',
        label: AppStrings.seatProfileCheckInAdministrative,
      ),
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'interview',
        label: AppStrings.seatProfileCheckInInterview,
      ),
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'survey',
        label: AppStrings.seatProfileCheckInSurvey,
      ),
      SeatProfileDescriptionCheckInTypeOption(
        apiValue: 'no_check_in',
        label: AppStrings.noCheckIn,
      ),
    ];

const List<String> _seatProfileDescriptionMilestoneOptions = <String>[
  '30',
  '60',
  '90',
  '',
];

Future<bool> showSeatProfileDescriptionBottomSheet(
  BuildContext context, {
  required SeatProfileDescription description,
  SeatProfileDescriptionSaveCallback? onSave,
  String? title,
  String? descriptionText,
  String? submitLabel,
}) async {
  final didSave = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _SeatProfileDescriptionBottomSheet(
      description: description,
      onSave: onSave,
      title: title,
      descriptionText: descriptionText,
      submitLabel: submitLabel,
    ),
  );

  return didSave == true;
}

String seatProfileDescriptionMilestoneLabel(String value) {
  final normalized = _normalizeSeatProfileMilestoneValue(value);
  if (normalized.isNotEmpty) {
    return normalized;
  }

  return AppStrings.seatProfileNoneOption;
}

String seatProfileDescriptionCheckInTypeLabel(String value) {
  final normalized = _normalizeSeatProfileCheckInType(value);
  if (normalized == null) {
    final fallbackLabel = _humanizeSeatProfileCheckInType(value);
    if (fallbackLabel.isNotEmpty) {
      return fallbackLabel;
    }

    return AppStrings.seatProfileNoneOption;
  }

  final option = seatProfileDescriptionCheckInTypeOptions.firstWhere(
    (item) => item.apiValue == normalized,
  );
  return option.label;
}

class _SeatProfileDescriptionBottomSheet extends StatefulWidget {
  const _SeatProfileDescriptionBottomSheet({
    required this.description,
    this.onSave,
    this.title,
    this.descriptionText,
    this.submitLabel,
  });

  final SeatProfileDescription description;
  final SeatProfileDescriptionSaveCallback? onSave;
  final String? title;
  final String? descriptionText;
  final String? submitLabel;

  @override
  State<_SeatProfileDescriptionBottomSheet> createState() =>
      _SeatProfileDescriptionBottomSheetState();
}

class _SeatProfileDescriptionBottomSheetState
    extends State<_SeatProfileDescriptionBottomSheet> {
  late final _SeatProfileDescriptionSheetController _controller;

  bool get _isEditable => widget.onSave != null;

  @override
  void initState() {
    super.initState();
    _controller = _SeatProfileDescriptionSheetController(widget.description);
  }

  Future<void> _submit() async {
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop();
      return;
    }

    FocusScope.of(context).unfocus();

    final didSave = await _controller.submit(onSave);
    if (!mounted || !didSave) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return PopScope<Object?>(
          canPop: !_controller.isSaving,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: FractionallySizedBox(
              heightFactor: 0.92,
              child: AppKeyboardBottomSheetSurface(
                color: AppColors.surfaceDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.fieldBorder.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextView.body1(
                              widget.title ??
                                  AppStrings
                                      .seatProfileEditDescriptionDialogTitle,
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _SeatDescriptionSheetCloseButton(
                            onTap: _controller.isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: AppDotDivider(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: AppTextView.body(
                                widget.descriptionText ??
                                    AppStrings
                                        .seatProfileEditDescriptionDialogDescription,
                                color: AppColors.lightPurple1,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const AppTextView.body2(
                              AppStrings.seatProfileSeatDescriptionNameLabel,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _SeatDescriptionTextField(
                              controller: _controller.nameController,
                              enabled: _isEditable && !_controller.isSaving,
                              hintText:
                                  AppStrings.seatProfileSeatDescriptionNameHint,
                              minLines: 1,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            const AppTextView.body3(
                              AppStrings
                                  .seatProfileSeatDescriptionValidationNote,
                              color: AppColors.grey1,
                              height: 1.4,
                            ),
                            const SizedBox(height: 20),
                            const AppTextView.body2(
                              AppStrings.seatProfileAuditSpecifics,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 10),
                            _SeatDescriptionTextField(
                              controller: _controller.auditSpecificsController,
                              enabled: _isEditable && !_controller.isSaving,
                              hintText:
                                  AppStrings.seatProfileAuditSpecificsHint,
                              minLines: 5,
                              maxLines: 7,
                            ),
                            const SizedBox(height: 20),
                            _SeatDescriptionDropdownField(
                              label: AppStrings.seatProfileMilestoneDays,
                              value: _controller.selectedMilestoneDay,
                              enabled: _isEditable && !_controller.isSaving,
                              items: _seatProfileDescriptionMilestoneOptions
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: AppTextView.body3(
                                        value.isEmpty
                                            ? AppStrings.seatProfileNoneOption
                                            : value,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _controller.selectMilestoneDay,
                            ),
                            const SizedBox(height: 20),
                            const AppTextView.body2(
                              AppStrings.seatProfileCheckInType,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: seatProfileDescriptionCheckInTypeOptions
                                  .map(
                                    (option) => _CheckInTypeChip(
                                      label: option.label,
                                      isSelected:
                                          _controller.selectedCheckInType ==
                                          option.apiValue,
                                      isEnabled:
                                          _isEditable && !_controller.isSaving,
                                      onTap: () => _controller
                                          .selectCheckInType(option.apiValue),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                            if (_controller.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _SeatDescriptionErrorCard(
                                message: _controller.errorMessage!,
                              ),
                            ],
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                child: AppButton(
                                  text: _isEditable
                                      ? (widget.submitLabel ??
                                            AppStrings.seatProfileUpdateAction)
                                      : AppStrings.done,
                                  onPressed: _isEditable
                                      ? (_controller.canSave ? _submit : null)
                                      : () => Navigator.of(context).pop(),
                                  isLoading:
                                      _isEditable && _controller.isSaving,
                                  borderRadius: 14,
                                  minimumHeight: 48,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeatProfileDescriptionSheetController extends ChangeNotifier {
  _SeatProfileDescriptionSheetController(SeatProfileDescription description)
    : nameController = TextEditingController(text: description.name),
      auditSpecificsController = TextEditingController(
        text: description.auditSpecifics,
      ),
      _selectedMilestoneDay = _normalizeSeatProfileMilestoneValue(
        description.milestoneDays,
      ),
      _selectedCheckInType = _initialSeatProfileCheckInType(
        description.auditFactorType,
      ) {
    nameController.addListener(_handleFieldChanged);
    auditSpecificsController.addListener(_handleFieldChanged);
  }

  final TextEditingController nameController;
  final TextEditingController auditSpecificsController;

  bool _isSaving = false;
  String _selectedMilestoneDay;
  String _selectedCheckInType;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String get selectedMilestoneDay => _selectedMilestoneDay;
  String get selectedCheckInType => _selectedCheckInType;
  String? get errorMessage => _errorMessage;
  bool get canSave => !_isSaving && nameController.text.trim().isNotEmpty;

  void selectMilestoneDay(String? value) {
    final resolvedValue = value?.trim() ?? '';
    if (_selectedMilestoneDay == resolvedValue) {
      return;
    }

    _selectedMilestoneDay = resolvedValue;
    _errorMessage = null;
    notifyListeners();
  }

  void selectCheckInType(String value) {
    final resolvedValue = value.trim();
    if (resolvedValue.isEmpty || _selectedCheckInType == resolvedValue) {
      return;
    }

    _selectedCheckInType = resolvedValue;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> submit(SeatProfileDescriptionSaveCallback onSave) async {
    final validationMessage = _validate();
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await onSave(
        SeatProfileDescriptionFormData(
          descriptionName: nameController.text.trim(),
          auditSpecifics: auditSpecificsController.text.trim(),
          auditFactorType: _selectedCheckInType,
          milestoneDays: _selectedMilestoneDay,
        ),
      );
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String? _validate() {
    final value = nameController.text.trim();
    if (value.isEmpty) {
      return AppStrings.seatProfileSeatDescriptionNameRequired;
    }

    if (_countWords(value) > 7) {
      return AppStrings.seatProfileSeatDescriptionNameWordLimit;
    }

    return null;
  }

  void _handleFieldChanged() {
    if (_errorMessage == null) {
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    nameController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    auditSpecificsController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    super.dispose();
  }
}

class _SeatDescriptionTextField extends StatelessWidget {
  const _SeatDescriptionTextField({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.28),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        cursorColor: AppColors.textPrimary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _SeatDescriptionDropdownField extends StatelessWidget {
  const _SeatDescriptionDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body2(
            label,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.fieldBorder.withValues(alpha: 0.7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark3,
                borderRadius: BorderRadius.circular(12),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  size: 24,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: items,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInTypeChip extends StatelessWidget {
  const _CheckInTypeChip({
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.purple1
        : AppColors.fieldBorder.withValues(alpha: 0.32);
    final backgroundColor = isSelected ? AppColors.purple1 : AppColors.mainBg;
    final textColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return Opacity(
      opacity: isEnabled ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: AppTextView.body3(
              label,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatDescriptionErrorCard extends StatelessWidget {
  const _SeatDescriptionErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red1.withValues(alpha: 0.28)),
      ),
      child: AppTextView.body2(
        message,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }
}

class _SeatDescriptionSheetCloseButton extends StatelessWidget {
  const _SeatDescriptionSheetCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}

String _normalizeSeatProfileMilestoneValue(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits == '30' || digits == '60' || digits == '90') {
    return digits;
  }

  return '';
}

String _initialSeatProfileCheckInType(String value) {
  return _normalizeSeatProfileCheckInType(value) ??
      seatProfileDescriptionCheckInTypeOptions.first.apiValue;
}

String? _normalizeSeatProfileCheckInType(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  switch (normalized) {
    case 'observation':
      return 'observation';
    case 'examination':
      return 'examination';
    case 'administrative':
    case 'administration':
      return 'administrative';
    case 'interview':
    case 'interviews':
      return 'interview';
    case 'survey':
    case 'surveys':
      return 'survey';
    case 'no check in':
    case 'no checkin':
    case 'none':
      return 'no_check_in';
    default:
      return null;
  }
}

String _humanizeSeatProfileCheckInType(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final normalized = trimmed
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized
      .split(' ')
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

int _countWords(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
}
