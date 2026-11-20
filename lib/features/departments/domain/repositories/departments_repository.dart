import '../../../seat_profile/domain/entities/department.dart';
import '../entities/department_audit_stats.dart';
import '../entities/department_directory.dart';

abstract class DepartmentsRepository {
  Future<DepartmentDirectory> getDepartments();

  Future<DepartmentAuditStats> getAuditStats(String departmentId);

  Future<void> updateDepartment({
    required Department department,
    required String name,
    required String colorHex,
  });
}
