import 'package:http/http.dart' as http;

import '../preference/app_preference.dart';
import 'api_endpoints.dart';

/// Applies organisation context when an app API request is sent.
class ApiHttpClient extends http.BaseClient {
  ApiHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  static const String organizationHeader = 'organization-uuid';
  static final String _apiOrigin = Uri.parse(ApiEndPoints.baseUrl).origin;
  final http.Client _inner;

  static String get organizationUuid {
    final savedId = AppPreference.getSelectedOrganization()?.id.trim();
    if (savedId != null && savedId.isNotEmpty) return savedId;
    return AppPreference.getSelectedOrganizationId()?.trim() ?? '';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin == _apiOrigin &&
        request.url.path.startsWith(ApiEndPoints.version)) {
      final organizationId = organizationUuid;
      request.headers.remove(organizationHeader);
      if (organizationId.isNotEmpty) {
        request.headers[organizationHeader] = organizationId;
      }
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
