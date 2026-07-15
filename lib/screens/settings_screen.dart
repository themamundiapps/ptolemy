import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/google_sign_in_button.dart';
import 'birth_data_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AuthSession? _session;
  bool _backingUp = false;
  String? _backUpError;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await StorageService.loadSession();
    if (mounted) setState(() => _session = session);
  }

  Future<void> _onBackedUp(GoogleAccount account) async {
    setState(() => _backUpError = null);
    await StorageService.saveGoogleSession(id: account.id, name: account.name, email: account.email);
    final birthData = await StorageService.loadBirthData();
    if (birthData != null) {
      try {
        await ApiClient(baseUrl: defaultBaseUrl()).saveUserChart(googleId: account.id, birthData: birthData);
      } catch (_) {}
    }
    await _loadSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backed up to Google.')));
    }
  }

  void _onBackUpError(String message) {
    if (mounted) setState(() => _backUpError = message);
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    await StorageService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
  }

  Future<void> _recalculate() async {
    await StorageService.clearChart();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BirthDataScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Account', style: textTheme.titleMedium),
          const Divider(height: 20),
          if (session == null)
            const SizedBox.shrink()
          else ...[
            if (session.mode == AuthMode.google)
              Text(
                'Signed in as ${session.googleName}',
                style: const TextStyle(color: AppColors.bodyText, fontSize: 15),
              )
            else ...[
              const Text('Guest Mode', style: TextStyle(color: AppColors.bodyText, fontSize: 15)),
              const SizedBox(height: 14),
              GoogleSignInButton(
                label: 'Back up to Google',
                onSignedIn: _onBackedUp,
                onError: _onBackUpError,
                onSigningInChanged: (value) => setState(() => _backingUp = value),
              ),
              if (_backUpError != null) ...[
                const SizedBox(height: 8),
                Text(_backUpError!, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
              ],
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _backingUp ? null : _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text('Chart', style: textTheme.titleMedium),
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _recalculate, child: const Text('Recalculate Chart')),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () {}, child: const Text('Restore Purchase')),
          ),
          const SizedBox(height: 40),
          const Center(child: Text('Ptolemy v1.0.0', style: TextStyle(color: AppColors.mutedText, fontSize: 12))),
        ],
      ),
    );
  }
}
