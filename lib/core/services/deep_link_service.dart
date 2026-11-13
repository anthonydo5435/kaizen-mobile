import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';

import '../../routes/app_router.dart';
import '../managers/app_manager.dart';
import '../managers/app_manager_remote_data_source.dart';
import '../navigation/browser_app_link.dart';
import '../preference/app_preference.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final AppManagerRemoteDataSource _appManagerRemoteDataSource =
      AppManagerRemoteDataSource();
  StreamSubscription<Uri>? _subscription;
  bool _isInitialized = false;
  String? _activeNavigationTargetKey;
  Timer? _activeNavigationTimer;
  DeepLinkTarget? _pendingStartupTarget;
  DeepLinkTarget? _pendingAuthenticatedTarget;
  Completer<DeepLinkTarget?>? _startupTargetCompleter;
  bool _isStartupPhaseActive = true;
  static const Duration _activeNavigationWindow = Duration(milliseconds: 900);
  static const Duration _navigationRetryDelay = Duration(milliseconds: 350);

  Future<void> initialize() async {
    _prepareStartupCycle();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        final target = await _resolveTarget(initialUri);
        if (target != null) {
          if (target.requiresAuthentication && !_hasAuthenticatedSession()) {
            _pendingAuthenticatedTarget = target;
            _completeStartupTarget(null);
          } else {
            _pendingStartupTarget = target;
            _completeStartupTarget(target);
          }
        }
      }
    } catch (_) {
      // Keep app startup resilient if a malformed link is received.
    }

    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {
        // Ignore invalid deep links without interrupting app usage.
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _activeNavigationTimer?.cancel();
    _subscription = null;
    _isInitialized = false;
    _activeNavigationTargetKey = null;
    _isStartupPhaseActive = true;
    _startupTargetCompleter = null;
  }

  void _prepareStartupCycle() {
    _pendingStartupTarget = null;
    _isStartupPhaseActive = true;
    _startupTargetCompleter = Completer<DeepLinkTarget?>();
  }

  Future<DeepLinkTarget?> consumeStartupTarget({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    if (!_isStartupPhaseActive) {
      return null;
    }

    if (_pendingStartupTarget != null) {
      _isStartupPhaseActive = false;
      return takePendingStartupTarget(markAsNavigating: true);
    }

    _startupTargetCompleter ??= Completer<DeepLinkTarget?>();

    try {
      await _startupTargetCompleter!.future.timeout(timeout);
    } catch (_) {
      // Treat timeout the same as "no startup deep link".
    }

    _isStartupPhaseActive = false;
    return takePendingStartupTarget(markAsNavigating: true);
  }

  DeepLinkTarget? takePendingStartupTarget({bool markAsNavigating = false}) {
    final target = _pendingStartupTarget;
    _pendingStartupTarget = null;
    if (markAsNavigating && target != null) {
      _markNavigationStarted(target);
    }
    return target;
  }

  DeepLinkTarget? takePendingAuthenticatedTarget({
    bool markAsNavigating = false,
  }) {
    final target = _pendingAuthenticatedTarget;
    _pendingAuthenticatedTarget = null;
    if (markAsNavigating && target != null) {
      _markNavigationStarted(target);
    }
    return target;
  }

  bool get hasPendingAuthenticatedTarget => _pendingAuthenticatedTarget != null;

  Future<DeepLinkTarget?> takePendingAuthenticatedTargetReady({
    bool markAsNavigating = false,
  }) async {
    final target = _pendingAuthenticatedTarget;
    if (target == null) {
      return null;
    }

    final preparedTarget = await _prepareAuthenticatedTarget(target);
    if (preparedTarget == null) {
      return null;
    }

    _pendingAuthenticatedTarget = null;
    if (markAsNavigating) {
      _markNavigationStarted(preparedTarget);
    }
    return preparedTarget;
  }

  Future<void> _handleUri(Uri uri) async {
    final target = await _resolveTarget(uri);
    if (target == null) {
      return;
    }

    if (target.requiresAuthentication && !_hasAuthenticatedSession()) {
      _pendingAuthenticatedTarget = target;
      if (_isStartupPhaseActive) {
        _completeStartupTarget(null);
        return;
      }

      _navigateToLoginForAuthentication();
      return;
    }

    if (_isStartupPhaseActive) {
      _pendingStartupTarget = target;
      _completeStartupTarget(target);
      return;
    }

    _navigateWhenReady(target);
  }

  Future<DeepLinkTarget?> _resolveTarget(Uri incomingUri) async {
    final uri = resolveBrowserAppLink(incomingUri);
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https' || scheme == 'http') {
      return _resolveUniversalLink(uri);
    }

    if (scheme != 'kaizenteams') {
      return null;
    }

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.toLowerCase())
        .toList();

    if (host == 'onboarding') {
      if (segments.contains('password') ||
          uri.queryParameters['step']?.toLowerCase() == 'password') {
        return DeepLinkTarget.password(uri.queryParameters['image']);
      }
      return const DeepLinkTarget.profile();
    }

    if (host == 'setting' || host == 'settings') {
      return const DeepLinkTarget.profile();
    }

    if (segments.isNotEmpty && segments.first == 'onboarding') {
      if (segments.length > 1 && segments[1] == 'password') {
        return DeepLinkTarget.password(uri.queryParameters['image']);
      }
      return const DeepLinkTarget.profile();
    }

    if (segments.isNotEmpty &&
        (segments.first == 'setting' || segments.first == 'settings')) {
      return const DeepLinkTarget.profile();
    }

    return null;
  }

  Future<DeepLinkTarget?> _resolveUniversalLink(Uri uri) async {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    final normalizedPath = uri.path.trim().toLowerCase();

    const supportedHosts = <String>{
      'app.kaizenteams.ai',
      'dev.kaizenteams.ai',
      'api.kaizenteams.ai',
    };
    if (!supportedHosts.contains(host)) {
      return null;
    }

    final sharedLmsTarget = _resolveSharedLmsTarget(segments);
    if (sharedLmsTarget != null) {
      return sharedLmsTarget;
    }

    final sharedPaygradesTarget = _resolveSharedPaygradesTarget(segments);
    if (sharedPaygradesTarget != null) {
      return sharedPaygradesTarget;
    }

    final sharedSeatProfileTarget = _resolveSharedSeatProfileTarget(segments);
    if (sharedSeatProfileTarget != null) {
      return sharedSeatProfileTarget;
    }

    // Google callbacks belong to the active sign-in attempt on either host.
    if (normalizedPath == '/auth/google/callback') {
      return null;
    }

    if (normalizedPath.contains('/organization')) {
      final redirectTarget = await _resolveOrganizationDeepLinkTarget(uri);
      if (redirectTarget != null) {
        return redirectTarget;
      }
    }

    if (segments.length < 2) {
      return null;
    }

    final normalizedSegments = segments
        .map((segment) => segment.trim().toLowerCase())
        .toList(growable: false);

    final passwordResetTarget = _resolvePasswordResetTarget(uri);
    if (passwordResetTarget != null) {
      return passwordResetTarget;
    }

    if (normalizedSegments.length >= 3 &&
        normalizedSegments[0] == 'ltc' &&
        normalizedSegments[1] == 'assigned-track') {
      final trackAssignmentUuid = segments[2].trim();
      if (trackAssignmentUuid.isEmpty) {
        return null;
      }

      return DeepLinkTarget.complianceTracks(trackAssignmentUuid);
    }

    if (normalizedSegments.first != 'verify_token') {
      return null;
    }

    final rawToken = segments[1].trim();
    if (rawToken.isEmpty) {
      return null;
    }

    final payload = _decodeJwtPayload(rawToken);
    final tokenType = payload?['token_type']?.toString().trim().toLowerCase();

    await AppPreference.clearTokens();
    await AppPreference.clearActiveCompany();
    await AppPreference.clearUser();
    await AppPreference.clearSelectedOrganizationId();
    AppManager.instance.updateCurrentUser(null);
    await AppPreference.setOnboardingToken(rawToken);
    if (tokenType != null && tokenType.isNotEmpty) {
      await AppPreference.setOnboardingTokenType(tokenType);
    } else {
      await AppPreference.clearOnboardingTokenType();
    }

    return const DeepLinkTarget.profile(clearStack: true);
  }

  DeepLinkTarget? _resolveSharedLmsTarget(List<String> segments) {
    if (segments.length != 3 ||
        segments[0].toLowerCase() != 'shared' ||
        segments[1].toLowerCase() != 'lms') {
      return null;
    }

    final publicId = segments[2].trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(publicId)) {
      return null;
    }

    return DeepLinkTarget.sharedLms(publicId);
  }

  DeepLinkTarget? _resolveSharedPaygradesTarget(List<String> segments) {
    if (segments.length != 3 ||
        segments[0].toLowerCase() != 'shared' ||
        segments[1].toLowerCase() != 'paygrades') {
      return null;
    }

    final publicId = segments[2].trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(publicId)) {
      return null;
    }

    return DeepLinkTarget.sharedPaygrades(publicId);
  }

  DeepLinkTarget? _resolveSharedSeatProfileTarget(List<String> segments) {
    if (segments.length != 3 ||
        segments[0].toLowerCase() != 'shared' ||
        segments[1].toLowerCase() != 'seat-profile') {
      return null;
    }

    final publicId = segments[2].trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(publicId)) {
      return null;
    }

    return DeepLinkTarget.sharedSeatProfile(publicId);
  }

  DeepLinkTarget? _resolvePasswordResetTarget(Uri uri) {
    final rawLink = uri.toString().trim();
    if (rawLink.isEmpty) {
      return null;
    }

    const passwordResetMarkers = <String>[
      '/auth/password-reset/confirm',
      '/auth/password-reset',
    ];
    final normalizedRawLink = rawLink.toLowerCase();

    var hasMatchedPasswordResetMarker = false;
    for (final marker in passwordResetMarkers) {
      final markerIndex = normalizedRawLink.indexOf(marker);
      if (markerIndex == -1) {
        continue;
      }

      final markerEndIndex = markerIndex + marker.length;
      if (markerEndIndex < normalizedRawLink.length) {
        final nextCharacter = normalizedRawLink[markerEndIndex];
        if (nextCharacter != '/' && nextCharacter != '?') {
          continue;
        }
      }

      hasMatchedPasswordResetMarker = true;
      break;
    }

    if (!hasMatchedPasswordResetMarker) {
      return null;
    }

    final token = uri.queryParameters['token']?.trim() ?? '';
    if (token.isEmpty) {
      return null;
    }

    return DeepLinkTarget.passwordResetConfirm(token: token);
  }

  Future<DeepLinkTarget?> _resolveOrganizationDeepLinkTarget(Uri uri) async {
    final rawLink = uri.toString().trim();
    if (rawLink.isEmpty) {
      return null;
    }

    const assignedTrackMarker = '/ltc/assigned-track/';
    final normalizedRawLink = rawLink.toLowerCase();
    final markerIndex = normalizedRawLink.indexOf(assignedTrackMarker);
    if (markerIndex == -1) {
      return null;
    }

    final trackStartIndex = markerIndex + assignedTrackMarker.length;
    final remainingLink = rawLink.substring(trackStartIndex);
    if (remainingLink.isEmpty) {
      return null;
    }

    final trackAssignmentUuid = remainingLink.split('/').first.trim();
    if (trackAssignmentUuid.isEmpty) {
      return null;
    }

    final organizationId = _extractOrganizationId(uri);
    final target = DeepLinkTarget.complianceTracks(
      trackAssignmentUuid,
      organizationId: organizationId,
    );

    if (!_hasAuthenticatedSession()) {
      return target;
    }

    final preparedTarget = await _prepareAuthenticatedTarget(target);
    if (preparedTarget == null) {
      return null;
    }

    return preparedTarget;
  }

  String? _extractOrganizationId(Uri uri) {
    final queryOrganizationId =
        uri.queryParameters['organization_uuid']?.trim() ??
        uri.queryParameters['organization_id']?.trim() ??
        uri.queryParameters['company_uuid']?.trim() ??
        uri.queryParameters['company_id']?.trim();
    if (queryOrganizationId != null && queryOrganizationId.isNotEmpty) {
      return queryOrganizationId;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);

    for (var index = 0; index < segments.length - 1; index++) {
      final segment = segments[index].trim().toLowerCase();
      if (segment == 'organization' || segment == 'organizations') {
        final organizationId = segments[index + 1].trim();
        if (organizationId.isNotEmpty) {
          return organizationId;
        }
      }
    }

    return null;
  }

  Future<void> _refreshSavedActiveCompany() async {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return;
    }

    try {
      final companyDetails = await _appManagerRemoteDataSource
          .fetchCompanyDetails(accessToken: authToken);
      await AppPreference.saveActiveCompany(companyDetails);
      AppManager.instance.saveActiveCompany(companyDetails);
    } catch (_) {
      // Keep deep link processing resilient if company details cannot refresh.
    }
  }

  bool _hasAuthenticatedSession() {
    return AppPreference.getAuthToken().trim().isNotEmpty;
  }

  Future<DeepLinkTarget?> _prepareAuthenticatedTarget(
    DeepLinkTarget target,
  ) async {
    final organizationId = target.organizationId?.trim();
    if (organizationId == null || organizationId.isEmpty) {
      return target;
    }

    final activeCompany = await AppPreference.getActiveCompany();
    final activeCompanyId = activeCompany?.uuid.trim() ?? '';
    if (activeCompanyId == organizationId) {
      return target;
    }

    final didSwitchOrganization = await AppManager.instance
        .setActiveOrganization(organizationId, resetNavigationStack: false);
    if (!didSwitchOrganization) {
      return null;
    }

    await _refreshSavedActiveCompany();
    return target;
  }

  void _navigateToLoginForAuthentication() {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  Future<void> openPendingAuthenticatedTargetAfterLogin() async {
    final target = await takePendingAuthenticatedTargetReady(
      markAsNavigating: true,
    );
    if (target == null) {
      return;
    }

    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final baseRouteName = target.postLoginBaseRouteName;
    if (baseRouteName == null || baseRouteName.isEmpty) {
      navigator.pushNamedAndRemoveUntil(target.routeName, (route) => false);
      return;
    }

    navigator.pushNamedAndRemoveUntil(baseRouteName, (route) => false);
    await Future<void>.microtask(() {
      navigator.pushNamed(target.routeName, arguments: target.arguments);
    });
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      return payload is Map<String, dynamic> ? payload : null;
    } catch (_) {
      return null;
    }
  }

  void _navigateWhenReady(
    DeepLinkTarget target, {
    int attempt = 0,
    bool bypassDuplicateNavigationGuard = false,
  }) {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) {
      if (attempt >= 10) {
        return;
      }

      Future<void>.delayed(
        const Duration(milliseconds: 150),
        () => _navigateWhenReady(target, attempt: attempt + 1),
      );
      return;
    }

    final currentRouteName = AppManager.instance.currentRouteName;
    if (currentRouteName == target.routeName &&
        target.routeName != AppRouter.sharedLms &&
        target.routeName != AppRouter.sharedPaygrades &&
        target.routeName != AppRouter.sharedSeatProfile) {
      if (target.clearStack) {
        _markNavigationStarted(target);
        navigator.pushNamedAndRemoveUntil(
          target.routeName,
          (route) => false,
          arguments: target.arguments,
        );
        _scheduleNavigationRetryIfNeeded(
          target,
          originRouteName: currentRouteName,
          hasRetried: bypassDuplicateNavigationGuard,
        );
        return;
      }

      _clearActiveNavigation(target);
      return;
    }

    if (!bypassDuplicateNavigationGuard && _isNavigationInFlight(target)) {
      return;
    }

    if (target.routeName == AppRouter.onboarding &&
        currentRouteName == AppRouter.onboardingPassword) {
      _markNavigationStarted(target);
      navigator.popUntil(
        (route) => route.settings.name == AppRouter.onboarding,
      );
      return;
    }

    if (target.routeName == AppRouter.onboardingPassword) {
      _markNavigationStarted(target);
      if (target.clearStack) {
        navigator.pushNamedAndRemoveUntil(
          AppRouter.onboarding,
          (route) => false,
        );
      } else {
        navigator.pushNamed(AppRouter.onboarding);
      }
      Future<void>.microtask(() {
        navigator.pushNamed(target.routeName, arguments: target.arguments);
      });
      _scheduleNavigationRetryIfNeeded(
        target,
        originRouteName: currentRouteName,
        hasRetried: bypassDuplicateNavigationGuard,
      );
      return;
    }

    _markNavigationStarted(target);

    if (target.clearStack) {
      navigator.pushNamedAndRemoveUntil(
        target.routeName,
        (route) => false,
        arguments: target.arguments,
      );
      _scheduleNavigationRetryIfNeeded(
        target,
        originRouteName: currentRouteName,
        hasRetried: bypassDuplicateNavigationGuard,
      );
      return;
    }

    navigator.pushNamed(target.routeName, arguments: target.arguments);
    _scheduleNavigationRetryIfNeeded(
      target,
      originRouteName: currentRouteName,
      hasRetried: bypassDuplicateNavigationGuard,
    );
  }

  void _completeStartupTarget(DeepLinkTarget? target) {
    final completer = _startupTargetCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(target);
    }
  }

  bool _isNavigationInFlight(DeepLinkTarget target) {
    return _activeNavigationTargetKey == target.deduplicationKey;
  }

  void _markNavigationStarted(DeepLinkTarget target) {
    _activeNavigationTargetKey = target.deduplicationKey;
    _activeNavigationTimer?.cancel();
    _activeNavigationTimer = Timer(_activeNavigationWindow, () {
      if (_activeNavigationTargetKey == target.deduplicationKey) {
        _activeNavigationTargetKey = null;
      }
    });
  }

  void _clearActiveNavigation(DeepLinkTarget target) {
    if (_activeNavigationTargetKey != target.deduplicationKey) {
      return;
    }

    _activeNavigationTimer?.cancel();
    _activeNavigationTargetKey = null;
  }

  void _scheduleNavigationRetryIfNeeded(
    DeepLinkTarget target, {
    required String? originRouteName,
    required bool hasRetried,
  }) {
    // Shared links can push new content on the same route. An unchanged
    // route name cannot identify a failed navigation in that case.
    if (hasRetried || originRouteName == target.routeName) {
      return;
    }

    Future<void>.delayed(_navigationRetryDelay, () {
      if (AppManager.instance.currentRouteName != originRouteName) {
        return;
      }

      _navigateWhenReady(target, bypassDuplicateNavigationGuard: true);
    });
  }
}

class DeepLinkTarget {
  const DeepLinkTarget._({
    required this.routeName,
    this.arguments,
    this.clearStack = false,
    this.requiresAuthentication = false,
    this.organizationId,
  });

  const DeepLinkTarget.profile({bool clearStack = false})
    : this._(
        routeName: AppRouter.onboarding,
        clearStack: clearStack,
        requiresAuthentication: false,
      );

  DeepLinkTarget.password(String? profileImagePath)
    : this._(
        routeName: AppRouter.onboardingPassword,
        arguments: OnboardingPasswordRouteArgs(
          profileImagePath: profileImagePath,
        ),
        requiresAuthentication: false,
      );

  DeepLinkTarget.passwordResetConfirm({required String token, String? email})
    : this._(
        routeName: AppRouter.loginSetPassword,
        arguments: LoginSetPasswordRouteArgs(email: email, token: token),
        clearStack: true,
        requiresAuthentication: false,
      );

  DeepLinkTarget.complianceTracks(
    String trackAssignmentUuid, {
    String? organizationId,
  }) : this._(
         routeName: AppRouter.complianceTracks,
         arguments: ComplianceTracksRouteArgs(
           trackAssignmentUuid: trackAssignmentUuid,
           title: '',
         ),
         requiresAuthentication: true,
         organizationId: organizationId,
       );

  DeepLinkTarget.sharedLms(String publicId)
    : this._(
        routeName: AppRouter.sharedLms,
        arguments: SharedLmsRouteArgs(publicId: publicId),
        requiresAuthentication: false,
      );

  DeepLinkTarget.sharedPaygrades(String publicId)
    : this._(
        routeName: AppRouter.sharedPaygrades,
        arguments: SharedPaygradesRouteArgs(publicId: publicId),
        requiresAuthentication: false,
      );

  DeepLinkTarget.sharedSeatProfile(String publicId)
    : this._(
        routeName: AppRouter.sharedSeatProfile,
        arguments: SharedSeatProfileRouteArgs(publicId: publicId),
        requiresAuthentication: false,
      );

  final String routeName;
  final Object? arguments;
  final bool clearStack;
  final bool requiresAuthentication;
  final String? organizationId;
  String? get postLoginBaseRouteName {
    switch (routeName) {
      case AppRouter.complianceTracks:
        return AppRouter.learningTracks;
    }

    return null;
  }

  String get deduplicationKey =>
      '$routeName|$clearStack|${arguments?.toString() ?? ''}';
}
