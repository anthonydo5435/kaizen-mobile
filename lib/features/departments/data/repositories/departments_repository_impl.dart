import '../../../seat_profile/domain/entities/department.dart';
import '../../domain/entities/department_audit_stats.dart';
import '../../domain/entities/department_directory.dart';
import '../../domain/repositories/departments_repository.dart';
import '../datasources/departments_remote_data_source.dart';

class DepartmentsRepositoryImpl implements DepartmentsRepository {
  DepartmentsRepositoryImpl(this._remoteDataSource);

  final DepartmentsRemoteDataSource _remoteDataSource;

  @override
  Future<DepartmentDirectory> getDepartments() {
    return _remoteDataSource.getDepartments();
  }

  @override
  Future<DepartmentAuditStats> getAuditStats(String departmentId) {
    return _remoteDataSource.getAuditStats(departmentId);
  }

  @override
  Future<void> updateDepartment({
    required Department department,
    required String name,
    required String colorHex,
  }) {
    return _remoteDataSource.updateDepartment(
      department: department,
      name: name,
      colorHex: colorHex,
    );
  }
}
