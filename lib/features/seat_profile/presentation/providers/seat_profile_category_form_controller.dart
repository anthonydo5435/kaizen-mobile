import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/seat_profile_category_draft.dart';

enum SeatProfileCategorySaveResult { notSaved, confirmationRequired, saved }

/// Shared draft and save behavior for the create dialog and category sheet.
class SeatProfileCategoryFormController extends ChangeNotifier {
  SeatProfileCategoryFormController({
    required Future<void> Function(List<SeatProfileCategoryDraft>)
    onSaveCategories,
    Future<List<SeatProfileCategoryDraft>> Function()? loadCategories,
  }) : _onSaveCategories = onSaveCategories,
       _loadCategories = loadCategories,
       _isLoading = loadCategories != null;

  static const maxCategoryTitleLength = 25;
  static const maxCategoryTitleWords = 3;
  static const _importanceTolerance = 0.001;

  final Future<void> Function(List<SeatProfileCategoryDraft>) _onSaveCategories;
  final Future<List<SeatProfileCategoryDraft>> Function()? _loadCategories;
  final List<SeatProfileCategoryRowController> _rows = [];
  bool _isLoading;
  bool _isSaving = false;
  bool _isDisposed = false;
  String? _message;
  String? _errorMessage;

  List<SeatProfileCategoryRowController> get rows => List.unmodifiable(_rows);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get message => _message;
  double get totalImportance => _rows.fold<double>(
    0,
    (total, row) => total + _parseWeightPercent(row.weightController.text),
  );
  double get remainingImportance => 100 - totalImportance;
  bool get hasReachedImportance =>
      remainingImportance.abs() < _importanceTolerance;
  bool get hasExceededImportance => remainingImportance < -_importanceTolerance;
  bool get requiresTotalConfirmation =>
      remainingImportance > _importanceTolerance;
  String get remainingImportanceLabel =>
      '${formatPercent(remainingImportance)}%';
  String get totalImportanceLabel =>
      '${AppStrings.seatProfileCategoriesTotalLabel}: ${formatPercent(totalImportance)}%';
  String get importanceStatusValueLabel => '${formatPercent(totalImportance)}%';
  String get importanceStatusLabel {
    if (hasReachedImportance) {
      return AppStrings.seatProfileCategoryImportanceReached;
    }
    if (hasExceededImportance) {
      return AppStrings.seatProfileCategoryImportanceExceeded;
    }
    return AppStrings.seatProfileCategoryImportanceRemaining;
  }

  Color get importanceStatusColor =>
      hasReachedImportance ? AppColors.secondaryColor : AppColors.red1;

  Future<void> initialize() async {
    final load = _loadCategories;
    if (load == null || _isDisposed) return;
    try {
      final categories = await load();
      if (!_isDisposed) initializeWith(categories);
    } catch (error) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  void initializeWith(List<SeatProfileCategoryDraft> categories) {
    if (_isDisposed) return;
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(
        categories.map(
          (category) => SeatProfileCategoryRowController(
            uuid: category.uuid,
            title: category.title,
            weightPercent: formatPercent(category.weightPercent),
            onChanged: _handleRowChanged,
          ),
        ),
      );
    _isLoading = false;
    _message = null;
    notifyListeners();
  }

  void addRow() {
    if (_isDisposed || _isSaving) return;
    _rows.add(SeatProfileCategoryRowController(onChanged: _handleRowChanged));
    _message = null;
    notifyListeners();
  }

  void removeRowAt(int index) {
    if (_isDisposed || _isSaving || index < 0 || index >= _rows.length) return;
    _rows.removeAt(index).dispose();
    _message = null;
    notifyListeners();
  }

  String? validateEntries() {
    for (final row in _rows) {
      final title = row.nameController.text.trim();
      if (title.isEmpty) return AppStrings.seatProfileCategoryNameRequired;
      if (title.length > maxCategoryTitleLength) {
        return AppStrings.seatProfileCategoryNameCharacterLimit;
      }
      if (_countWords(title) > maxCategoryTitleWords) {
        return AppStrings.seatProfileCategoryNameWordLimit;
      }
      final weightText = row.weightController.text.trim();
      if (weightText.isEmpty) {
        return AppStrings.seatProfileCategoryImportanceRequired;
      }
      final weight = double.tryParse(weightText);
      if (weight == null || weight <= 0) {
        return AppStrings.seatProfileCategoryImportanceInvalid;
      }
    }
    if (totalImportance > 100 + _importanceTolerance) {
      return AppStrings.seatProfileCategoryImportanceTotalExceeded;
    }
    return null;
  }

  List<SeatProfileCategoryDraft> buildDrafts() => _rows
      .map(
        (row) => SeatProfileCategoryDraft(
          uuid: row.uuid,
          title: row.nameController.text.trim(),
          weightPercent: _parseWeightPercent(row.weightController.text),
        ),
      )
      .toList(growable: false);

  Future<SeatProfileCategorySaveResult> submit({
    bool confirmIncompleteTotal = false,
  }) async {
    if (_isDisposed || _isLoading || _isSaving) {
      return SeatProfileCategorySaveResult.notSaved;
    }
    _message = validateEntries();
    if (_message != null) {
      notifyListeners();
      return SeatProfileCategorySaveResult.notSaved;
    }
    if (requiresTotalConfirmation && !confirmIncompleteTotal) {
      return SeatProfileCategorySaveResult.confirmationRequired;
    }
    _isSaving = true;
    notifyListeners();
    try {
      await _onSaveCategories(buildDrafts());
      return SeatProfileCategorySaveResult.saved;
    } catch (error) {
      if (!_isDisposed) _errorMessage = error.toString();
      return SeatProfileCategorySaveResult.notSaved;
    } finally {
      _isSaving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  String? takeErrorMessage() {
    final error = _errorMessage;
    _errorMessage = null;
    return error;
  }

  void _handleRowChanged() {
    _message = null;
    notifyListeners();
  }

  static double _parseWeightPercent(String value) =>
      double.tryParse(value.trim()) ?? 0;

  static String formatPercent(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static int _countWords(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;

  @override
  void dispose() {
    _isDisposed = true;
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }
}

class SeatProfileCategoryRowController {
  SeatProfileCategoryRowController({
    this.uuid,
    String title = '',
    String weightPercent = '',
    required VoidCallback onChanged,
  }) : _onChanged = onChanged {
    nameController = TextEditingController(text: title)
      ..addListener(_handleChanged);
    weightController = TextEditingController(text: weightPercent)
      ..addListener(_handleChanged);
  }

  final String? uuid;
  late final TextEditingController nameController;
  late final TextEditingController weightController;
  final VoidCallback _onChanged;

  void _handleChanged() => _onChanged();

  void dispose() {
    nameController
      ..removeListener(_handleChanged)
      ..dispose();
    weightController
      ..removeListener(_handleChanged)
      ..dispose();
  }
}
