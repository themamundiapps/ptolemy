import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'google_web_button.dart' as web_button;

/// A "Continue with Google" control that works on every platform this app
/// ships to (Android, web). On Android it's this app's own styled button,
/// triggering the native account picker directly via [AuthService.authenticate].
/// On web, Google's Identity Services SDK refuses to launch from
/// application-provided UI at all -- so there it instead renders Google's
/// own button widget and listens for the [AuthService.accountEvents] /
/// [AuthService.errorEvents] that click ultimately produces.
class GoogleSignInButton extends StatefulWidget {
  final String label;
  final ValueChanged<GoogleAccount> onSignedIn;
  final ValueChanged<String> onError;
  final ValueChanged<bool>? onSigningInChanged;

  const GoogleSignInButton({
    required this.onSignedIn,
    required this.onError,
    this.label = 'Continue with Google',
    this.onSigningInChanged,
    super.key,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _signingIn = false;
  StreamSubscription<GoogleAccount>? _accountSub;
  StreamSubscription<AuthException>? _errorSub;

  @override
  void initState() {
    super.initState();
    AuthService.ensureInitialized();
    // On web there's no app-triggered call to hang a result on -- the
    // rendered button below completes the sign-in itself, so the only way
    // to learn the outcome is to listen to the shared event streams.
    if (!AuthService.supportsAuthenticate()) {
      _accountSub = AuthService.accountEvents.listen(widget.onSignedIn);
      _errorSub = AuthService.errorEvents.listen((e) => widget.onError(e.message));
    }
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  void _setSigningIn(bool value) {
    if (!mounted) return;
    setState(() => _signingIn = value);
    widget.onSigningInChanged?.call(value);
  }

  Future<void> _handleTap() async {
    _setSigningIn(true);
    try {
      final account = await AuthService.authenticate();
      if (mounted) widget.onSignedIn(account);
    } on AuthException catch (e) {
      if (mounted) widget.onError(e.message);
    } finally {
      _setSigningIn(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.supportsAuthenticate()) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _signingIn ? null : _handleTap,
          icon: _signingIn
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                )
              : const _GoogleMark(),
          label: Text(widget.label),
        ),
      );
    }
    if (kIsWeb) {
      return Center(child: web_button.renderGoogleSignInButton());
    }
    return const SizedBox.shrink();
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 13, height: 1),
      ),
    );
  }
}
