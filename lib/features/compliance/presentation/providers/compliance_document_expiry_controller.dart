import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';

enum _ExpirySegment { month, day, year }

typedef _ExpiryParts = ({int? month, String day, String year});
typedef _ExpiryEdit = ({int start, int end, String inserted});

class ComplianceDocumentExpiryController extends ChangeNotifier {
  ComplianceDocumentExpiryController({
    DateTime Function()? currentDate,
    String? initialExpiryDate,
  }) : _currentDate = currentDate ?? DateTime.now {
    final value = initialExpiryDate?.trim() ?? '';
    final date = _parseInitialDate(value);
    if (date != null) {
      textController.value = _maskedValue((
        month: date.month,
        day: date.day.toString().padLeft(2, '0'),
        year: date.year.toString().padLeft(4, '0'),
      ));
      if (date.isBefore(today)) {
        _errorText = AppStrings.expiryDateInPast;
      }
    }
    textController.addListener(_onTextChanged);
    focusNode.addListener(_onFocusChanged);
  }

  final DateTime Function() _currentDate;
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  String? _errorText;
  String? _pendingMonthDigit;

  DateTime get today => DateUtils.dateOnly(_currentDate());
  DateTime? get selectedDate => _parseDate(textController.text);
  String? get errorText => _errorText;

  String? get apiExpiryDate {
    final date = selectedDate;
    if (date == null || date.isBefore(today)) {
      return null;
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void selectDate(DateTime date) {
    final dateOnly = DateUtils.dateOnly(date);
    if (dateOnly.isBefore(today)) {
      return;
    }
    _pendingMonthDigit = null;
    textController.value = _maskedValue((
      month: dateOnly.month,
      day: dateOnly.day.toString().padLeft(2, '0'),
      year: dateOnly.year.toString().padLeft(4, '0'),
    ));
  }

  bool validate() {
    final date = selectedDate;
    _errorText =
        textController.text.trim().isEmpty ||
            textController.text == AppStrings.enterExpiryDate
        ? AppStrings.expiryDateRequired
        : date == null
        ? AppStrings.expiryDateInvalid
        : date.isBefore(today)
        ? AppStrings.expiryDateInPast
        : null;
    notifyListeners();
    return _errorText == null;
  }

  /// A tap commits a one-digit month and selects the tapped date segment.
  void selectSegmentAtCursor() {
    _pendingMonthDigit = null;
    final parts = _maskedParts(textController.text);
    if (parts == null) {
      return;
    }
    final segment = parts.month == null
        ? _ExpirySegment.month
        : _segmentAt(textController.text, textController.selection.start);
    textController.value = _maskedValue(
      parts,
      segment: segment,
      selectWhole: true,
    );
  }

  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }
    final parts = _maskedParts(oldValue.text);
    final edit = _replacement(oldValue, newValue);
    if (parts == null ||
        (edit.start == 0 && edit.end == oldValue.text.length)) {
      return _formatWholeInput(oldValue, newValue);
    }
    final segment = _segmentAt(oldValue.text, edit.start);
    if (edit.inserted.isEmpty) {
      _pendingMonthDigit = null;
      return _deleteSegment(parts, segment, edit, oldValue.text);
    }
    if (RegExp(r'^[\s,./-]+$').hasMatch(edit.inserted)) {
      final wasEnteringMonth = _pendingMonthDigit != null;
      _pendingMonthDigit = null;
      if (wasEnteringMonth || segment == _ExpirySegment.month) {
        return _maskedValue(
          parts,
          segment: _ExpirySegment.day,
          selectWhole: true,
        );
      }
      if (segment == _ExpirySegment.day &&
          parts.day.isNotEmpty &&
          int.parse(parts.day) > 0) {
        return _maskedValue(
          (
            month: parts.month,
            day: parts.day.padLeft(2, '0'),
            year: parts.year,
          ),
          segment: _ExpirySegment.year,
          selectWhole: true,
        );
      }
      return oldValue;
    }
    if (!RegExp(r'^\d+$').hasMatch(edit.inserted)) {
      final month = _monthNumber(edit.inserted);
      if (segment == _ExpirySegment.month && month != null) {
        _pendingMonthDigit = null;
        return _maskedValue(
          (month: month, day: parts.day, year: parts.year),
          segment: _ExpirySegment.day,
          selectWhole: true,
        );
      }
      return oldValue;
    }
    // DD is highlighted during a one-digit month preview. The next digit
    // completes that month; subsequent digits fill DD without a separator.
    if (_pendingMonthDigit != null &&
        edit.inserted.length == 1 &&
        segment != _ExpirySegment.year) {
      final combined = int.parse('$_pendingMonthDigit${edit.inserted}');
      final latestDigit = int.parse(edit.inserted);
      _pendingMonthDigit = null;
      final month = combined >= 1 && combined <= 12 ? combined : latestDigit;
      if (month > 0) {
        return _maskedValue(
          (month: month, day: parts.day, year: parts.year),
          segment: _ExpirySegment.day,
          selectWhole: true,
        );
      }
      if (parts.month == null) {
        _pendingMonthDigit = '0';
        return oldValue;
      }
      return _editDigits(parts, _ExpirySegment.day, edit, oldValue);
    }
    _pendingMonthDigit = null;
    if (segment == _ExpirySegment.month) {
      if (edit.inserted.length > 2) {
        return oldValue;
      }
      final numeric = int.parse(edit.inserted);
      final month = numeric >= 1 && numeric <= 12
          ? numeric
          : int.parse(edit.inserted.substring(edit.inserted.length - 1));
      if (month == 0 && edit.inserted.length == 2) {
        return oldValue;
      }
      _pendingMonthDigit = edit.inserted.length == 1 ? edit.inserted : null;
      return _maskedValue(
        (month: month == 0 ? null : month, day: parts.day, year: parts.year),
        segment: month == 0 ? _ExpirySegment.month : _ExpirySegment.day,
        selectWhole: true,
      );
    }
    return _editDigits(parts, segment, edit, oldValue);
  }

  TextEditingValue _editDigits(
    _ExpiryParts parts,
    _ExpirySegment segment,
    _ExpiryEdit edit,
    TextEditingValue oldValue,
  ) {
    final start =
        oldValue.text.indexOf(' ') + (segment == _ExpirySegment.day ? 1 : 5);
    final existing = segment == _ExpirySegment.day ? parts.day : parts.year;
    final prefix = (edit.start - start).clamp(0, existing.length);
    final suffix = (edit.end - start).clamp(0, existing.length);
    final digits =
        existing.substring(0, prefix) +
        edit.inserted +
        existing.substring(suffix);
    if (segment == _ExpirySegment.day) {
      if (digits.length > 2 || int.parse(digits) > 31) {
        return oldValue;
      }
      final complete = digits.length == 2 || int.parse(digits) > 3;
      return _maskedValue(
        (
          month: parts.month,
          day: complete ? digits.padLeft(2, '0') : digits,
          year: parts.year,
        ),
        segment: complete ? _ExpirySegment.year : _ExpirySegment.day,
        selectWhole: complete,
      );
    }
    if (digits.length > 4) {
      return oldValue;
    }
    return _maskedValue((
      month: parts.month,
      day: parts.day,
      year: digits,
    ), segment: digits.length == 4 ? null : _ExpirySegment.year);
  }

  TextEditingValue _deleteSegment(
    _ExpiryParts parts,
    _ExpirySegment segment,
    _ExpiryEdit edit,
    String text,
  ) {
    if (segment == _ExpirySegment.month) {
      return _maskedValue(
        (month: null, day: parts.day, year: parts.year),
        segment: _ExpirySegment.month,
        selectWhole: true,
      );
    }
    final digits = segment == _ExpirySegment.day ? parts.day : parts.year;
    if (digits.isEmpty) {
      return _maskedValue(
        parts,
        segment: segment == _ExpirySegment.day
            ? _ExpirySegment.month
            : _ExpirySegment.day,
        selectWhole: true,
      );
    }
    final start = text.indexOf(' ') + (segment == _ExpirySegment.day ? 1 : 5);
    final prefix = (edit.start - start).clamp(0, digits.length);
    final suffix = (edit.end - start).clamp(0, digits.length);
    var remaining = digits.substring(0, prefix) + digits.substring(suffix);
    if (remaining == digits) {
      remaining = digits.substring(0, digits.length - 1);
    }
    return _maskedValue((
      month: parts.month,
      day: segment == _ExpirySegment.day ? remaining : parts.day,
      year: segment == _ExpirySegment.year ? remaining : parts.year,
    ), segment: segment);
  }

  TextEditingValue _formatWholeInput(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    _pendingMonthDigit = null;
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final parts = _readParts(newValue.text);
    if (parts == null) {
      return newValue;
    }
    final day = parts.day ?? '';
    final year = parts.year ?? '';
    if (day.length > 2 || (day.isNotEmpty && int.parse(day) > 31)) {
      return oldValue;
    }
    var month = _monthNumber(parts.month);
    if (day.isEmpty &&
        year.isEmpty &&
        RegExp(r'^\d{1,2}$').hasMatch(parts.month)) {
      _pendingMonthDigit = parts.month.length == 1 ? parts.month : null;
      month ??= int.parse(parts.month.substring(parts.month.length - 1));
      return _maskedValue(
        (month: month == 0 ? null : month, day: '', year: ''),
        segment: month == 0 ? _ExpirySegment.month : _ExpirySegment.day,
        selectWhole: true,
      );
    }
    if (month == null) {
      return newValue;
    }
    final completeDay =
        day.length == 2 ||
        (day.isNotEmpty && int.parse(day) > 3) ||
        year.isNotEmpty;
    final masked = (
      month: month,
      day: completeDay ? day.padLeft(2, '0') : day,
      year: year,
    );
    return _maskedValue(
      masked,
      segment: day.isEmpty || !completeDay
          ? _ExpirySegment.day
          : year.length < 4
          ? _ExpirySegment.year
          : null,
      selectWhole: day.isEmpty,
    );
  }

  TextEditingValue _maskedValue(
    _ExpiryParts parts, {
    _ExpirySegment? segment,
    bool selectWhole = false,
  }) {
    final month = parts.month == null
        ? AppStrings.expiryDateMonthPlaceholder
        : AppStrings.expiryDateMonths[parts.month! - 1];
    final day =
        parts.day +
        AppStrings.expiryDateDayPlaceholder.substring(parts.day.length);
    final year =
        parts.year +
        AppStrings.expiryDateYearPlaceholder.substring(parts.year.length);
    final text = '$month $day, $year';
    final dayStart = month.length + 1;
    final yearStart = month.length + 5;
    final selection = switch (segment) {
      _ExpirySegment.month => TextSelection(
        baseOffset: 0,
        extentOffset: month.length,
      ),
      _ExpirySegment.day => TextSelection(
        baseOffset: dayStart + (selectWhole ? 0 : parts.day.length),
        extentOffset: dayStart + 2,
      ),
      _ExpirySegment.year => TextSelection(
        baseOffset: yearStart + (selectWhole ? 0 : parts.year.length),
        extentOffset: yearStart + 4,
      ),
      null => TextSelection.collapsed(offset: text.length),
    };
    return TextEditingValue(text: text, selection: selection);
  }

  _ExpiryParts? _maskedParts(String value) {
    final match = RegExp(
      r'^([a-zA-Z]+) (\d{0,2}D{0,2}), (\d{0,4}Y{0,4})$',
    ).firstMatch(value);
    if (match == null || match[2]!.length != 2 || match[3]!.length != 4) {
      return null;
    }
    final month = _monthNumber(match[1]!);
    if (month == null && match[1] != AppStrings.expiryDateMonthPlaceholder) {
      return null;
    }
    return (
      month: month,
      day: match[2]!.replaceAll('D', ''),
      year: match[3]!.replaceAll('Y', ''),
    );
  }

  _ExpirySegment _segmentAt(String text, int offset) {
    final monthEnd = text.indexOf(' ');
    return offset <= monthEnd
        ? _ExpirySegment.month
        : offset < monthEnd + 5
        ? _ExpirySegment.day
        : _ExpirySegment.year;
  }

  _ExpiryEdit _replacement(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final start = oldValue.selection.start;
    final end = oldValue.selection.end;
    if (oldValue.selection.isValid &&
        end <= oldValue.text.length &&
        newValue.text.length >= start + oldValue.text.length - end &&
        newValue.text.startsWith(oldValue.text.substring(0, start)) &&
        newValue.text.endsWith(oldValue.text.substring(end))) {
      return (
        start: start,
        end: end,
        inserted: newValue.text.substring(
          start,
          newValue.text.length - oldValue.text.length + end,
        ),
      );
    }
    var prefix = 0;
    while (prefix < oldValue.text.length &&
        prefix < newValue.text.length &&
        oldValue.text[prefix] == newValue.text[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldValue.text.length - prefix &&
        suffix < newValue.text.length - prefix &&
        oldValue.text[oldValue.text.length - suffix - 1] ==
            newValue.text[newValue.text.length - suffix - 1]) {
      suffix++;
    }
    return (
      start: prefix,
      end: oldValue.text.length - suffix,
      inserted: newValue.text.substring(prefix, newValue.text.length - suffix),
    );
  }

  void _onFocusChanged() {
    if (focusNode.hasFocus && textController.text.isEmpty) {
      _pendingMonthDigit = null;
      textController.value = _maskedValue(
        (month: null, day: '', year: ''),
        segment: _ExpirySegment.month,
        selectWhole: true,
      );
    }
  }

  void _onTextChanged() {
    if (textController.text.isEmpty) {
      _pendingMonthDigit = null;
    }
    final date = selectedDate;
    final parts = _readParts(textController.text);
    _errorText = date != null && date.isBefore(today)
        ? AppStrings.expiryDateInPast
        : date == null && parts?.year?.length == 4
        ? AppStrings.expiryDateInvalid
        : null;
    notifyListeners();
  }

  DateTime? _parseInitialDate(String value) {
    final isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}(?=[T ])').firstMatch(value);
    if (isoDate != null) {
      return _parseDate(isoDate.group(0)!);
    }
    // The document card also accepts day-first labels and Unix timestamps.
    final dayFirst = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+),?\s+(\d{4})$',
    ).firstMatch(value);
    if (dayFirst != null) {
      return _parseDate('${dayFirst[2]} ${dayFirst[1]}, ${dayFirst[3]}');
    }
    if (RegExp(r'^\d{10}(?:\d{3})?$').hasMatch(value)) {
      final timestamp = int.parse(value);
      return DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(
          value.length == 13 ? timestamp : timestamp * 1000,
        ),
      );
    }
    return _parseDate(value);
  }

  DateTime? _parseDate(String value) {
    final parts = _readParts(value);
    final month = parts == null ? null : _monthNumber(parts.month);
    final day = int.tryParse(parts?.day ?? '');
    final yearText = parts?.year ?? '';
    final year = int.tryParse(yearText);
    if (month == null ||
        day == null ||
        day < 1 ||
        day > 31 ||
        year == null ||
        yearText.length != 4 ||
        year == 0) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  ({String month, String? day, String? year})? _readParts(String value) {
    final text = value.trim();
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d+)$').firstMatch(text);
    if (iso != null) {
      return (month: iso[2]!, day: iso[3], year: iso[1]);
    }
    if (RegExp(r'^\d{8}$').hasMatch(text)) {
      return (
        month: text.substring(0, 2),
        day: text.substring(2, 4),
        year: text.substring(4),
      );
    }
    final match = RegExp(
      r'^([a-zA-Z]+|\d{1,2})(?:[\s,./-]+(\d*))?(?:[\s,./-]+(\d{0,4}))?$',
    ).firstMatch(text);
    return match == null
        ? null
        : (month: match[1]!, day: match[2], year: match[3]);
  }

  int? _monthNumber(String value) {
    final numericMonth = int.tryParse(value);
    if (numericMonth != null) {
      return numericMonth >= 1 && numericMonth <= 12 ? numericMonth : null;
    }
    final normalized = value.toLowerCase();
    if (normalized == 'sept') {
      return 9;
    }
    final index = AppStrings.expiryDateMonths.indexWhere(
      (month) => month.toLowerCase() == normalized,
    );
    if (index >= 0) {
      return index + 1;
    }
    final fullIndex = AppStrings.expiryDateFullMonths.indexWhere(
      (month) => month.toLowerCase() == normalized,
    );
    return fullIndex < 0 ? null : fullIndex + 1;
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChanged);
    focusNode.dispose();
    textController.removeListener(_onTextChanged);
    textController.dispose();
    super.dispose();
  }
}
