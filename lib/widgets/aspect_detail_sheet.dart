import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

const _aspectSymbols = {
  'conjunction': '☌',
  'sextile': '⚹',
  'square': '□',
  'trine': '△',
  'opposition': '☍',
};

/// One-line introduction preceding the base interpretation, varying by
/// aspect type -- per ptolemy-aspects.md's own note, this is an app-side
/// concern layered on top of the per-pair content, not part of it.
const _aspectIntros = {
  'conjunction': 'A conjunction fuses these two principles into a single, undivided force.',
  'sextile': 'A sextile creates cooperative opportunity between these two principles.',
  'square': 'A square creates tension and friction between these two principles that demands resolution.',
  'trine': 'A trine connects these two principles with ease and natural flow.',
  'opposition': 'An opposition places these two principles in direct confrontation across the chart.',
};

const _lotOfFortuneText =
    "The Lot of Fortune marks the point of material fortune and bodily wellbeing in the natal chart. "
    "Its aspects indicate the planets that most directly shape the native's material circumstances and "
    "physical constitution.";

const _lotOfSpiritText =
    "The Lot of Spirit marks the point of the soul's intention and conscious action. Its aspects "
    "indicate the planets that most directly shape the native's deliberate choices and spiritual direction.";

const _fallbackText = 'Interpretation for this aspect pair is coming in a future update.';

const _bodyStyle = TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5);
const _citationStyle = TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 12, height: 1.4);
const _introStyle = TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 13, height: 1.4);
const _fallbackStyle = TextStyle(color: AppColors.mutedText, fontStyle: FontStyle.italic, fontSize: 14, height: 1.4);
const _orbStyle = TextStyle(color: AppColors.mutedText, fontSize: 12);

/// The fixed explanatory text for an aspect involving a Lot -- Lots have no
/// per-pair interpretation content (see ptolemy-aspects.md), so this is a
/// hardcoded fallback keyed only by which Lot is involved, not by its
/// counterpart planet or aspect type. Returns null for an ordinary
/// planet/angle pair.
String? _lotFallbackText(Aspect aspect) {
  if (aspect.planetA == 'Lot of Fortune' || aspect.planetB == 'Lot of Fortune') return _lotOfFortuneText;
  if (aspect.planetA == 'Lot of Spirit' || aspect.planetB == 'Lot of Spirit') return _lotOfSpiritText;
  return null;
}

void showAspectDetailSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required Aspect aspect,
}) {
  final symbol = _aspectSymbols[aspect.aspect] ?? aspect.aspect;
  final lotText = _lotFallbackText(aspect);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: scrollController,
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
            Text(
              '${aspect.planetA} $symbol ${aspect.planetB}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            if (lotText != null)
              Text(lotText, style: _bodyStyle)
            else ...[
              Text(_aspectIntros[aspect.aspect] ?? '', style: _introStyle),
              const SizedBox(height: 16),
              FutureBuilder<Interpretation>(
                future: apiClient.fetchAspectInterpretation(
                  planetA: aspect.planetA,
                  planetB: aspect.planetB,
                  aspectType: aspect.aspect,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(_fallbackText, style: _fallbackStyle);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.data!.body, style: _bodyStyle),
                      if (snapshot.data!.citation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(snapshot.data!.citation, style: _citationStyle),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text('Orb: ${aspect.orb.toStringAsFixed(1)}°', style: _orbStyle),
            ],
          ],
        ),
      ),
    ),
  );
}
