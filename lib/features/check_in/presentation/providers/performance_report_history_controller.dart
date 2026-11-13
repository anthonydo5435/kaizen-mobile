import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/performance_report.dart';

typedef PerformanceReportHistoryLoader =
    Future<List<CertifiedReportOption>> Function(DateTimeRange? range);

/// Keeps saved-report filtering separate from the report currently being viewed.
class PerformanceReportHistoryController extends ChangeNotifier {
  PerformanceReportHistoryController({
    required List<CertifiedReportOption> initialOptions,
    required PerformanceReportHistoryLoader loadReports,
  }) : _options = List.unmodifiable(initialOptions),
       _allOptions = List.unmodifiable(initialOptions),
       _loadReports = loadReports;

  final PerformanceReportHistoryLoader _loadReports;
  List<CertifiedReportOption> _options;
  List<CertifiedReportOption> _allOptions;
  DateTimeRange? _dateRange;
  bool _isLoading = false;
  String? _error;
  int _requestGeneration = 0;
  bool _isDisposed = false;

  List<CertifiedReportOption> get options => _options;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTimeRange? get dateRange => _dateRange;
  String get dateRangeLabel {
    final range = _dateRange;
    if (range == null) return AppStrings.performanceReportAllReports;
    return AppStrings.performanceReportDateRangeLabel(
      CustomFunctions.formatDate(
        range.start.toIso8601String(),
      ).replaceAll(',', ''),
      CustomFunctions.formatDate(
        range.end.toIso8601String(),
      ).replaceAll(',', ''),
    );
  }

  Future<void> refresh() => _loadRange(null, silently: true);

  Future<void> applyDateRange(DateTimeRange range) => _loadRange(range);

  Future<void> clearDates() {
    if (_isDisposed) return Future.value();
    _dateRange = null;
    _options = _allOptions;
    return _loadRange(null);
  }

  Future<void> _loadRange(DateTimeRange? range, {bool silently = false}) async {
    if (_isDisposed) return;
    final generation = ++_requestGeneration;
    _isLoading = !silently;
    _error = null;
    notifyListeners();
    try {
      final options = await _loadReports(range);
      if (_isDisposed || generation != _requestGeneration) return;
      _options = List.unmodifiable(options);
      if (range == null) _allOptions = _options;
      _dateRange = range;
    } catch (_) {
      if (_isDisposed || generation != _requestGeneration) return;
      if (!silently) _error = AppStrings.performanceReportHistoryLoadFailed;
    } finally {
      if (!_isDisposed && generation == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
