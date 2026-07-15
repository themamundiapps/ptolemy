import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// The same OAuth client registered in android/app/src/main/res/values/
/// strings.xml (as default_web_client_id) -- a single "Web application"
/// type client used both as Android's ID-token audience and directly as
/// the client id for Flutter Web.
const _clientId = '269741173127-vl9mvdbs2qqs95a5384ap3ne8326fpai.apps.googleusercontent.com';

/// A signed-in Google identity's fields, as needed by the rest of the app.
/// This app only needs identity (to key the backend's per-account chart
/// store) and never requests any People-API/contacts scopes, so nothing
/// beyond id/displayName/email is surfaced here.
class GoogleAccount {
  final String id;
  final String name;
  final String email;

  const GoogleAccount({required this.id, required this.name, required this.email});

  factory GoogleAccount._fromPlugin(GoogleSignInAccount account) =>
      GoogleAccount(id: account.id, name: account.displayName ?? '', email: account.email);
}

/// Thrown by [AuthService] for both explicit cancellation and any other
/// sign-in failure -- callers only need a friendly message to display, not
/// to distinguish the underlying cause.
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around the real `google_sign_in` package (v7+, which
/// replaced the old imperative `GoogleSignIn().signIn()` call with an
/// event-stream based API -- see the package's own migration guide).
///
/// Android/iOS support an app-triggered interactive prompt via
/// [authenticate]. Web does not: Google's Identity Services SDK refuses to
/// launch from application-provided UI there at all, so an interactive
/// web sign-in can only be started by a button the SDK itself renders (see
/// widgets/google_sign_in_button.dart). Both paths resolve through the same
/// [accountEvents] stream underneath, mirroring the package's own official
/// example, so the rest of the app reacts identically regardless of which
/// platform triggered the sign-in.
class AuthService {
  static final GoogleSignIn _instance = GoogleSignIn.instance;
  static Future<void>? _initFuture;
  static final _accountController = StreamController<GoogleAccount>.broadcast();
  static final _errorController = StreamController<AuthException>.broadcast();

  /// Fires whenever a sign-in completes, whether triggered by [authenticate]
  /// or by the web-rendered Google button.
  static Stream<GoogleAccount> get accountEvents => _accountController.stream;

  /// Fires when the underlying authentication stream itself reports a
  /// failure (chiefly relevant to the web-rendered button, which has no
  /// other call site to catch an exception from).
  static Stream<AuthException> get errorEvents => _errorController.stream;

  static Future<void> ensureInitialized() {
    return _initFuture ??= _instance
        .initialize(clientId: _clientId, serverClientId: _clientId)
        .then((_) => _instance.authenticationEvents.listen(_onEvent, onError: _onError));
  }

  static void _onEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      _accountController.add(GoogleAccount._fromPlugin(event.user));
    }
  }

  static void _onError(Object error) {
    _errorController.add(_toAuthException(error));
  }

  static AuthException _toAuthException(Object error) {
    if (error is GoogleSignInException) {
      return AuthException(
        error.code == GoogleSignInExceptionCode.canceled
            ? 'Sign-in was cancelled.'
            : 'Google sign-in failed: ${error.description ?? error.code}',
      );
    }
    return AuthException('Google sign-in failed: $error');
  }

  /// Whether this platform supports an app-triggered interactive prompt.
  /// True on Android/iOS, false on web (see the class doc).
  static bool supportsAuthenticate() => _instance.supportsAuthenticate();

  /// Interactive sign-in for platforms where the SDK allows an app-triggered
  /// prompt. Throws [AuthException] on cancellation or any other failure.
  static Future<GoogleAccount> authenticate() async {
    await ensureInitialized();
    try {
      final account = await _instance.authenticate();
      return GoogleAccount._fromPlugin(account);
    } on GoogleSignInException catch (e) {
      throw _toAuthException(e);
    }
  }

  static Future<void> signOut() async {
    await ensureInitialized();
    await _instance.signOut();
  }
}
