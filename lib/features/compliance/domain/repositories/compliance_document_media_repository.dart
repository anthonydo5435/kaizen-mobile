import '../entities/picked_compliance_document_file.dart';

enum ComplianceDocumentFileSource { camera, gallery, pdf }

abstract class ComplianceDocumentMediaRepository {
  Future<PickedComplianceDocumentFile?> pickFile(
    ComplianceDocumentFileSource source,
  );
}
