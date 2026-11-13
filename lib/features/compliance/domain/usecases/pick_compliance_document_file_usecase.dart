import '../entities/picked_compliance_document_file.dart';
import '../repositories/compliance_document_media_repository.dart';

class PickComplianceDocumentFileUseCase {
  const PickComplianceDocumentFileUseCase(this._repository);

  final ComplianceDocumentMediaRepository _repository;

  Future<PickedComplianceDocumentFile?> call(
    ComplianceDocumentFileSource source,
  ) async {
    final file = await _repository.pickFile(source);
    return file == null || file.path.trim().isEmpty ? null : file;
  }
}
