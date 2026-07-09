enum AuthMode { google, guest }

/// The device's current sign-in state -- either a mocked Google identity or
/// anonymous guest mode. Persisted via StorageService and consulted on every
/// app open to decide whether a saved chart can be loaded automatically.
class AuthSession {
  final AuthMode mode;
  final String? googleId;
  final String? googleName;
  final String? googleEmail;

  const AuthSession.google({required this.googleId, required this.googleName, required this.googleEmail}) : mode = AuthMode.google;

  const AuthSession.guest() : mode = AuthMode.guest, googleId = null, googleName = null, googleEmail = null;
}
