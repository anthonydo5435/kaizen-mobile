import 'package:flutter/foundation.dart';

import '../repositories/compliance_repository.dart';

class UploadComplianceDocumentUseCase {
  const UploadComplianceDocumentUseCase(this._repository);

  final ComplianceRepository _repository;
  Future<void> call({
    required String complianceDocumentId,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    String? name,
    String description = '',
    String? expiryDate,
    ValueChanged<double>? onUploadProgress,
    VoidCallback? onRecordUploadStarted,
  }) async {
    final presignedUpload = await _repository
        .generateComplianceDocumentUploadUrl(fileName: fileName);

    await _repository.uploadComplianceDocumentFile(
      uploadUrl: presignedUpload.uploadUrl,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onUploadProgress,
    );

    onRecordUploadStarted?.call();
    await _repository.uploadComplianceDocumentRecord(
      complianceDocumentId: complianceDocumentId,
      fileName: fileName,
      documentUrl: _urlWithoutQuery(presignedUpload.uploadUrl),
      name: name,
      description: description,
      expiryDate: expiryDate,
    );
  }

  String _urlWithoutQuery(String value) {
    final querySeparatorIndex = value.indexOf('?');
    if (querySeparatorIndex == -1) {
      return value;
    }

    return value.substring(0, querySeparatorIndex);
  }
}
