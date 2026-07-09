import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_flow.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/armillary_sphere_icon.dart';

/// The very first screen a new device sees: pick Google or Guest, then hand
/// off to [AppFlow.goToChartOrBirthData] to decide what comes next.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _signingIn = false;

  Future<void> _continueWithGoogle() async {
    setState(() => _signingIn = true);
    final account = await AuthService.signInWithGoogle();
    await StorageService.saveGoogleSession(id: account.id, name: account.name, email: account.email);
    if (!mounted) return;
    await AppFlow.goToChartOrBirthData(context);
  }

  Future<void> _continueAsGuest() async {
    await StorageService.saveGuestSession();
    if (!mounted) return;
    await AppFlow.goToChartOrBirthData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const ArmillarySphereIcon(size: 100),
              const SizedBox(height: 28),
              Text(
                'PTOLEMY',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Traditional Astrology Made Simple',
                style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 0.5),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _signingIn ? null : _continueWithGoogle,
                  icon: _signingIn
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                        )
                      : const _GoogleMark(),
                  label: const Text('Continue with Google'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _signingIn ? null : _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bodyText,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Guest Mode'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your chart will be saved on this device only.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
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
