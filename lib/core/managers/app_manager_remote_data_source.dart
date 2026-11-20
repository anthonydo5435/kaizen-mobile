import '../network/api_endpoints.dart';
import '../network/api_error.dart';
import '../network/api_processor.dart';
import '../../features/login/data/datasources/auth_remote_data_source.dart';
import '../../features/login/domain/entities/user.dart';
import '../../features/organizations/domain/entities/organization.dart';
import 'models/company_details.dart';

class AppManagerRemoteDataSource {
  AppManagerRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

  Future<List<Organization>> fetchOrganizations({required String accessToken}) {
    return _apiCallExecutor.processApi<List<Organization>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.organizations,
      authToken: accessToken,
      invalidateCacheBeforeRequest: true,
      decoder: (json) {
        if (json is! List) throw const ApiError.invalidResponse();
        return json
            .whereType<Map<String, dynamic>>()
            .map(Organization.fromJson)
            .toList(growable: false);
      },
    );
  }

  Future<User> fetchUserDetail({
    String? accessToken,
    bool allowConflictRetry = true,
  }) {
    return AuthRemoteDataSource(
      apiCallExecutor: _apiCallExecutor,
    ).fetchUserDetail(
      accessToken: accessToken?.trim() ?? '',
      allowConflictRetry: allowConflictRetry,
    );
  }

  Future<CompanyDetails> fetchCompanyDetails({String? accessToken}) {
    return _apiCallExecutor.processApi<CompanyDetails>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.companyDetail,
      authToken: accessToken,
      invalidateCacheBeforeRequest: true,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return CompanyDetails.fromApiJson(json);
      },
    );
  }
}

AppManagerRemoteDataSource createAppManagerRemoteDataSource() {
  return AppManagerRemoteDataSource();
}
