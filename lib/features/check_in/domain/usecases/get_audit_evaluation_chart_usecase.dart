import '../entities/audit_evaluation_chart.dart';
import '../repositories/audit_repository.dart';

class GetAuditEvaluationChartUseCase {
  const GetAuditEvaluationChartUseCase(this._repository);

  final AuditRepository _repository;

  Future<List<AuditEvaluationChart>> call({
    required String profileJobId,
    String? profileUuid,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _repository.getAuditEvaluationChart(
      profileJobId: profileJobId,
      profileUuid: profileUuid,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
