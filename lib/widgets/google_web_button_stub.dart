import 'package:flutter/material.dart';

/// Stub for the web-only rendered sign-in button, since google_sign_in_web
/// has to sit behind a conditional import (see google_web_button.dart).
/// Never actually called on non-web platforms -- callers must check
/// AuthService.supportsAuthenticate() / kIsWeb first.
Widget renderGoogleSignInButton() {
  throw StateError('renderGoogleSignInButton is only available on web');
}
