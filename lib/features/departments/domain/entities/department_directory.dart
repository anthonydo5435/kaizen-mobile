import '../../../seat_profile/domain/entities/department.dart';

class DepartmentDirectory {
  const DepartmentDirectory({
    required this.departments,
    this.auditStatsDepartmentIds,
  });

  final List<Department> departments;
  final Set<String>? auditStatsDepartmentIds;
}
