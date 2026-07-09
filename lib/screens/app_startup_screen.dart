import 'package:flutter/material.dart';

import '../services/app_flow.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'welcome_screen.dart';

/// The app's actual home widget. Resolves, on every launch, whether this
/// device has a sign-in session at all -- if not, straight to the welcome
/// screen; if so, hands off to [AppFlow] to load a saved chart or fall
/// through to birth data / onboarding.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final session = await StorageService.loadSession();
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      return;
    }
    await AppFlow.goToChartOrBirthData(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );
  }
}
