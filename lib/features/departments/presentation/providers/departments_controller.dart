import 'package:flutter/material.dart';

import '../../../seat_profile/domain/entities/department.dart';
import '../../data/datasources/departments_remote_data_source.dart';
import '../../data/repositories/departments_repository_impl.dart';
import '../../domain/usecases/manage_departments_use_case.dart';

class DepartmentsController extends ChangeNotifier {
  DepartmentsController(this._manageDepartmentsUseCase);

  final ManageDepartmentsUseCase _manageDepartmentsUseCase;
  final TextEditingController searchController = TextEditingController();

  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<Department> _allDepartments = const <Department>[];
  List<Department> _visibleDepartments = const <Department>[];
  Set<String>? _auditStatsDepartmentIds;

  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasSearchQuery => _searchQuery.trim().isNotEmpty;
  List<Department> get departments =>
      List<Department>.unmodifiable(_visibleDepartments);

  bool canViewAuditStats(String departmentId) =>
      _auditStatsDepartmentIds?.contains(departmentId) ?? true;

  Future<void> initialize() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadDepartments();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isInitialLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_isInitialLoading || _isRefreshing) {
      return;
    }

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadDepartments();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isRefreshing = false;
    notifyListeners();
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    _applySearch();
  }

  Future<void> updateDepartment({
    required Department department,
    required String name,
    required String colorHex,
  }) async {
    await _manageDepartmentsUseCase.updateDepartment(
      department: department,
      name: name,
      colorHex: colorHex,
    );

    _replaceDepartment(
      Department(
        id: department.id,
        name: name,
        colorHex: colorHex,
        fromSandbox: department.fromSandbox,
        driveId: department.driveId,
      ),
    );

    try {
      await _loadDepartments(notify: false);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadDepartments({bool notify = false}) async {
    final directory = await _manageDepartmentsUseCase.getDepartments();
    _allDepartments = directory.departments;
    _auditStatsDepartmentIds = directory.auditStatsDepartmentIds;
    _applySearch(notify: notify);
  }

  void _replaceDepartment(Department updatedDepartment) {
    _allDepartments = List<Department>.unmodifiable(
      _allDepartments.map((department) {
        if (department.id != updatedDepartment.id) {
          return department;
        }

        return updatedDepartment;
      }),
    );
    _applySearch();
  }

  void _applySearch({bool notify = true}) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      _visibleDepartments = List<Department>.unmodifiable(_allDepartments);
    } else {
      _visibleDepartments = List<Department>.unmodifiable(
        _allDepartments.where((department) {
          final name = department.name.trim().toLowerCase();
          final colorHex = (department.colorHex ?? '').trim().toLowerCase();
          return name.contains(normalizedQuery) ||
              colorHex.contains(normalizedQuery);
        }),
      );
    }

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

DepartmentsRepositoryImpl createDepartmentsRepository(
  DepartmentsRemoteDataSource remoteDataSource,
) {
  return DepartmentsRepositoryImpl(remoteDataSource);
}

ManageDepartmentsUseCase createManageDepartmentsUseCase(
  DepartmentsRepositoryImpl repository,
) {
  return ManageDepartmentsUseCase(repository);
}
