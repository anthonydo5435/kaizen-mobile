class DepartmentAuditStats {
  const DepartmentAuditStats({
    required this.score,
    required this.confidenceLevel,
    required this.jobStats,
  });

  final double score;
  final double confidenceLevel;
  final List<DepartmentJobAuditStats> jobStats;
}

class DepartmentJobAuditStats {
  const DepartmentJobAuditStats({
    required this.id,
    required this.name,
    required this.totalMembers,
    required this.score,
    required this.confidenceLevel,
  });

  final String id;
  final String name;
  final int totalMembers;
  final double score;
  final double confidenceLevel;
}
