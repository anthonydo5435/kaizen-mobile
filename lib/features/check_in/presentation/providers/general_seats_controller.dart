import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/seat_audit.dart';
import '../../domain/repositories/audit_repository.dart';

class GeneralSeatsController extends ChangeNotifier {
  GeneralSeatsController(
    this._repository, {
    int pageSize = 12,
    bool filterByPeriod = true,
  }) : _pageSize = pageSize,
       _filterByPeriod = filterByPeriod {
    final period = CustomFunctions.currentYearQuarter();
    _year = period.year;
    _quarter = period.quarter;
  }

  final AuditRepository _repository;
  final int _pageSize;
  final bool _filterByPeriod;
  late int _year;
  late int _quarter;
  SeatAuditPage? _page;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasInitialized = false;
  bool _isDisposed = false;
  String? _error;
  String? _paginationError;
  int _requestGeneration = 0;

  int get year => _year;
  int get quarter => _quarter;
  List<SeatAudit> get seats => _page?.results ?? const <SeatAudit>[];
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreSeats => _page?.next != null;
  String? get error => _error;
  String? get paginationError => _paginationError;
  String get yearQuarterLabel => '$_year - Q$_quarter';
  List<int> get yearOptions {
    final currentYear = CustomFunctions.currentYearQuarter().year;
    return {currentYear - 1, currentYear, currentYear + 1, _year}.toList()
      ..sort((left, right) => right.compareTo(left));
  }

  String scoreLabel(SeatAudit seat) {
    if (seat.overallScore == 0 && seat.lastAuditDate == null) {
      return AppStrings.auditScoreUnavailable;
    }
    return seat.overallScore == seat.overallScore.roundToDouble()
        ? seat.overallScore.toStringAsFixed(0)
        : seat.overallScore.toStringAsFixed(1);
  }

  Future<void> initialize() async {
    if (_hasInitialized || _isDisposed) return;
    _hasInitialized = true;
    await _loadFirstPage();
  }

  Future<void> refresh() => _loadFirstPage(forceRefresh: true);

  Future<void> applyYearQuarter(String? label) async {
    if (label == null) return;
    final match = RegExp(r'^(\d{4}) - Q([1-4])$').firstMatch(label);
    if (match == null) return;
    final year = int.parse(match.group(1)!);
    final quarter = int.parse(match.group(2)!);
    if (_year == year && _quarter == quarter) return;
    _year = year;
    _quarter = quarter;
    await _loadFirstPage(clear: true);
  }

  Future<void> _loadFirstPage({
    bool clear = false,
    bool forceRefresh = false,
  }) async {
    if (_isDisposed) return;
    final generation = ++_requestGeneration;
    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    _paginationError = null;
    if (clear) _page = null;
    notifyListeners();
    try {
      final page = await _repository.getSeatAudits(
        page: 1,
        pageSize: _pageSize,
        year: _filterByPeriod ? _year : null,
        quarter: _filterByPeriod ? _quarter : null,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed || generation != _requestGeneration) return;
      _page = page;
    } catch (_) {
      if (_isDisposed || generation != _requestGeneration) return;
      _error = AppStrings.auditGeneralSeatsLoadError;
    }
    if (_isDisposed || generation != _requestGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNextPage() async {
    final current = _page;
    if (_isDisposed || _isLoading || _isLoadingMore || current?.next == null) {
      return;
    }
    final generation = _requestGeneration;
    _isLoadingMore = true;
    _paginationError = null;
    notifyListeners();
    try {
      final next = await _repository.getSeatAudits(
        page: current!.current + 1,
        pageSize: _pageSize,
        year: _filterByPeriod ? _year : null,
        quarter: _filterByPeriod ? _quarter : null,
      );
      if (_isDisposed || generation != _requestGeneration) return;
      final existingIds = current.results.map((seat) => seat.uuid).toSet();
      _page = SeatAuditPage(
        count: next.count,
        next: next.next,
        previous: next.previous,
        current: next.current,
        results: [
          ...current.results,
          ...next.results.where((seat) => existingIds.add(seat.uuid)),
        ],
      );
    } catch (_) {
      if (_isDisposed || generation != _requestGeneration) return;
      _paginationError = AppStrings.auditGeneralSeatsPageError;
    }
    if (_isDisposed || generation != _requestGeneration) return;
    _isLoadingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
