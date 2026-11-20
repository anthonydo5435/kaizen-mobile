import '../../../seat_profile/domain/entities/department.dart';
import '../entities/department_audit_stats.dart';
import '../entities/department_directory.dart';
import '../repositories/departments_repository.dart';

class ManageDepartmentsUseCase {
  const ManageDepartmentsUseCase(this._repository);

  final DepartmentsRepository _repository;

  Future<DepartmentDirectory> getDepartments() {
    return _repository.getDepartments();
  }

  Future<DepartmentAuditStats> getAuditStats(String departmentId) {
    return _repository.getAuditStats(departmentId);
  }

  Future<void> updateDepartment({
    required Department department,
    required String name,
    required String colorHex,
  }) {
    return _repository.updateDepartment(
      department: department,
      name: name,
      colorHex: colorHex,
    );
  }
}
