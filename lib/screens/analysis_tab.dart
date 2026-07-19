import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/error_messages.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/example_reading.dart';
import '../widgets/pro_status_builder.dart';
import 'paywall_screen.dart';

const _subtitleStyle = TextStyle(color: AppColors.mutedText, fontSize: 14, height: 1.5);

const _exampleAnalysisText = '''
This is a diurnal nativity of considerable solar force. The Sun, lord of the chart by sect, occupies its own domicile in Leo and is placed at the Midheaven — a configuration Valens considers among the most publicly distinguished, producing natives known by name in many places and thought worthy of honor and rank. The Moon, applying to a trine with Jupiter in the eleventh house, adds genuine popular goodwill and the support of powerful friends to an already prominent nativity.

Saturn, though a malefic, is well-placed in Libra — its exaltation — and governs the ninth house of philosophy and long journeys. This tempering of the solar fire by Saturnine discipline produces not mere ambition but the patient, methodical pursuit of lasting distinction. The native is not content with recognition that does not endure.

The Lot of Fortune falls in the fifth house, receiving a trine from Jupiter: material fortune comes through creative expression and the goodwill of those in positions of authority. The native tends to prosper most when their genuine gifts are visible rather than concealed.

Overall, this is a nativity of public distinction, intellectual authority, and sustained ambition — a chart in which the solar principle operates at its fullest, tempered by Saturnine endurance and supported by genuine Jovian good fortune.
''';

/// The Analysis tab: a single AI-generated full natal chart reading, shown
/// alongside Chart, Electional, and Temperament on the main chart screen.
/// Cached to shared_preferences (keyed by the exact birth chart) so opening
/// the tab again doesn't re-call the API.
class AnalysisTab extends StatefulWidget {
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;
  final double? tzOffset;
  final ApiClient? apiClient;

  const AnalysisTab({
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    this.tzOffset,
    this.apiClient,
    super.key,
  });

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

enum _Status { idle, loading, loaded, error }

class _AnalysisTabState extends State<AnalysisTab> {
  _Status _status = _Status.idle;
  String? _analysisText;
  String? _errorMessage;

  ApiClient get _client => widget.apiClient ?? ApiClient(baseUrl: defaultBaseUrl());

  String get _chartKey => StorageService.chartAnalysisKey(
        date: widget.birthDate,
        time: widget.birthTime,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await StorageService.loadCachedAnalysis(_chartKey);
    if (!mounted || cached == null) return;
    setState(() {
      _analysisText = cached;
      _status = _Status.loaded;
    });
  }

  Future<void> _generate() async {
    setState(() {
      _status = _Status.loading;
      _errorMessage = null;
    });
    try {
      final userId = await StorageService.resolveUserId();
      final text = await _client.fetchChartAnalysis(
        date: widget.birthDate,
        time: widget.birthTime,
        latitude: widget.latitude,
        longitude: widget.longitude,
        tzOffset: widget.tzOffset,
        userId: userId,
      );
      await StorageService.saveAnalysis(_chartKey, text);
      if (!mounted) return;
      setState(() {
        _analysisText = text;
        _status = _Status.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = friendlyApiError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProStatusBuilder(
      builder: (context, isPro) {
        if (!isPro) return const _LockedAnalysis();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('Chart Analysis', style: Theme.of(context).textTheme.headlineLarge),
                  ),
                  if (_status == _Status.loaded)
                    TextButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.replay, color: AppColors.mutedGold, size: 16),
                      label: const Text('Regenerate ↺', style: TextStyle(color: AppColors.mutedGold, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(child: _body()),
            ],
          ),
        );
      },
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.loading:
        return const _LoadingBody();
      case _Status.loaded:
        return SingleChildScrollView(child: _AnalysisBody(text: _analysisText!));
      case _Status.error:
        return _GenerateBody(onGenerate: _generate, errorMessage: _errorMessage);
      case _Status.idle:
        return _GenerateBody(onGenerate: _generate, errorMessage: null);
    }
  }
}

class _GenerateBody extends StatelessWidget {
  final VoidCallback onGenerate;
  final String? errorMessage;

  const _GenerateBody({required this.onGenerate, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              style: const TextStyle(color: AppColors.warning, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(onPressed: onGenerate, child: const Text('Generate My Reading')),
          const SizedBox(height: 10),
          const Text('This may take a moment', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
          const SizedBox(height: 40),
          const ExampleReading(text: _exampleAnalysisText),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Ptolemy is reading your chart...',
            style: TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Splits the AI's plain-text reading into paragraphs, rendering any short,
/// unpunctuated line as a gold section header rather than body text -- the
/// prompt doesn't force the model into a fixed structure, so this degrades
/// gracefully to plain paragraphs if it never emits anything header-like.
class _AnalysisBody extends StatelessWidget {
  final String text;

  const _AnalysisBody({required this.text});

  static const _sentenceEndings = {'.', '!', '?', '"', '”', ':'};

  bool _looksLikeHeader(String block) {
    if (block.isEmpty || block.length > 60 || block.contains('\n')) return false;
    return !_sentenceEndings.contains(block[block.length - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = text.split(RegExp(r'\n\s*\n')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          Text(
            block,
            style: _looksLikeHeader(block)
                ? const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w600)
                : const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _LockedAnalysis extends StatelessWidget {
  const _LockedAnalysis();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Chart Analysis', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'A complete reading of your natal chart, considering all planets, '
            'houses, aspects, house lords, and temperament together.',
            style: _subtitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline, color: AppColors.gold, size: 28),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: FilledButton(onPressed: () => showPaywallScreen(context), child: const Text('Unlock with Pro')),
          ),
          const SizedBox(height: 40),
          const ExampleReading(text: _exampleAnalysisText),
        ],
      ),
    );
  }
}
