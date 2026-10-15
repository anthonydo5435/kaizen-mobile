class GoogleAuthorization {
  const GoogleAuthorization({required this.code, required this.redirectUri});

  final String code;
  final String redirectUri;
}

enum GoogleAuthorizationFailure {
  unavailable,
  invalidResponse,
  timedOut,
  browserUnavailable,
  callbackNotVerified,
}

class GoogleAuthorizationException implements Exception {
  const GoogleAuthorizationException(this.reason);

  final GoogleAuthorizationFailure reason;
}
