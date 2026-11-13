import '../entities/compliance_document.dart';
import '../repositories/compliance_repository.dart';

class GetComplianceDocumentsUseCase {
  const GetComplianceDocumentsUseCase(this._repository);

  final ComplianceRepository _repository;

  Future<List<ComplianceDocument>> call({
    bool forceRefresh = false,
    String? name,
  }) {
    return _repository.getComplianceDocuments(
      forceRefresh: forceRefresh,
      name: name,
    );
  }
}
