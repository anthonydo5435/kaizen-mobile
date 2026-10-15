import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/compliance_document.dart';

class ComplianceDocumentModel extends ComplianceDocument {
  const ComplianceDocumentModel({
    required super.id,
    required super.title,
    required super.category,
    required super.status,
    required super.updatedAt,
    super.rawStatus,
    super.hasExpiry,
    super.hasLatestDocument,
    super.latestDocumentUuid,
    super.latestDocumentName,
    super.latestDocumentExpiryDate,
    super.latestDocumentCreatedAt,
    super.latestDocumentUrl,
    super.latestDocumentThumbnailUrl,
    super.latestDocumentStatus,
    super.latestDocumentReason,
    super.seatProfiles,
  });

  factory ComplianceDocumentModel.fromApiJson(Map<String, dynamic> json) {
    final jobs = (json['jobs'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .map((job) => job['title']?.toString().trim())
        .whereType<String>()
        .where((title) => title.isNotEmpty)
        .toList(growable: false);

    final allJobs = json['all_jobs'] == true;
    final requiresExpiry = json['expiry'] == true;
    final category = allJobs
        ? 'All Jobs'
        : (jobs == null || jobs.isEmpty ? 'Unassigned' : jobs.join(', '));

    return ComplianceDocumentModel(
      id: json['uuid']?.toString().trim() ?? '',
      title: json['name']?.toString().trim() ?? '',
      category: category,
      status: requiresExpiry ? 'Expiry Required' : 'No Expiry',
      updatedAt: '',
      hasExpiry: requiresExpiry,
      seatProfiles: allJobs
          ? const <String>['All Jobs']
          : (jobs ?? const <String>[]),
    );
  }
}

class ComplianceDocumentModal extends ComplianceDocument {
  const ComplianceDocumentModal({
    required super.id,
    required super.title,
    required super.category,
    required super.status,
    required super.updatedAt,
    super.rawStatus,
    required super.hasExpiry,
    super.hasLatestDocument,
    super.latestDocumentUuid,
    super.latestDocumentName,
    super.latestDocumentExpiryDate,
    super.latestDocumentCreatedAt,
    super.latestDocumentUrl,
    super.latestDocumentThumbnailUrl,
    super.latestDocumentStatus,
    super.latestDocumentReason,
    super.seatProfiles,
  });

  factory ComplianceDocumentModal.fromApiJson(Map<String, dynamic> json) {
    final jobs = (json['jobs'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .map((job) => job['title']?.toString().trim())
        .whereType<String>()
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final latestDocument = json['latest_document'] is Map<String, dynamic>
        ? json['latest_document'] as Map<String, dynamic>
        : null;

    return ComplianceDocumentModal(
      id: json['uuid']?.toString().trim() ?? '',
      title: json['name']?.toString().trim() ?? '',
      category: jobs == null || jobs.isEmpty ? 'Unassigned' : jobs.join(', '),
      status:
          CustomFunctions.displayStatus(json['status']?.toString().trim()) ??
          'Pending',
      rawStatus: json['status']?.toString().trim(),
      updatedAt: json['created_at']?.toString().trim() ?? '',
      hasExpiry: json['has_expiry'] == true,
      hasLatestDocument: latestDocument != null,
      latestDocumentUuid: latestDocument?['uuid']?.toString().trim(),
      latestDocumentName: latestDocument?['name']?.toString().trim(),
      latestDocumentExpiryDate: latestDocument?['expiry_date']
          ?.toString()
          .trim(),
      latestDocumentCreatedAt: latestDocument?['created_at']?.toString().trim(),
      latestDocumentUrl: latestDocument?['doc_url']?.toString().trim(),
      latestDocumentThumbnailUrl: latestDocument?['thumbnail_url']
          ?.toString()
          .trim(),
      latestDocumentStatus: latestDocument?['status']?.toString().trim(),
      latestDocumentReason: latestDocument?['reason']?.toString().trim(),
      seatProfiles: jobs ?? const <String>[],
    );
  }
}
