import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme.dart';
import 'birth_data_screen.dart';

/// Three swipeable screens shown exactly once, on the very first time the
/// app is about to land on the birth data form (a saved chart, if any,
/// always takes priority and skips this entirely -- see AppFlow).
class OnboardingScreen extends StatefulWidget {
  final String? loadError;

  const OnboardingScreen({this.loadError, super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    await StorageService.setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => BirthDataScreen(loadError: widget.loadError)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage1(),
                  _OnboardingPage2(),
                  _OnboardingPage3(onGetStarted: _finish),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => _Dot(active: i == _page)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;

  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.gold : Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OnboardingPage1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _OnboardingBody(
      headline: 'The sky at the moment of your birth was not random.',
      body:
          'Ptolemy calculates your natal chart using the system of the ancient astrologers — '
          'Whole Sign houses, the seven classical planets, and the methods of Claudius Ptolemy '
          'and Vettius Valens. No modern additions. No pop astrology. The tradition as it was written.',
    );
  }
}

class _OnboardingPage2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _OnboardingBody(
      headline: 'Astrology before it was simplified.',
      body:
          'Traditional astrology is the system practiced from ancient Greece through the Renaissance '
          '— precise, technical, and grounded in centuries of observation. It works with seven '
          'planets, twelve houses, and a set of rules that have remained largely unchanged for two '
          'thousand years. Ptolemy brings this system to your phone, uncompromised.',
    );
  }
}

class _OnboardingPage3 extends StatelessWidget {
  final VoidCallback onGetStarted;

  const _OnboardingPage3({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Three tools. One tradition.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          const _ToolItem(
            label: 'Natal Chart',
            description:
                'Your birth chart calculated and interpreted according to classical sources, with '
                'essential dignities, aspects, and the Lots of Fortune and Spirit.',
          ),
          const SizedBox(height: 18),
          const _ToolItem(
            label: 'Temperament',
            description:
                'Your fundamental constitution determined by the method of Claudius Ptolemy — the '
                'balance of Hot, Cold, Moist, and Dry that shapes your body and character.',
          ),
          const SizedBox(height: 18),
          const _ToolItem(
            label: 'Electional Astrology',
            description:
                'Find the most astrologically favorable moments to act. Choose a theme, choose a '
                'period, and let the chart guide your timing.',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onGetStarted, child: const Text('Get Started')),
          ),
        ],
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final String label;
  final String description;

  const _ToolItem({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.45)),
      ],
    );
  }
}

class _OnboardingBody extends StatelessWidget {
  final String headline;
  final String body;

  const _OnboardingBody({required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Text(body, style: const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.55)),
        ],
      ),
    );
  }
}
