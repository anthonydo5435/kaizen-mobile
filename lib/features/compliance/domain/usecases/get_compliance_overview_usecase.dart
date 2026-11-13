import '../entities/compliance_overview.dart';
import '../repositories/compliance_repository.dart';

class GetComplianceOverviewUseCase {
  const GetComplianceOverviewUseCase(this._repository);

  final ComplianceRepository _repository;

  Future<ComplianceOverview> call({bool forceRefresh = false, String? name}) {
    return _repository.getComplianceOverview(
      forceRefresh: forceRefresh,
      name: name,
    );
  }
}
