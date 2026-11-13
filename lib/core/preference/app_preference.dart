import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../managers/models/company_details.dart';
import '../../features/login/domain/entities/user.dart';

class AppPreference {
  static late SharedPreferences _sharedPrefs;
  static const String _userKey = 'userKey';
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _onboardingTokenKey = 'onboardingToken';
  static const String _onboardingTokenTypeKey = 'onboardingTokenType';
  static const String _activeCompanyKey = 'activeCompany';
  static const String _useParentApiEndpointsKey = 'useParentApiEndpoints';
  static const String _selectedOrganizationIdKey = 'selectedOrganizationId';
  static bool _useParentApiEndpoints = false;
  static String? _selectedOrganizationId;
  static int _sessionVersion = 0;

  /// Changes when credentials are cleared, not when a token pair is refreshed.
  static int get sessionVersion => _sessionVersion;

  static Future<void> init() async {
    _sessionVersion++;
    _sharedPrefs = await SharedPreferences.getInstance();
    _useParentApiEndpoints =
        _sharedPrefs.getBool(_useParentApiEndpointsKey) ?? false;
    _selectedOrganizationId = _sharedPrefs.getString(
      _selectedOrganizationIdKey,
    );
  }

  static String getAuthToken() {
    return _sharedPrefs.getString(_accessTokenKey) ?? '';
  }

  static Future<void> setAuthToken(String at) async {
    await _sharedPrefs.setString(_accessTokenKey, at);
  }

  static Future<void> clearAuthToken() async {
    await _sharedPrefs.remove(_accessTokenKey);
  }

  static String getRefreshToken() {
    return _sharedPrefs.getString(_refreshTokenKey) ?? '';
  }

  static Future<void> setRefreshToken(String at) async {
    await _sharedPrefs.setString(_refreshTokenKey, at);
  }

  static Future<void> clearRefreshToken() async {
    await _sharedPrefs.remove(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    _sessionVersion++;
    await Future.wait<void>([clearAuthToken(), clearRefreshToken()]);
  }

  static String getOnboardingToken() {
    return _sharedPrefs.getString(_onboardingTokenKey) ?? '';
  }

  static Future<void> setOnboardingToken(String token) async {
    await _sharedPrefs.setString(_onboardingTokenKey, token);
  }

  static Future<void> clearOnboardingToken() async {
    await _sharedPrefs.remove(_onboardingTokenKey);
  }

  static String getOnboardingTokenType() {
    return _sharedPrefs.getString(_onboardingTokenTypeKey) ?? '';
  }

  static Future<void> setOnboardingTokenType(String tokenType) async {
    await _sharedPrefs.setString(_onboardingTokenTypeKey, tokenType);
  }

  static Future<void> clearOnboardingTokenType() async {
    await _sharedPrefs.remove(_onboardingTokenTypeKey);
  }

  static Future<void> clearOnboardingSession() async {
    await clearOnboardingToken();
    await clearOnboardingTokenType();
  }

  static Future<void> clearUserSession() async {
    await Future.wait<void>([
      clearTokens(),
      clearActiveCompany(),
      clearUser(),
      clearSelectedOrganizationId(),
      clearUseParentApiEndpoints(),
      clearOnboardingSession(),
    ]);
  }

  static Future<void> saveActiveCompany(CompanyDetails company) async {
    final jsonString = jsonEncode(company.toJson());
    await _sharedPrefs.setString(_activeCompanyKey, jsonString);
  }

  static Future<CompanyDetails?> getActiveCompany() async {
    final jsonString = _sharedPrefs.getString(_activeCompanyKey);
    if (jsonString == null) {
      return null;
    }

    final companyMap = jsonDecode(jsonString);
    if (companyMap is! Map<String, dynamic>) {
      return null;
    }

    return CompanyDetails.fromApiJson(companyMap);
  }

  static Future<void> clearActiveCompany() async {
    await _sharedPrefs.remove(_activeCompanyKey);
  }

  static bool getUseParentApiEndpoints() {
    return _useParentApiEndpoints;
  }

  static Future<void> setUseParentApiEndpoints(bool value) async {
    if (_useParentApiEndpoints == value) {
      return;
    }

    _useParentApiEndpoints = value;
    await _sharedPrefs.setBool(_useParentApiEndpointsKey, value);
  }

  static Future<void> clearUseParentApiEndpoints() async {
    _useParentApiEndpoints = false;
    await _sharedPrefs.remove(_useParentApiEndpointsKey);
  }

  static String? getSelectedOrganizationId() {
    return _selectedOrganizationId;
  }

  static Future<void> setSelectedOrganizationId(String value) async {
    final normalizedValue = value.trim();
    if (_selectedOrganizationId == normalizedValue) {
      return;
    }

    _selectedOrganizationId = normalizedValue;
    await _sharedPrefs.setString(_selectedOrganizationIdKey, normalizedValue);
  }

  static Future<void> clearSelectedOrganizationId() async {
    _selectedOrganizationId = null;
    await _sharedPrefs.remove(_selectedOrganizationIdKey);
  }

  static String getPreferredApiToken({bool includeOnboardingToken = false}) {
    final authToken = getAuthToken().trim();
    if (authToken.isNotEmpty) {
      return authToken;
    }

    if (!includeOnboardingToken) {
      return '';
    }

    return getOnboardingToken().trim();
  }

  static Future<void> saveUser(User user) async {
    // Convert object to Map -> then to JSON String
    String jsonString = jsonEncode(user.toJson());
    await _sharedPrefs.setString(_userKey, jsonString);
  }

  static Future<void> clearUser() async {
    await _sharedPrefs.remove(_userKey);
  }

  // GET USER
  static Future<User?> getUser() async {
    String? jsonString = _sharedPrefs.getString(_userKey);

    if (jsonString == null) return null;

    // Convert JSON String -> back to Map -> back to Entity
    Map<String, dynamic> userMap = jsonDecode(jsonString);
    return User.fromJson(userMap);
  }
}
