import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

// Hardcoded during development — real subscription state comes later.
const bool _isSubscriber = true;

const _bodyStyle = TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5);
const _citationStyle = TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 12, height: 1.4);

void showPlanetDetailSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required ChartResponse result,
  required String planetName,
}) {
  final position = result.planets[planetName];
  if (position == null) return;

  final relevantAspects = result.aspects
      .where((a) => a.planetA == planetName || a.planetB == planetName)
      .map((a) {
        final other = a.planetA == planetName ? a.planetB : a.planetA;
        return '${_aspectVerb(a.aspect)} $other (orb ${a.orb.toStringAsFixed(2)}°)';
      })
      .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _PlanetDetailSheet(
        apiClient: apiClient,
        result: result,
        planetName: planetName,
        position: position,
        relevantAspects: relevantAspects,
        scrollController: scrollController,
      ),
    ),
  );
}

String _aspectVerb(String aspect) => aspect == 'conjunction' ? 'Conjunct' : '${aspect[0].toUpperCase()}${aspect.substring(1)}';

class _PlanetDetailSheet extends StatefulWidget {
  final ApiClient apiClient;
  final ChartResponse result;
  final String planetName;
  final ZodiacPosition position;
  final List<String> relevantAspects;
  final ScrollController scrollController;

  const _PlanetDetailSheet({
    required this.apiClient,
    required this.result,
    required this.planetName,
    required this.position,
    required this.relevantAspects,
    required this.scrollController,
  });

  @override
  State<_PlanetDetailSheet> createState() => _PlanetDetailSheetState();
}

class _PlanetDetailSheetState extends State<_PlanetDetailSheet> {
  late final Future<Interpretation> _signFuture;
  late final Future<Interpretation> _houseFuture;
  Future<String>? _synthesisFuture;

  @override
  void initState() {
    super.initState();
    _signFuture = widget.apiClient.fetchPlanetInSign(planet: widget.planetName, sign: widget.position.sign);
    _houseFuture = widget.apiClient.fetchPlanetInHouse(planet: widget.planetName, house: widget.position.house);
    if (_isSubscriber) {
      _synthesisFuture = widget.apiClient.fetchSynthesis(
        planet: widget.planetName,
        sign: widget.position.sign,
        house: widget.position.house,
        sect: widget.result.sect,
        dignities: widget.position.dignities,
        aspects: widget.relevantAspects,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.mutedText, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Personal Synthesis', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (!_isSubscriber) const _LockedSynthesis() else _SynthesisContent(future: _synthesisFuture!),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: AppColors.gold, thickness: 1, height: 1),
          ),
          FutureBuilder<Interpretation>(
            future: _signFuture,
            builder: (context, snapshot) => _InterpretationSection(
              title: '${widget.planetName} in ${widget.position.sign}',
              titleStyle: theme.textTheme.titleMedium,
              snapshot: snapshot,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: AppColors.gold, thickness: 1, height: 1),
          ),
          FutureBuilder<Interpretation>(
            future: _houseFuture,
            builder: (context, snapshot) => _InterpretationSection(
              title: '${widget.planetName} in House ${widget.position.house}',
              titleStyle: theme.textTheme.titleMedium,
              snapshot: snapshot,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterpretationSection extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final AsyncSnapshot<Interpretation> snapshot;

  const _InterpretationSection({required this.title, required this.titleStyle, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 10),
        if (snapshot.connectionState != ConnectionState.done)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
          )
        else if (snapshot.hasError || !snapshot.hasData)
          const Text('Interpretation unavailable.', style: TextStyle(color: AppColors.mutedText))
        else ...[
          Text(snapshot.data!.body, style: _bodyStyle),
          if (snapshot.data!.citation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(snapshot.data!.citation, style: _citationStyle),
          ],
        ],
      ],
    );
  }
}

class _LockedSynthesis extends StatelessWidget {
  const _LockedSynthesis();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A personalized reading of this placement — sign, house, dignity, sect, and every aspect '
                    'it makes — generated by AI for your specific chart',
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () {}, child: const Text('Unlock with Pro')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SynthesisContent extends StatelessWidget {
  final Future<String> future;

  const _SynthesisContent({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            'Personal Synthesis temporarily unavailable',
            style: TextStyle(color: AppColors.mutedText, fontStyle: FontStyle.italic),
          );
        }
        return Text(snapshot.data!, style: _bodyStyle);
      },
    );
  }
}
