import '../repositories/compliance_document_media_repository.dart';

class PickComplianceDocumentFileUseCase {
  const PickComplianceDocumentFileUseCase(this._repository);

  final ComplianceDocumentMediaRepository _repository;

  Future<String?> call(ComplianceDocumentFileSource source) async {
    final path = await _repository.pickFile(source);
    return path == null || path.trim().isEmpty ? null : path;
  }
}
