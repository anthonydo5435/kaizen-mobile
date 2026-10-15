import '../entities/audit_main_list.dart';
import '../repositories/audit_repository.dart';

class GetAuditOverviewUseCase {
  const GetAuditOverviewUseCase(this._repository);

  final AuditRepository _repository;

  Future<AuditMainList> call({
    required int year,
    required int quarter,
    int page = 1,
    int pageSize = 12,
    String? search,
    String? jobUuid,
    bool forceRefresh = false,
  }) {
    return _repository.getAuditMainList(
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      search: search,
      jobUuid: jobUuid,
      forceRefresh: forceRefresh,
    );
  }
}
