import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../../features/login/domain/entities/user.dart';
import '../../features/organizations/domain/entities/organization.dart';
import '../../routes/app_router.dart';
import '../constants/app_strings.dart';
import '../network/api_endpoints.dart';
import '../network/api_error.dart';
import '../network/api_http_client.dart';
import '../network/api_processor.dart';
import '../network/models/organization_conflict_payload.dart';
import '../preference/app_preference.dart';
import '../utils/app_permission_utils.dart';
import 'app_manager_remote_data_source.dart';
import 'models/company_billing_details.dart';
import 'models/company_details.dart';

class AppManager extends ChangeNotifier {
  AppManager._();

  static final AppManager instance = AppManager._();

  bool _isLoadingOrganizations = false;
  bool _isShowingOrganizationsScreen = false;
  bool _isSettingActiveOrganization = false;
  bool _showOrganizationBanner = false;
  String? _activatingOrganizationId;
  CompanyDetails? _activeCompany;
  CompanyBillingDetails? _billingDetails;
  bool _isBillingBannerDismissed = false;
  String? _currentRouteName;
  User? _currentUser;
  String? _selectedOrganizationId;
  Organization? _selectedOrganization;
  Future<List<Organization>>? _organizationsOperation;
  Future<void>? _refreshSessionContextOperation;
  bool _shouldSkipNextResumeSessionRefresh = false;
  bool _isHandlingOrganizationConflict = false;
  bool _didResolveOrganizationConflict = false;
  bool _isRefreshingOrganizationContext = false;
  bool _hasPendingNotification = false;
  List<Organization> _organizations = const <Organization>[];

  bool get isLoadingOrganizations => _isLoadingOrganizations;
  bool get isSettingActiveOrganization => _isSettingActiveOrganization;
  bool get showOrganizationBanner =>
      _showOrganizationBanner && !_isShowingOrganizationsScreen;
  bool get _isInTrial => _billingDetails?.isInTrial == true;
  bool get _canShowBillingBanner =>
      !_isBillingBannerDismissed && _currentRouteName != AppRouter.splash;
  bool get hasRestrictedBillingStatus =>
      _billingDetails?.status != 'paid' && !_isInTrial;
  bool get showBillingBanner =>
      (_activeCompany != null || _billingDetails != null) &&
      hasRestrictedBillingStatus &&
      _canShowBillingBanner;
  bool get showTrialBanner => _isInTrial && _canShowBillingBanner;
  String? get currentRouteName => _currentRouteName;
  String? get activatingOrganizationId => _activatingOrganizationId;
  CompanyBillingDetails? get billingDetails => _billingDetails;
  CompanyDetails? get activeCompany => _activeCompany;
  User? get currentUser => _currentUser;
  bool get isRefreshingOrganizationContext => _isRefreshingOrganizationContext;
  bool get hasPendingOrganizationConflict =>
      _isHandlingOrganizationConflict && !_didResolveOrganizationConflict;
  bool get currentUserHasOwnerOverrideAccess =>
      AppPermissionUtils.hasOwnerOverrideAccess(_currentUser);
  bool get currentUserCanOpenSeatProfileCreateFlow =>
      AppPermissionUtils.canAccessScopedCreateEntry(
        _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanOpenTrainingModuleCreateFlow =>
      AppPermissionUtils.canAccessScopedCreateEntry(
        _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get isCurrentOrganizationChild =>
      AppPermissionUtils.isChildOrganization(currentOrganization);
  bool get canCurrentOrganizationModifyContent =>
      AppPermissionUtils.canModifyCurrentOrganizationContent(
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanEditDepartments =>
      AppPermissionUtils.canEditDepartments(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanManageAnySeatProfileDepartments =>
      AppPermissionUtils.canManageAnySeatProfileDepartments(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanCreateSeatProfiles =>
      AppPermissionUtils.canCreateSeatProfiles(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanManageAnyTrainingModules =>
      AppPermissionUtils.canManageAnyTrainingModules(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );
  bool get currentUserCanAccessAuditTeamMembers =>
      AppPermissionUtils.canAccessAuditTeamMembers(_currentUser);
  bool get currentUserCanManagePaygrades =>
      AppPermissionUtils.canManagePaygrades(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );

  bool get currentUserCanManagePublicLinks =>
      AppPermissionUtils.canManagePublicLinks(
        user: _currentUser,
        currentOrganization: currentOrganization,
      );

  bool canCurrentUserManageSeatProfileDepartment({
    required String departmentId,
  }) {
    return AppPermissionUtils.canManageSeatProfileDepartment(
      user: _currentUser,
      currentOrganization: currentOrganization,
      departmentId: departmentId,
    );
  }

  bool canCurrentUserManageTrainingForSeatProfile({
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    return AppPermissionUtils.canManageTrainingForSeatProfile(
      user: _currentUser,
      currentOrganization: currentOrganization,
      seatProfileId: seatProfileId,
      additionalSeatProfileIds: additionalSeatProfileIds,
    );
  }

  bool canCurrentUserViewTrainingQuizAndAssignment({
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    return AppPermissionUtils.canViewTrainingQuizAndAssignment(
      user: _currentUser,
      currentOrganization: currentOrganization,
      seatProfileId: seatProfileId,
      additionalSeatProfileIds: additionalSeatProfileIds,
    );
  }

  bool isCurrentUserAssignedToTrainingSeatProfile({
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    return AppPermissionUtils.isAssignedToTrainingSeatProfile(
      user: _currentUser,
      seatProfileId: seatProfileId,
      additionalSeatProfileIds: additionalSeatProfileIds,
    );
  }

  bool get usesParentApiEndpoints {
    final selectedOrganization = _selectedOrganization;
    if (selectedOrganization != null) {
      return _isSandboxOrganization(selectedOrganization);
    }
    final selectedOrganizationId = _selectedOrganizationId;
    if (selectedOrganizationId != null) {
      if (selectedOrganizationId.isEmpty) {
        return true;
      }

      final selectedOrganization = _findOrganizationById(
        selectedOrganizationId,
      );
      if (selectedOrganization != null) {
        return _isSandboxOrganization(selectedOrganization);
      }

      return false;
    }

    final resolvedOrganization = currentOrganization;
    if (resolvedOrganization != null &&
        _isSandboxOrganization(resolvedOrganization)) {
      return true;
    }

    final activeCompanyName = _activeCompany?.name.trim().toLowerCase() ?? '';
    return activeCompanyName.contains('sandbox');
  }

  Organization? get currentOrganization {
    if (_selectedOrganization != null) return _selectedOrganization;
    final selectedOrganizationId = _selectedOrganizationId;
    if (selectedOrganizationId != null) {
      final selectedOrganization = _findOrganizationForSelection(
        selectedOrganizationId,
      );
      if (selectedOrganization != null) {
        return selectedOrganization;
      }
    }

    final userOrganizationId = _resolveUserBackedOrganizationSelectionId();
    if (userOrganizationId != null) {
      final userOrganization = _findOrganizationForSelection(
        userOrganizationId,
      );
      if (userOrganization != null) {
        return userOrganization;
      }
    }

    return _findOrganizationById(_activeCompany?.uuid);
  }

  String get currentOrganizationId {
    final resolvedOrganization = currentOrganization;
    if (resolvedOrganization != null) {
      return resolvedOrganization.id;
    }

    final selectedOrganizationId = _selectedOrganizationId;
    if (selectedOrganizationId != null) {
      return selectedOrganizationId;
    }

    final userOrganizationId = _resolveUserBackedOrganizationSelectionId();
    if (userOrganizationId != null) {
      return userOrganizationId;
    }

    return _activeCompany?.uuid.trim() ?? '';
  }

  List<Organization> get organizations =>
      List<Organization>.unmodifiable(_organizations);
  String get currentOrganizationName {
    final resolvedOrganization = currentOrganization;
    if (resolvedOrganization != null) {
      final organizationName = resolvedOrganization.name.trim();
      if (organizationName.isNotEmpty) {
        return organizationName;
      }
    }

    final activeCompanyName = _activeCompany?.name.trim() ?? '';
    if (activeCompanyName.isNotEmpty) {
      return activeCompanyName;
    }

    return '';
  }

  Future<void> initialize({
    bool forceRefresh = false,
    bool requireSuccess = false,
    AppManagerRemoteDataSource? remoteDataSource,
    String? accessToken,
  }) async {
    final token = (accessToken ?? AppPreference.getAuthToken()).trim();
    if (token.isEmpty) return;
    await fetchOrganizations(
      forceRefresh: forceRefresh,
      requireSuccess: requireSuccess,
      selectFirstOrganization: true,
      remoteDataSource: remoteDataSource,
      accessToken: token,
    );
  }

  Future<void> refreshSessionContext({
    bool forceOrganizationsRefresh = true,
  }) async {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return;
    }

    final existingOperation = _refreshSessionContextOperation;
    if (existingOperation != null) {
      await existingOperation;
      return;
    }

    final operation = _refreshSessionContextInternal(
      sessionVersion: AppPreference.sessionVersion,
      forceOrganizationsRefresh: forceOrganizationsRefresh,
    );
    _isRefreshingOrganizationContext = true;
    _notifyListenersSafely();
    _refreshSessionContextOperation = operation;

    try {
      await operation;
    } finally {
      if (identical(_refreshSessionContextOperation, operation)) {
        _refreshSessionContextOperation = null;
        _isRefreshingOrganizationContext = false;
        _notifyListenersSafely();
      }
    }
  }

  Future<void> hydrateCurrentUser() async {
    _currentUser = await AppPreference.getUser();
    _activeCompany = await AppPreference.getActiveCompany();
    _updateBillingDetails(_activeCompany?.billing);
    _selectedOrganization = AppPreference.getSelectedOrganization();
    if (_selectedOrganization != null) {
      _organizations = [_selectedOrganization!];
    }
    _selectedOrganizationId =
        AppPreference.getSelectedOrganizationId() ??
        _resolveSelectionIdForUser(_currentUser);
    _syncParentApiEndpointMode();
    _notifyListenersSafely();
  }

  void skipNextResumeSessionRefresh() {
    _shouldSkipNextResumeSessionRefresh = true;
  }

  bool consumeResumeSessionRefreshSkip() {
    if (!_shouldSkipNextResumeSessionRefresh) {
      return false;
    }

    _shouldSkipNextResumeSessionRefresh = false;
    return true;
  }

  void updateCurrentUser(User? user) {
    _currentUser = user;
    _syncSelectedOrganizationWithUser(user);
    _syncParentApiEndpointMode();
    _notifyListenersSafely();
  }

  void saveBillingDetails(CompanyBillingDetails? billingDetails) {
    _updateBillingDetails(billingDetails);
    _notifyListenersSafely();
  }

  void saveActiveCompany(CompanyDetails? activeCompany) {
    final previousCompanyId = _activeCompany?.uuid.trim() ?? '';
    final nextCompanyId = activeCompany?.uuid.trim() ?? '';

    _activeCompany = activeCompany;
    if (previousCompanyId != nextCompanyId) {
      _isBillingBannerDismissed = false;
    }
    _updateBillingDetails(activeCompany?.billing);

    _syncParentApiEndpointMode();
    _notifyListenersSafely();
  }

  void _updateBillingDetails(CompanyBillingDetails? billingDetails) {
    final wasInTrial = _isInTrial;
    _billingDetails = billingDetails;
    if (wasInTrial != _isInTrial ||
        (!_isInTrial && !hasRestrictedBillingStatus)) {
      _isBillingBannerDismissed = false;
    }
  }

  void dismissBillingBanner() {
    if (_isBillingBannerDismissed) {
      return;
    }

    _isBillingBannerDismissed = true;
    _notifyListenersSafely();
  }

  void resetBillingBannerDismissal() {
    if (!_isBillingBannerDismissed) {
      return;
    }

    _isBillingBannerDismissed = false;
    _notifyListenersSafely();
  }

  void updateCurrentRouteName(String? routeName) {
    if (_currentRouteName == routeName) {
      return;
    }

    _currentRouteName = routeName;
    _notifyListenersSafely();
  }

  void resetSessionState() {
    _organizationsOperation = null;
    _isLoadingOrganizations = false;
    _refreshSessionContextOperation = null;
    _shouldSkipNextResumeSessionRefresh = false;
    _isHandlingOrganizationConflict = false;
    _didResolveOrganizationConflict = false;
    _isRefreshingOrganizationContext = false;
    _showOrganizationBanner = false;
    _isShowingOrganizationsScreen = false;
    _isSettingActiveOrganization = false;
    _activatingOrganizationId = null;
    _activeCompany = null;
    _billingDetails = null;
    _isBillingBannerDismissed = false;
    _currentUser = null;
    _selectedOrganizationId = null;
    _selectedOrganization = null;
    _organizations = const <Organization>[];
    _syncParentApiEndpointMode();
    _notifyListenersSafely();
  }

  Future<void> fetchOrganizations({
    bool forceRefresh = false,
    bool requireSuccess = false,
    bool selectFirstOrganization = false,
    AppManagerRemoteDataSource? remoteDataSource,
    String? accessToken,
  }) async {
    final sessionVersion = AppPreference.sessionVersion;
    final token = (accessToken ?? AppPreference.getAuthToken()).trim();
    final operation =
        _organizationsOperation ??
        (remoteDataSource ?? AppManagerRemoteDataSource()).fetchOrganizations(
          accessToken: token,
        );
    _organizationsOperation = operation;
    _isLoadingOrganizations = true;
    _notifyListenersSafely();

    try {
      final organizations = await operation;
      if (sessionVersion != AppPreference.sessionVersion) {
        if (requireSuccess) throw ApiError.requestFailed(401);
        return;
      }
      _organizations = organizations;
      await _reconcileSelectedOrganization(
        selectFirst: selectFirstOrganization,
      );
      _syncParentApiEndpointMode();
    } catch (_) {
      if (requireSuccess) {
        rethrow;
      }
      // Keep startup resilient if organizations cannot be fetched.
    } finally {
      if (identical(_organizationsOperation, operation)) {
        _organizationsOperation = null;
        _isLoadingOrganizations = false;
        _notifyListenersSafely();
      }
    }
  }

  Future<void> handleConflict409() async {
    _isHandlingOrganizationConflict = false;
    _didResolveOrganizationConflict = false;
    _showOrganizationBanner = false;
    _isShowingOrganizationsScreen = false;
    await fetchOrganizations(forceRefresh: true);
    _showOrganizationConflictChangedSnackBar();
    _notifyListenersSafely();
  }

  Future<bool> resolveConflictWithServerActiveOrganization(
    OrganizationConflictPayload conflictPayload,
  ) async {
    final organizationId = conflictPayload.organizationId.trim();
    final organizationType = _normalizeOrganizationType(
      conflictPayload.organizationType,
    );
    if (organizationId.isEmpty || organizationType.isEmpty) {
      return false;
    }

    _isHandlingOrganizationConflict = false;
    _showOrganizationBanner = false;
    _isShowingOrganizationsScreen = false;
    _showOrganizationConflictChangedSnackBar();
    _notifyListenersSafely();

    final didSetOrganization = await _setActiveOrganizationInternal(
      organizationId: organizationId,
      organizationType: organizationType,
    );
    if (!didSetOrganization) {
      return false;
    }

    await fetchOrganizations(forceRefresh: true);
    _notifyListenersSafely();
    return true;
  }

  Future<void> openOrganizationsScreen({bool openedForConflict = false}) async {
    if (openedForConflict) {
      _isHandlingOrganizationConflict = true;
      _didResolveOrganizationConflict = false;
      _showOrganizationBanner = false;
    }

    if (_isShowingOrganizationsScreen) {
      return;
    }

    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _isShowingOrganizationsScreen = true;
    _notifyListenersSafely();

    await navigator.pushNamed(AppRouter.organizations);

    _isShowingOrganizationsScreen = false;
    _notifyListenersSafely();
  }

  Future<void> resolveOrganizationConflictFromBack() async {
    final shouldRefreshContext = hasPendingOrganizationConflict;
    _showOrganizationBanner = false;
    _isHandlingOrganizationConflict = false;
    _didResolveOrganizationConflict = false;
    _notifyListenersSafely();

    if (!shouldRefreshContext) {
      return;
    }

    await _refreshCurrentOrganizationContext();
    await fetchOrganizations(forceRefresh: true);
  }

  Future<bool> setActiveOrganization(
    String organizationId, {
    bool resetNavigationStack = true,
  }) async {
    if (_isSettingActiveOrganization) {
      return false;
    }

    _isSettingActiveOrganization = true;
    _activatingOrganizationId = organizationId;
    _notifyListenersSafely();

    try {
      final selectedOrganization = _findOrganizationById(organizationId);
      final organizationType = _resolveOrganizationType(
        organization: selectedOrganization,
      );
      final didSetOrganization = await _setActiveOrganizationInternal(
        organizationId: organizationId,
        organizationType: organizationType,
      );
      if (!didSetOrganization) {
        return false;
      }
      final navigator = AppRouter.navigatorKey.currentState;
      if (resetNavigationStack && navigator != null) {
        navigator.pushNamedAndRemoveUntil(
          AppRouter.defaultAuthenticatedRouteName,
          (route) => false,
        );
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      _isSettingActiveOrganization = false;
      _activatingOrganizationId = null;
      _notifyListenersSafely();
    }
  }

  Future<void> _syncCurrentOrganization(
    String organizationId, {
    String? organizationType,
  }) async {
    final normalizedOrganizationId = organizationId.trim();
    if (normalizedOrganizationId.isEmpty) {
      return;
    }
    final didChangeOrganization =
        normalizedOrganizationId != ApiHttpClient.organizationUuid;

    final normalizedOrganizationType = _normalizeOrganizationType(
      organizationType,
    );
    final matchedOrganization = _findOrganizationById(normalizedOrganizationId);
    final persistedOrganizationId = normalizedOrganizationType.isNotEmpty
        ? (_isSandboxOrganizationType(normalizedOrganizationType)
              ? ''
              : normalizedOrganizationId)
        : matchedOrganization != null &&
              _isSandboxOrganization(matchedOrganization)
        ? ''
        : normalizedOrganizationId;
    _selectedOrganization = matchedOrganization;
    _selectedOrganizationId = persistedOrganizationId;
    await Future.wait([
      _clearActiveCompanyForOrganizationChange(normalizedOrganizationId),
      AppPreference.setSelectedOrganizationId(persistedOrganizationId),
      if (matchedOrganization != null)
        AppPreference.saveSelectedOrganization(matchedOrganization)
      else
        AppPreference.clearSelectedOrganization(),
    ]);

    final currentUser = _currentUser;
    if (currentUser == null) {
      _syncParentApiEndpointMode();
      return;
    }

    if (!didChangeOrganization &&
        currentUser.organizationUuid?.trim() == persistedOrganizationId) {
      _syncParentApiEndpointMode();
      return;
    }

    final updatedUser = currentUser.copyWith(
      organizationUuid: persistedOrganizationId,
      hierarchyMemberships: didChangeOrganization ? const [] : null,
    );
    _currentUser = updatedUser;
    await AppPreference.saveUser(updatedUser);
    _syncParentApiEndpointMode();
  }

  Future<void> _refreshActiveCompany() async {
    await _refreshActiveCompanyForToken();
  }

  Future<void> _refreshUserAfterOrganizationSwitch() async {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty || _currentUser == null) return;

    final sessionVersion = AppPreference.sessionVersion;
    final organizationId = ApiHttpClient.organizationUuid;
    bool isCurrentOrganizationSession() =>
        sessionVersion == AppPreference.sessionVersion &&
        organizationId == ApiHttpClient.organizationUuid;

    try {
      final user = await AppManagerRemoteDataSource().fetchUserDetail(
        accessToken: authToken,
        allowConflictRetry: false,
      );
      if (!isCurrentOrganizationSession()) return;
      await AppPreference.saveUser(user);
      if (isCurrentOrganizationSession()) updateCurrentUser(user);
    } catch (_) {
      // The switch has succeeded even if its profile cannot be refreshed yet.
    }
  }

  void _showOrganizationConflictChangedSnackBar() {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(AppStrings.organizationConflictChangedMessage),
        ),
      );
  }

  Future<void> _refreshCurrentOrganizationContext() async {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return;
    }

    try {
      ApiCallExecutor.clearGetCache();
      final remoteDataSource = AppManagerRemoteDataSource();
      final refreshedUser = await remoteDataSource.fetchUserDetail(
        accessToken: authToken,
      );
      await AppPreference.saveUser(refreshedUser);
      updateCurrentUser(refreshedUser);
      await _refreshActiveCompanyForToken(authToken: authToken);
    } catch (_) {
      // Keep organization conflict recovery resilient if the server cannot refresh context.
    }
  }

  Future<void> _refreshSessionContextInternal({
    required int sessionVersion,
    required bool forceOrganizationsRefresh,
  }) async {
    try {
      ApiCallExecutor.clearGetCache();
      await fetchOrganizations(
        forceRefresh: forceOrganizationsRefresh,
        requireSuccess: true,
        selectFirstOrganization: true,
      );
      if (sessionVersion != AppPreference.sessionVersion) return;
      final remoteDataSource = AppManagerRemoteDataSource();
      final refreshedUser = await remoteDataSource.fetchUserDetail(
        accessToken: AppPreference.getAuthToken(),
      );
      if (sessionVersion != AppPreference.sessionVersion) return;
      await AppPreference.saveUser(refreshedUser);
      updateCurrentUser(refreshedUser);
      await _refreshActiveCompanyForToken(
        authToken: AppPreference.getAuthToken(),
        sessionVersion: sessionVersion,
      );
    } catch (_) {
      // Keep foreground resume resilient if session context cannot refresh.
    }
  }

  Future<void> _refreshActiveCompanyForToken({
    String? authToken,
    int? sessionVersion,
  }) async {
    final expectedSessionVersion =
        sessionVersion ?? AppPreference.sessionVersion;
    final resolvedAuthToken =
        authToken?.trim() ?? AppPreference.getAuthToken().trim();
    if (resolvedAuthToken.isEmpty) {
      return;
    }
    final organizationId = ApiHttpClient.organizationUuid;

    try {
      final companyDetails = await AppManagerRemoteDataSource()
          .fetchCompanyDetails(accessToken: resolvedAuthToken);
      if (expectedSessionVersion != AppPreference.sessionVersion ||
          organizationId != ApiHttpClient.organizationUuid) {
        return;
      }
      await AppPreference.saveActiveCompany(companyDetails);
      if (expectedSessionVersion != AppPreference.sessionVersion ||
          organizationId != ApiHttpClient.organizationUuid) {
        return;
      }
      saveActiveCompany(companyDetails);
    } catch (_) {
      // Keep organization switches resilient if company details cannot refresh.
    }
  }

  void _notifyListenersSafely() {
    if (_hasPendingNotification) {
      return;
    }

    _hasPendingNotification = true;
    void dispatchNotification() {
      _hasPendingNotification = false;
      notifyListeners();
    }

    final scheduler = SchedulerBinding.instance;
    final phase = scheduler.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      scheduleMicrotask(dispatchNotification);
      return;
    }

    scheduler.addPostFrameCallback((_) {
      dispatchNotification();
    });
  }

  Organization? _findOrganizationById(String? organizationId) {
    final normalizedOrganizationId = organizationId?.trim() ?? '';
    if (normalizedOrganizationId.isEmpty) {
      return null;
    }

    for (final organization in _organizations) {
      if (organization.id == normalizedOrganizationId) {
        return organization;
      }
    }

    return null;
  }

  Organization? _findOrganizationForSelection(String organizationId) {
    if (organizationId.isEmpty) {
      return _findSandboxOrganization();
    }

    return _findOrganizationById(organizationId);
  }

  Organization? _findSandboxOrganization() {
    for (final organization in _organizations) {
      if (_isSandboxOrganization(organization)) {
        return organization;
      }
    }

    return null;
  }

  bool _isSandboxOrganization(Organization organization) {
    final organizationType = organization.type.trim().toLowerCase();
    if (organizationType == 'sandbox') {
      return true;
    }

    return organization.name.trim().toLowerCase().contains('sandbox');
  }

  Map<String, String> _buildSetActiveOrganizationPayload({
    required String organizationId,
    required Organization? organization,
    String? organizationType,
  }) {
    final normalizedOrganizationId = organizationId.trim();
    final normalizedOrganizationType = _normalizeOrganizationType(
      organizationType,
    );
    final resolvedType = normalizedOrganizationType.isNotEmpty
        ? normalizedOrganizationType
        : _resolveOrganizationType(organization: organization);

    return <String, String>{
      'type': resolvedType,
      'uuid': normalizedOrganizationId,
    };
  }

  Future<bool> _setActiveOrganizationInternal({
    required String organizationId,
    required String organizationType,
  }) async {
    final token = AppPreference.getAuthToken();
    final uri = ApiEndPoints.resolveUri(ApiEndPoints.setActiveOrganization);
    final selectedOrganization = _findOrganizationById(organizationId);
    final payload = _buildSetActiveOrganizationPayload(
      organizationId: organizationId,
      organization: selectedOrganization,
      organizationType: organizationType,
    );

    final client = ApiHttpClient();
    late final http.Response response;
    try {
      response = await client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      return false;
    }

    ApiCallExecutor.clearGetCache();
    await _syncCurrentOrganization(
      organizationId,
      organizationType: organizationType,
    );
    await _refreshActiveCompany();
    await _refreshUserAfterOrganizationSwitch();
    _didResolveOrganizationConflict = true;
    _isHandlingOrganizationConflict = false;
    _showOrganizationBanner = false;
    _isShowingOrganizationsScreen = false;
    return true;
  }

  String _resolveOrganizationType({required Organization? organization}) {
    if (organization != null && _isSandboxOrganization(organization)) {
      return 'sandbox';
    }

    return 'organization';
  }

  String _normalizeOrganizationType(String? organizationType) {
    return organizationType?.trim().toLowerCase() ?? '';
  }

  bool _isSandboxOrganizationType(String organizationType) {
    return _normalizeOrganizationType(organizationType) == 'sandbox';
  }

  String? _resolveSelectionIdForUser(User? user) {
    if (user == null) {
      return null;
    }

    final organizationId = user.organizationUuid?.trim() ?? '';
    if (organizationId.isNotEmpty) {
      return organizationId;
    }

    return _findSandboxOrganization() != null ? '' : null;
  }

  String? _resolveUserBackedOrganizationSelectionId() {
    return _resolveSelectionIdForUser(_currentUser);
  }

  void _syncSelectedOrganizationWithUser(User? user) {
    if (user == null) {
      if (_selectedOrganizationId == null && _selectedOrganization == null) {
        return;
      }

      _selectedOrganizationId = null;
      _selectedOrganization = null;
      unawaited(AppPreference.clearSelectedOrganizationId());
      return;
    }

    // The organisations response owns the active context once it is available.
    if (_selectedOrganization != null) return;

    final nextSelectedOrganizationId = _resolveSelectionIdForUser(user);
    if (_selectedOrganizationId == nextSelectedOrganizationId) {
      return;
    }

    _selectedOrganizationId = nextSelectedOrganizationId;
    if (nextSelectedOrganizationId == null) {
      unawaited(AppPreference.clearSelectedOrganizationId());
      return;
    }

    unawaited(
      AppPreference.setSelectedOrganizationId(nextSelectedOrganizationId),
    );
  }

  Future<void> _persistSelectedOrganization(Organization organization) async {
    _selectedOrganization = organization;
    _selectedOrganizationId = _isSandboxOrganization(organization)
        ? ''
        : organization.id;
    await Future.wait([
      _clearActiveCompanyForOrganizationChange(organization.id),
      AppPreference.setSelectedOrganizationId(_selectedOrganizationId!),
      AppPreference.saveSelectedOrganization(organization),
    ]);
  }

  Future<void> _clearActiveCompanyForOrganizationChange(
    String organizationId,
  ) async {
    if (organizationId == ApiHttpClient.organizationUuid) return;
    if (_activeCompany != null || _billingDetails != null) {
      saveActiveCompany(null);
    }
    await AppPreference.clearActiveCompany();
  }

  Future<void> _reconcileSelectedOrganization({
    bool selectFirst = false,
  }) async {
    if (selectFirst) {
      if (_organizations.isNotEmpty) {
        await _persistSelectedOrganization(_organizations.first);
      } else {
        _selectedOrganization = null;
        _selectedOrganizationId = null;
        await Future.wait([
          _clearActiveCompanyForOrganizationChange(''),
          AppPreference.clearSelectedOrganizationId(),
        ]);
      }
      return;
    }
    final selectedOrganizationId = _selectedOrganizationId;
    final selectedOrganization = selectedOrganizationId == null
        ? null
        : _findOrganizationForSelection(selectedOrganizationId);
    if (selectedOrganization != null) {
      await _persistSelectedOrganization(selectedOrganization);
      return;
    }

    final fallbackOrganizationId = _resolveUserBackedOrganizationSelectionId();
    if (fallbackOrganizationId != null &&
        _findOrganizationForSelection(fallbackOrganizationId) != null) {
      if (fallbackOrganizationId == selectedOrganizationId) {
        return;
      }

      await _persistSelectedOrganization(
        _findOrganizationForSelection(fallbackOrganizationId)!,
      );
      return;
    }

    if (_selectedOrganizationId == null) {
      return;
    }

    _selectedOrganizationId = null;
    _selectedOrganization = null;
    await Future.wait([
      _clearActiveCompanyForOrganizationChange(''),
      AppPreference.clearSelectedOrganizationId(),
    ]);
  }

  void _syncParentApiEndpointMode() {
    unawaited(AppPreference.setUseParentApiEndpoints(usesParentApiEndpoints));
  }
}
