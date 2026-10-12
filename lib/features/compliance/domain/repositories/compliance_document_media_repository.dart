enum ComplianceDocumentFileSource { camera, gallery, pdf }

abstract class ComplianceDocumentMediaRepository {
  Future<String?> pickFile(ComplianceDocumentFileSource source);
}
