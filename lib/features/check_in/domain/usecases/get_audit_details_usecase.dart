import '../entities/audit_details.dart';
import '../repositories/audit_repository.dart';

class GetAuditDetailsUseCase {
  const GetAuditDetailsUseCase(this._repository);

  final AuditRepository _repository;

  Future<AuditDetails> call({
    required String profileJobId,
    required int year,
    required int quarter,
    String? profileUuid,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _repository.getAuditDetails(
      profileJobId: profileJobId,
      year: year,
      quarter: quarter,
      profileUuid: profileUuid,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
