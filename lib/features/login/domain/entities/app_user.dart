enum LoginSetupStep { ready, emailVerification, workspaceImport }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.verificationUserId,
    this.setupStep = LoginSetupStep.ready,
  });

  final String id;
  final String email;
  final String displayName;
  final String? verificationUserId;
  final LoginSetupStep setupStep;
}
