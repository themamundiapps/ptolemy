/// A simulated Google identity, returned by [AuthService.signInWithGoogle].
///
/// Real Google Sign-In needs an OAuth client id from a Google Cloud project
/// and the official `google_sign_in` plugin, which has no Windows desktop
/// implementation -- only Android/iOS/Web. Until those credentials exist,
/// this mock stands in: same call shape and latency as the real thing, so
/// swapping it out later is a one-function change, not a rewrite.
class MockGoogleAccount {
  final String id;
  final String name;
  final String email;

  const MockGoogleAccount({required this.id, required this.name, required this.email});
}

class AuthService {
  static Future<MockGoogleAccount> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return const MockGoogleAccount(
      id: 'mock-google-user-001',
      name: 'Alex Rivera',
      email: 'alex.rivera@gmail.com',
    );
  }
}
