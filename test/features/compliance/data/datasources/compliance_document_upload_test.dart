import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/compliance/data/datasources/compliance_remote_data_source.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
  });

  test(
    'the final document PUT sends the edited name and optional description',
    () async {
      final executor = _Executor();
      await ComplianceRemoteDataSource(
        apiCallExecutor: executor,
      ).uploadComplianceDocumentRecord(
        complianceDocumentId: 'document-id',
        fileName: 'original.png',
        documentUrl: 'https://example.com/original.png',
        name: '  Identity document.png  ',
        description: '  Signed photo  ',
        expiryDate: '2027-04-05',
      );
      expect(executor.type, ApiCallType.put);
      expect(
        executor.endpoint,
        ApiEndPoints.uploadComplianceDocument('document-id'),
      );
      expect(executor.parameters, {
        'name': 'Identity document.png',
        'description': 'Signed photo',
        'doc_url': 'https://example.com/original.png',
        'expiry_date': '2027-04-05',
      });
    },
  );

  test(
    'the final PUT includes an empty description and retains the default filename',
    () async {
      final executor = _Executor();
      await ComplianceRemoteDataSource(
        apiCallExecutor: executor,
      ).uploadComplianceDocumentRecord(
        complianceDocumentId: 'document-id',
        fileName: 'photo.png',
        documentUrl: 'https://example.com/photo.png',
      );
      expect(executor.parameters, {
        'name': 'photo.png',
        'description': '',
        'doc_url': 'https://example.com/photo.png',
      });
    },
  );
}

class _Executor extends ApiCallExecutor {
  ApiCallType? type;
  String? endpoint;
  Map<String, dynamic>? parameters;

  @override
  Future<Response> processApi<Response>({
    required ApiCallType apiCallType,
    required String endpoint,
    required Response Function(dynamic json) decoder,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    String? authToken,
    bool allowAutoRefresh = true,
    bool allowConflictRetry = true,
    bool invalidateCacheBeforeRequest = false,
  }) async {
    type = apiCallType;
    this.endpoint = endpoint;
    this.parameters = parameters;
    return decoder({});
  }
}
