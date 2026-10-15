import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/services/file_uploader.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../training/domain/entities/seat_description_training.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/audit_job_option.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/entities/seat_description_final_audit_report.dart';
import '../models/audit_description_audit_model.dart';
import '../models/audit_details_model.dart';
import '../models/audit_evaluation_chart_model.dart';
import '../models/audit_list_model.dart';
import '../models/audit_main_list_model.dart';
import '../models/description_comments_response_model.dart';
import '../models/performance_report_model.dart';
import '../models/quarterly_audit_model.dart';
import '../models/seat_description_audit_report_comments_model.dart';
import '../models/seat_description_final_audit_report_model.dart';
import '../models/seat_description_training_model.dart';
import '../models/single_audit_report_category_details_model.dart';

class AuditRemoteDataSource {
  AuditRemoteDataSource({
    ApiCallExecutor? apiCallExecutor,
    FileUploader? fileUploader,
  }) : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor(),
       _fileUploader = fileUploader ?? const FileUploader();

  static const Map<String, String> _karachiTimezoneHeader = <String, String>{
    'X-Timezone': 'Asia/Karachi',
  };

  final ApiCallExecutor _apiCallExecutor;
  final FileUploader _fileUploader;

  Future<AuditMainListModel> getAuditMainList({
    required int page,
    required int pageSize,
    required int year,
    required int quarter,
    String? search,
    String? jobUuid,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<AuditMainListModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAudit,
      invalidateCacheBeforeRequest: forceRefresh,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (jobUuid != null && jobUuid.trim().isNotEmpty) 'job': jobUuid.trim(),
        'page_size': pageSize,
        'year': year,
        'quarter': quarter,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditMainListModel.fromApiJson(
          json: json,
          year: year,
          quarter: quarter,
        );
      },
    );
  }

  Future<AuditMainListModel> getAuditTeamMembers({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
  }) {
    return _apiCallExecutor.processApi<AuditMainListModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAudit,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'page': page,
        'page_size': pageSize,
        if (year != null) 'year': year,
        if (quarter != null) 'quarter': quarter,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditMainListModel.fromApiJson(
          json: json,
          year: year ?? 0,
          quarter: quarter ?? 0,
        );
      },
    );
  }

  Future<AuditMainListModel> getMyAudits({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<AuditMainListModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditMyAudits,
      invalidateCacheBeforeRequest: forceRefresh,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page_size': pageSize,
        if (year != null) 'year': year,
        if (quarter != null) 'quarter': quarter,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditMainListModel.fromApiJson(
          json: json,
          year: year ?? 0,
          quarter: quarter ?? 0,
        );
      },
    );
  }

  Future<dynamic> getMyPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    var result = _apiCallExecutor.processApi<dynamic>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditMyPerformanceSnapshot,
      invalidateCacheBeforeRequest: forceRefresh,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      decoder: (json) => json,
    );
    return result;
  }

  Future<dynamic> getPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    var result = _apiCallExecutor.processApi<dynamic>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditPerformanceSnapshot,
      invalidateCacheBeforeRequest: forceRefresh,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      decoder: (json) => json,
    );
    return result;
  }

  Future<List<String>> getSubordinateJobTitles() {
    return getSubordinateJobOptions().then(
      (options) =>
          options.map((option) => option.title).toList(growable: false),
    );
  }

  Future<List<AuditJobOption>> getSubordinateJobOptions() {
    return _apiCallExecutor.processApi<List<AuditJobOption>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.subordinateJobs,
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        final options =
            json
                .whereType<Map<String, dynamic>>()
                .map((item) {
                  final nestedJob = item['job'] is Map<String, dynamic>
                      ? item['job'] as Map<String, dynamic>
                      : null;
                  final uuid =
                      item['uuid']?.toString().trim() ??
                      item['job_uuid']?.toString().trim() ??
                      nestedJob?['uuid']?.toString().trim() ??
                      '';
                  final title =
                      item['title']?.toString().trim() ??
                      nestedJob?['title']?.toString().trim() ??
                      '';
                  return AuditJobOption(uuid: uuid, title: title);
                })
                .where(
                  (option) => option.uuid.isNotEmpty && option.title.isNotEmpty,
                )
                .toList(growable: false)
              ..sort((left, right) => left.title.compareTo(right.title));

        return options;
      },
    );
  }

  Future<PerformanceReportModel> getPerformanceReportOverview({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final parameters = <String, dynamic>{};
    _appendValidProfileUuid(parameters, profile.profileUuid);

    if (startDate != null && endDate != null) {
      parameters['start'] = CustomFunctions.apiDateString(date: startDate);
      parameters['end'] = CustomFunctions.apiDateString(date: endDate);
    } else {
      parameters['year'] = year;
      parameters['quarter'] = quarter;
    }

    return _apiCallExecutor.processApi<PerformanceReportModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReportOverview(profile.profileJob),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return PerformanceReportModel.fromApiJson(
          json,
          fallbackProfile: profile,
        );
      },
    );
  }

  Future<Map<String, String>> getPerformanceReportRemarks({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final parameters = <String, dynamic>{};
    if (startDate != null && endDate != null) {
      parameters['start'] = CustomFunctions.apiDateString(date: startDate);
      parameters['end'] = CustomFunctions.apiDateString(date: endDate);
    } else {
      parameters['year'] = year;
      parameters['quarter'] = quarter;
    }
    final trimmedProfileUuid = _normalizedProfileUuid(profile.profileUuid);
    final profileQuery = trimmedProfileUuid == null
        ? ''
        : '?profile_uuid=${Uri.encodeQueryComponent(trimmedProfileUuid)}';

    return _apiCallExecutor.processApi<Map<String, String>>(
      apiCallType: ApiCallType.post,
      endpoint:
          '${ApiEndPoints.auditReportRemarks(profile.profileJob)}$profileQuery',
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! Map) {
          throw const ApiError.invalidResponse();
        }

        final descriptions = json['descriptions'];
        if (descriptions is! Map) {
          throw const ApiError.invalidResponse();
        }

        return descriptions.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      },
    );
  }

  Future<List<CertifiedReportOption>> getCertifiedReports({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final parameters = <String, dynamic>{};
    _appendValidProfileUuid(parameters, profile.profileUuid);
    if (startDate != null && endDate != null) {
      parameters['start'] = CustomFunctions.apiDateString(date: startDate);
      parameters['end'] = CustomFunctions.apiDateString(date: endDate);
    } else {
      parameters['year'] = year;
      parameters['quarter'] = quarter;
    }

    return _apiCallExecutor.processApi<List<CertifiedReportOption>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReportCertifiedReports(profile.profileJob),
      authToken: AppPreference.getAuthToken(),
      headers: _karachiTimezoneHeader,
      parameters: parameters,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        final options = <CertifiedReportOption>[];
        for (final item in json.whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          final option = CertifiedReportOption(
            uuid: map['uuid']?.toString().trim() ?? '',
            displayName: map['display_name']?.toString().trim() ?? '',
          );
          if (option.uuid.isNotEmpty && option.displayName.isNotEmpty) {
            options.add(option);
          }
        }

        return options;
      },
    );
  }

  Future<CertifiedReportDetail> getCertifiedReportDetail({
    required String certifiedReportUuid,
    required AuditProfile fallbackProfile,
  }) {
    return _apiCallExecutor.processApi<CertifiedReportDetail>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReportCertifiedReportDetail(
        certifiedReportUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final reportSnapshot = json['report_snapshot'];
        if (reportSnapshot is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final overview = reportSnapshot['overview'];
        if (overview is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final baseReport = PerformanceReportModel.fromApiJson(
          overview,
          fallbackProfile: fallbackProfile,
        );

        return CertifiedReportDetail(
          report: PerformanceReport(
            profile: baseReport.profile,
            createdAt: baseReport.createdAt,
            personalityAvatarImagePath: baseReport.personalityAvatarImagePath,
            hasPersonalityData: baseReport.hasPersonalityData,
            isCertified: json['is_certified'] == true,
            certifiedAt: json['certified_at']?.toString().trim(),
            employeeSignatureName: baseReport.profile.name,
            selectedProfileSignatureUuid:
                baseReport.selectedProfileSignatureUuid,
            selectedProfileSignatureUrl: baseReport.selectedProfileSignatureUrl,
            facilitatorSignatureUrl: json['facilitator_signature']
                ?.toString()
                .trim(),
            facilitatorName:
                json['facilatator_name']?.toString().trim().isNotEmpty == true
                ? json['facilatator_name']?.toString().trim()
                : json['facilitator_name']?.toString().trim(),
            reportSnapshot: baseReport.reportSnapshot,
            rawPersonalityDescription: baseReport.rawPersonalityDescription,
            overallPerformanceScore: baseReport.overallPerformanceScore,
            confidenceLevel: baseReport.confidenceLevel,
            archetypeTitle: baseReport.archetypeTitle,
            archetypeSubtitle: baseReport.archetypeSubtitle,
            archetypeSummary: baseReport.archetypeSummary,
            guidanceParagraphs: baseReport.guidanceParagraphs,
            categoryTabs: baseReport.categoryTabs,
            selectedCategoryIndex: baseReport.selectedCategoryIndex,
            ratingRows: baseReport.ratingRows,
            paygradePipeline: baseReport.paygradePipeline,
            currentPaygrade: baseReport.currentPaygrade,
            paygradeUnit: baseReport.paygradeUnit,
            coreValues: baseReport.coreValues,
            remarkVersion: baseReport.remarkVersion,
          ),
          commitmentComment:
              json['commitment_comment']?.toString().trim() ?? '',
        );
      },
    );
  }

  Future<String> getCertifiedReportPdfUrl({
    required String certifiedReportUuid,
  }) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.auditReportCertifiedReportDownloadPdf(
        certifiedReportUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final url = json['url']?.toString().trim() ?? '';
        if (url.isEmpty) {
          throw const ApiError.invalidResponse();
        }

        return url;
      },
    );
  }

  Future<String?> certifyPerformanceReport({
    required String profileJobId,
    required Map<String, dynamic> payload,
  }) {
    return _apiCallExecutor.processApi<String?>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.auditReportCertify(profileJobId),
      authToken: AppPreference.getAuthToken(),
      parameters: payload,
      decoder: (json) {
        if (json is Map<String, dynamic>) {
          final directUuid = json['uuid']?.toString().trim();
          if (directUuid != null && directUuid.isNotEmpty) {
            return directUuid;
          }

          final certifiedReport = json['certified_report'];
          if (certifiedReport is Map<String, dynamic>) {
            final nestedUuid = certifiedReport['uuid']?.toString().trim();
            if (nestedUuid != null && nestedUuid.isNotEmpty) {
              return nestedUuid;
            }
          }
        }

        if (json is String) {
          final value = json.trim();
          return value.isEmpty ? null : value;
        }

        return null;
      },
    );
  }

  Future<AuditDetailsModel> getAuditDetails({
    required String profileJobId,
    required int year,
    required int quarter,
    String? profileUuid,
  }) {
    final parameters = <String, dynamic>{'year': year, 'quarter': quarter};
    _appendQuarterlyAuditProfile(parameters, profileUuid);

    return _apiCallExecutor.processApi<AuditDetailsModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditDetails(profileJobId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditDetailsModel.fromApiJson(json);
      },
    );
  }

  Future<List<AuditEvaluationChartModel>> getAuditEvaluationChart({
    required String profileJobId,
    String? profileUuid,
  }) {
    final parameters = <String, dynamic>{'time_range': 'current_quarter'};
    _appendQuarterlyAuditProfile(parameters, profileUuid);

    return _apiCallExecutor.processApi<List<AuditEvaluationChartModel>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditEvaluationChart(profileJobId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map<String, dynamic>>()
            .map(AuditEvaluationChartModel.fromApiJson)
            .toList(growable: false);
      },
    );
  }

  Future<List<AuditListModel>> getAuditReport({
    required int quarter,
    required int year,
    required String profileJobId,
  }) {
    return _apiCallExecutor.processApi<List<AuditListModel>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReport(profileJobId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'quarter': quarter, 'year': year},
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map<String, dynamic>>()
            .map(AuditListModel.fromApiJson)
            .toList(growable: false);
      },
    );
  }

  Future<List<SingleAuditReportCategoryDetailsModel>>
  getAuditReportCategoryDetails({
    required String categoryId,
    required int quarter,
    required int year,
  }) {
    return _apiCallExecutor
        .processApi<List<SingleAuditReportCategoryDetailsModel>>(
          apiCallType: ApiCallType.get,
          endpoint: ApiEndPoints.auditReportJobCategory(categoryId),
          authToken: AppPreference.getAuthToken(),
          parameters: {'quarter': quarter, 'year': year},
          decoder: (json) {
            if (json is! List) {
              throw const ApiError.invalidResponse();
            }

            return json
                .whereType<Map<String, dynamic>>()
                .map(SingleAuditReportCategoryDetailsModel.fromApiJson)
                .toList(growable: false);
          },
        );
  }

  Future<SeatDescriptionFinalAuditReportModel>
  getSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    final parameters = _buildTimeRangeParameters(
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
    final trimmedProfileUuid = profileUuid?.trim();
    if (trimmedProfileUuid != null && trimmedProfileUuid.isNotEmpty) {
      parameters['profile_uuid'] = trimmedProfileUuid;
    }
    return _apiCallExecutor.processApi<SeatDescriptionFinalAuditReportModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReportSeatDescription(
        flowFirstId: flowFirstId,
        descriptionId: descriptionId,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionFinalAuditReportModel.fromApiJson(json);
      },
    );
  }

  Future<SeatDescriptionAuditReportCommentsModel>
  getSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    final parameters = _buildTimeRangeParameters(
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
    final trimmedProfileUuid = profileUuid?.trim();
    if (trimmedProfileUuid != null && trimmedProfileUuid.isNotEmpty) {
      parameters['profile_uuid'] = trimmedProfileUuid;
    }
    return _apiCallExecutor.processApi<SeatDescriptionAuditReportCommentsModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditMediaSeatDescription(
        flowFirstId: flowFirstId,
        descriptionId: descriptionId,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: SeatDescriptionAuditReportCommentsModel.fromApiJson,
    );
  }

  Future<List<SeatDescriptionFinalAuditProfile>>
  getSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    final parameters = _buildTimeRangeParameters(
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
    final trimmedProfileUuid = profileUuid?.trim();
    if (trimmedProfileUuid != null && trimmedProfileUuid.isNotEmpty) {
      parameters['profile_uuid'] = trimmedProfileUuid;
    }
    return _apiCallExecutor.processApi<List<SeatDescriptionFinalAuditProfile>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditReportSeatDescriptionProfiles(
        flowFirstId: flowFirstId,
        descriptionId: descriptionId,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map>()
            .map(
              (item) => SeatDescriptionFinalAuditProfileModel.fromApiJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<List<SeatDescriptionTrainingModule>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.seatDescriptionTrainingModules(descriptionId),
      authToken: AppPreference.getAuthToken(),
      invalidateCacheBeforeRequest: forceRefresh,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map>()
            .map(
              (item) => SeatDescriptionTrainingModuleModel.fromApiJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingModule>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.trainingModules,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'job': jobId,
        'job_category_description': descriptionId,
        'title': title,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingModuleModel.fromApiJson(json);
      },
    );
  }

  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingModuleDetail>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      invalidateCacheBeforeRequest: forceRefresh,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingModuleDetailModel.fromApiJson(json);
      },
    );
  }

  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingDocument>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleDocument(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json == null) {
          return const SeatDescriptionTrainingDocumentModel(
            uuid: '',
            text: null,
          );
        }

        if (json is Map<String, dynamic>) {
          return SeatDescriptionTrainingDocumentModel.fromApiJson(json);
        }

        if (json is Map) {
          return SeatDescriptionTrainingDocumentModel.fromApiJson(
            Map<String, dynamic>.from(json),
          );
        }

        if (json is List && json.isEmpty) {
          return const SeatDescriptionTrainingDocumentModel(
            uuid: '',
            text: null,
          );
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId}) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingAssignment>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json == null) {
          return const SeatDescriptionTrainingAssignmentModel(
            uuid: '',
            title: null,
            instructions: null,
          );
        }

        if (json is Map<String, dynamic>) {
          return SeatDescriptionTrainingAssignmentModel.fromApiJson(json);
        }

        if (json is Map) {
          return SeatDescriptionTrainingAssignmentModel.fromApiJson(
            Map<String, dynamic>.from(json),
          );
        }

        if (json is List && json.isEmpty) {
          return const SeatDescriptionTrainingAssignmentModel(
            uuid: '',
            title: null,
            instructions: null,
          );
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId}) {
    return _apiCallExecutor.processApi<List<SeatDescriptionTrainingQuestion>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleQuestions(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        final questionsJson = switch (json) {
          List<dynamic> list => list,
          Map<String, dynamic> map => map['questions'],
          Map map => Map<String, dynamic>.from(map)['questions'],
          _ => null,
        };
        if (questionsJson is! List) {
          throw const ApiError.invalidResponse();
        }

        return questionsJson
            .whereType<Map>()
            .map(
              (item) => SeatDescriptionTrainingQuestionModel.fromApiJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingQuestion>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.addTrainingModuleQuestion(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': '',
        'question': questionText,
        if (imageId != null && imageId.trim().isNotEmpty)
          'image': imageId.trim(),
        'correct_option': correctOptionUuid,
        'options': options
            .map((option) => {'uuid': option.uuid, 'text': option.text})
            .toList(growable: false),
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingQuestionModel.fromApiJson(json);
      },
    );
  }

  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    final uploadedImage = await _fileUploader.uploadOnboardingImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
    return uploadedImage.uuid;
  }

  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleQuiz(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'num_questions': numQuestions,
        'difficulty_level': difficultyLevel,
        'replace_existing_questions': replaceExistingQuestions,
        'options_per_question': optionsPerQuestion,
      },
      decoder: (_) {},
    );
  }

  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleSop(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<String?>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleSummary(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is Map<String, dynamic>) {
          return _readFirstString(json, const ['description']);
        }

        if (json is Map) {
          return _readFirstString(Map<String, dynamic>.from(json), const [
            'description',
          ]);
        }

        if (json == null) {
          return null;
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  }) {
    final parameters = <String, dynamic>{};
    if (title != null) {
      parameters['title'] = title.trim();
    }
    if (description != null) {
      parameters['description'] = description.trim();
    }
    if (parameters.isEmpty) {
      return Future<void>.value();
    }

    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'description': description.trim(),
        'is_publicly_available': isPubliclyAvailable,
      },
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'is_publicly_available': isPubliclyAvailable},
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  }) {
    final resolvedDocumentId = documentId.trim();
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingDocument(resolvedDocumentId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'uuid': resolvedDocumentId, 'text': text.trim()},
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  }) {
    final resolvedAssignmentId = assignmentId?.trim() ?? '';
    return _apiCallExecutor.processApi<void>(
      apiCallType: resolvedAssignmentId.isNotEmpty
          ? ApiCallType.patch
          : ApiCallType.put,
      endpoint: resolvedAssignmentId.isNotEmpty
          ? ApiEndPoints.trainingAssignment(resolvedAssignmentId)
          : ApiEndPoints.addTrainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        if (title != null) 'title': title.trim(),
        'instructions': instructions.trim(),
      },
      decoder: (_) {},
    );
  }

  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  }) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.generatePreSignedUrl,
      authToken: AppPreference.getAuthToken(),
      parameters: {'key': 'lms', 'file_name': fileName},
      decoder: (json) {
        final uploadUrl = _readFirstString(json, const ['signedUrl']);
        if (uploadUrl == null || uploadUrl.isEmpty) {
          throw const ApiError.invalidResponse();
        }

        return uploadUrl;
      },
    );
  }

  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null) {
      throw const ApiError.invalidUrl();
    }

    final request = _ProgressByteRequest(
      'PUT',
      uri,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onProgress,
    );

    final client = http.Client();
    late final http.Response response;
    try {
      final streamedResponse = await client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiError.requestFailed(response.statusCode);
    }
  }

  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingVideo>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.addTrainingModuleVideo(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': videoUuid,
        'title': title,
        'url': videoUrl,
        'duration': duration,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingVideoModel.fromApiJson(json);
      },
    );
  }

  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.trainingVideoDetail(videoId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'thumbnail_link': thumbnailUrl.trim(),
        'thumbnails': <String>[thumbnailUrl.trim()],
      },
      decoder: (_) {},
    );
  }

  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingQuestion>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.updateQuestion(questionId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': questionId,
        'question': questionText,
        'options': options
            .map((option) => {'uuid': option.uuid, 'text': option.text})
            .toList(growable: false),
        'correct_option': correctOptionUuid,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingQuestionModel.fromApiJson(json);
      },
    );
  }

  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.updateQuestion(questionId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<QuarterlyAuditModel> getQuarterlyAudit({
    required String quarterlyAuditId,
    required String date,
  }) {
    return _apiCallExecutor.processApi<QuarterlyAuditModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditDetail(quarterlyAuditId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'date': date},
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return QuarterlyAuditModel.fromApiJson(json);
      },
    );
  }

  Future<void> markFavoriteSubordinate({required String profileJobId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.favoriteSubordinate,
      authToken: AppPreference.getAuthToken(),
      parameters: {'profile_job': profileJobId},
      decoder: (_) {},
    );
  }

  Future<void> markUnfavoriteSubordinate({required String profileJobId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.unfavoriteSubordinate,
      authToken: AppPreference.getAuthToken(),
      parameters: {'profile_job': profileJobId},
      decoder: (_) {},
    );
  }

  Future<AuditDescriptionAuditModel> getAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  }) {
    return _apiCallExecutor.processApi<AuditDescriptionAuditModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.quarterlyAuditDescriptionAudit(
        quarterlyAuditId: quarterlyAuditId,
        descriptionId: descriptionId,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: {'date': date},
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditDescriptionAuditModel.fromApiJson(json);
      },
    );
  }

  Future<AuditDescriptionAuditModel> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) {
    return _apiCallExecutor.processApi<AuditDescriptionAuditModel>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.auditDescription(descriptionId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'audit': audit},
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return AuditDescriptionAuditModel.fromApiJson(json);
      },
    );
  }

  Future<String> generateAuditDescriptionMediaUploadUrl({
    required String fileName,
  }) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.generatePreSignedUrl,
      authToken: AppPreference.getAuthToken(),
      parameters: {'key': 'audit_comments', 'file_name': fileName},
      decoder: (json) {
        final uploadUrl = _readFirstString(json, const ['signedUrl']);
        if (uploadUrl == null || uploadUrl.isEmpty) {
          throw const ApiError.invalidResponse();
        }

        return uploadUrl;
      },
    );
  }

  Future<void> uploadAuditDescriptionMediaFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null) {
      throw const ApiError.invalidUrl();
    }

    final request = _ProgressByteRequest(
      'PUT',
      uri,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onProgress,
    );

    final client = http.Client();
    late final http.Response response;
    try {
      final streamedResponse = await client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiError.requestFailed(response.statusCode);
    }
  }

  Future<void> createAuditDescriptionMedia({
    required String descriptionId,
    required String comment,
    String? mediaUrl,
    String? mediaType,
  }) {
    final parameters = <String, dynamic>{'comment': comment};
    final resolvedMediaUrl = mediaUrl?.trim();
    final resolvedMediaType = mediaType?.trim();
    if (resolvedMediaUrl != null && resolvedMediaUrl.isNotEmpty) {
      parameters['media'] = resolvedMediaUrl;
    }
    if (resolvedMediaType != null && resolvedMediaType.isNotEmpty) {
      parameters['type'] = resolvedMediaType;
    }

    return _apiCallExecutor.processApi(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.createAuditDescriptionMedia(descriptionId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (_) {},
    );
  }

  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) {
    final parameters = <String, dynamic>{'comment': comment};
    return _apiCallExecutor.processApi(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.createAuditDescriptionMedia(descriptionId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (_) {},
    );
  }

  Future<String> uploadPerformanceReportSignatureImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    final uri = ApiEndPoints.resolveUri(ApiEndPoints.images);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${AppPreference.getAuthToken()}'
      ..files.add(
        http.MultipartFile.fromBytes('image', fileBytes, filename: fileName),
      );

    final client = http.Client();
    late final http.Response response;
    try {
      final streamedResponse = await client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiError.requestFailed(response.statusCode);
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const ApiError.invalidResponse();
    }

    final signatureImageId = _readFirstString(decodedBody, const ['uuid']);
    if (signatureImageId == null || signatureImageId.isEmpty) {
      throw const ApiError.invalidResponse();
    }

    return signatureImageId;
  }

  Future<DescriptionCommentsResponseModel> getDescriptionComments({
    required String auditMediaId,
  }) {
    return _apiCallExecutor.processApi<DescriptionCommentsResponseModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.auditMedia(auditMediaId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return DescriptionCommentsResponseModel.fromApiJson(json);
      },
    );
  }

  Future<void> updateAuditMedia({
    required String auditMediaId,
    required String mediaUrl,
    required String mediaType,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.auditMedia(auditMediaId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'media': mediaUrl.trim(), 'type': mediaType.trim()},
      decoder: (_) {},
    );
  }

  Future<CommentAdditionResponseModel> addComment({
    required String auditMediaId,
    required String comment,
    String? parent,
  }) {
    final parameters = <String, dynamic>{'comment': comment};
    if (parent != null && parent.trim().isNotEmpty) {
      parameters['parent'] = parent;
    }

    return _apiCallExecutor.processApi<CommentAdditionResponseModel>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.addAuditMediaComment(auditMediaId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return CommentAdditionResponseModel.fromApiJson(json);
      },
    );
  }

  Future<void> deleteAuditMedia({required String auditMediaId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.auditMedia(auditMediaId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  String? _readFirstString(dynamic json, List<String> keys) {
    if (json is! Map) {
      return null;
    }

    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Map<String, dynamic> _buildTimeRangeParameters({
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    final resolvedTimeRange = timeRange?.trim();
    if (resolvedTimeRange != null && resolvedTimeRange.isNotEmpty) {
      return {'time_range': resolvedTimeRange};
    }

    return {
      if (quarter != null) 'quarter': quarter,
      if (year != null) 'year': year,
    };
  }

  void _appendValidProfileUuid(
    Map<String, dynamic> parameters,
    String? profileUuid,
  ) {
    final normalizedProfileUuid = _normalizedProfileUuid(profileUuid);
    if (normalizedProfileUuid == null) {
      return;
    }

    parameters['profile_uuid'] = normalizedProfileUuid;
  }

  void _appendQuarterlyAuditProfile(
    Map<String, dynamic> parameters,
    String? profileUuid,
  ) {
    final normalizedProfileUuid = _normalizedProfileUuid(profileUuid);
    if (normalizedProfileUuid == null) {
      return;
    }

    parameters['profile'] = normalizedProfileUuid;
  }

  String? _normalizedProfileUuid(String? profileUuid) {
    final trimmedValue = profileUuid?.trim();
    if (trimmedValue == null ||
        trimmedValue.isEmpty ||
        trimmedValue.toLowerCase() == 'null') {
      return null;
    }

    return trimmedValue;
  }
}

class _ProgressByteRequest extends http.BaseRequest {
  _ProgressByteRequest(
    super.method,
    super.url, {
    required this.fileBytes,
    required this.contentType,
    this.onProgress,
  }) {
    headers['Content-Type'] = contentType;
  }

  final List<int> fileBytes;
  final String contentType;
  final ValueChanged<double>? onProgress;

  @override
  http.ByteStream finalize() {
    final totalBytes = fileBytes.length;
    var sentBytes = 0;
    contentLength = totalBytes;
    super.finalize();

    final stream = Stream<List<int>>.fromIterable([fileBytes]).transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call((sentBytes / totalBytes).clamp(0, 1).toDouble());
          }
          sink.add(chunk);
        },
      ),
    );

    return http.ByteStream(stream);
  }
}
