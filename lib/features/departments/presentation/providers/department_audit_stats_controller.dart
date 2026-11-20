import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/department_audit_stats.dart';
import '../../domain/usecases/manage_departments_use_case.dart';

class DepartmentAuditStatsController extends ChangeNotifier {
  DepartmentAuditStatsController(this._manageDepartments, this._departmentId);

  final ManageDepartmentsUseCase _manageDepartments;
  final String _departmentId;

  bool _isDisposed = false;
  bool _isLoading = false;
  String? _errorMessage;
  DepartmentAuditStats? _stats;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DepartmentAuditStats? get stats => _stats;

  Future<void> load() async {
    if (_isDisposed || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stats = await _manageDepartments.getAuditStats(_departmentId);
      if (!_isDisposed) _stats = stats;
    } catch (error) {
      if (!_isDisposed) {
        _errorMessage = AppStrings.departmentAuditStatsLoadError;
        debugPrint('Unable to load department audit stats: $error');
      }
    } finally {
      if (!_isDisposed) {
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
