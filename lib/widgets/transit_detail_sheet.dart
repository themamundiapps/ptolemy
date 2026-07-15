import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Astronomicon (bundled as an app asset -- see pubspec.yaml, and
/// lib/widgets/chart_wheel.dart for the original mapping and how it was
/// verified) maps each glyph onto a plain Latin letter/punctuation codepoint
/// rather than the actual Unicode astrological codepoint -- any Text showing
/// one of these MUST scope the font family to just that character, never to
/// a whole string that also contains ordinary English text.
const _astronomiconFontFamily = 'Astronomicon';

const _aspectSymbols = {
  'conjunction': '!',
  'sextile': '%',
  'square': '#',
  'trine': r'$',
  'opposition': '"',
};

/// One-line introduction preceding the interpretation body, varying by
/// aspect type -- same pattern as aspect_detail_sheet.dart's natal-aspect
/// intros, but phrased for a transit unfolding "in the present moment"
/// rather than a fixed natal placement.
const _aspectIntros = {
  'conjunction': 'A conjunction intensifies this planetary combination in the present moment.',
  'sextile': 'A sextile opens cooperative opportunity through this transit.',
  'square': 'A square creates friction and tension that calls for conscious engagement.',
  'trine': 'A trine brings ease and natural flow to this transit.',
  'opposition': 'An opposition places these principles in direct confrontation today.',
};

const _fallbackText = 'Interpretation for this transit is coming in a future update.';

const _bodyStyle = TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5);
const _introStyle = TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 13, height: 1.4);
const _fallbackStyle = TextStyle(color: AppColors.mutedText, fontStyle: FontStyle.italic, fontSize: 14, height: 1.4);
const _orbStyle = TextStyle(color: AppColors.mutedText, fontSize: 12);

void showTransitDetailSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required Transit transit,
}) {
  final symbol = _aspectSymbols[transit.aspect] ?? transit.aspect;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
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
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.headlineMedium,
                children: [
                  TextSpan(text: '${transit.transitingPlanet} '),
                  TextSpan(text: symbol, style: const TextStyle(fontFamily: _astronomiconFontFamily)),
                  TextSpan(text: ' natal ${transit.natalPlanet}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(_aspectIntros[transit.aspect] ?? '', style: _introStyle),
            const SizedBox(height: 16),
            FutureBuilder<Interpretation>(
              future: apiClient.fetchTransitInterpretation(
                transiting: transit.transitingPlanet,
                natal: transit.natalPlanet,
                aspectType: transit.aspect,
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
                return Text(snapshot.data!.body, style: _bodyStyle);
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Orb: ${transit.orb.toStringAsFixed(1)}° · ${transit.isApplying ? 'Applying' : 'Separating'}',
              style: _orbStyle,
            ),
          ],
        ),
      ),
    ),
  );
}
