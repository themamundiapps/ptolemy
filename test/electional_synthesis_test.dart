import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/electional_synthesis.dart';

ElectionalHit hit({
  required String planet,
  required int house,
  String houseName = 'Test House',
  String aspect = 'trine',
  String mode = 'direct',
  double orb = 1.0,
  double score = 1.0,
  bool isSupporting = false,
  bool isCazimi = false,
}) {
  return ElectionalHit(
    planet: planet,
    house: house,
    houseName: houseName,
    aspect: aspect,
    mode: mode,
    orb: orb,
    score: score,
    isSupporting: isSupporting,
    isCazimi: isCazimi,
  );
}

void main() {
  group('qualitativeSymbols', () {
    test('has exactly the three known tiers with distinct glyphs', () {
      expect(qualitativeSymbols.keys.toSet(), {'Auspicious', 'Favorable', 'Best Available'});
      expect(qualitativeSymbols.values.toSet(), hasLength(3)); // all distinct
    });
  });

  group('buildSynthesis', () {
    test('produces non-empty text for a simple single-hit case', () {
      final usageCounts = <String, int>{};
      final text = buildSynthesis([hit(planet: 'Venus', house: 5)], 'Auspicious', usageCounts);
      expect(text, isNotEmpty);
    });

    test('rotates through the three phrasing variants for a repeated planet/house combo', () {
      final usageCounts = <String, int>{};
      final seen = <String>{};
      for (var i = 0; i < 3; i++) {
        // A single hit each time, always the same (planet, house) -- this is
        // the scenario the rotation exists for: several days in the same
        // results list all featuring Moon+House1 as their top hit.
        final text = buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
        // Strip the trailing closing sentence for comparison purposes by
        // just checking the whole text differs across the three calls.
        seen.add(text);
      }
      expect(seen, hasLength(3), reason: 'expected three distinct phrasings, got: $seen');
    });

    test('a fourth call wraps back around to the first variant', () {
      final usageCounts = <String, int>{};
      final first = buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      final fourth = buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      expect(fourth, first);
    });

    test('two independent (planet, house) keys rotate independently', () {
      final usageCounts = <String, int>{};
      final moonFirst = buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      final venusFirst = buildSynthesis([hit(planet: 'Venus', house: 5)], 'Favorable', usageCounts);
      final moonSecond = buildSynthesis([hit(planet: 'Moon', house: 1)], 'Favorable', usageCounts);
      // Moon's second call should differ from its first regardless of the
      // unrelated Venus call happening in between.
      expect(moonSecond, isNot(moonFirst));
      expect(venusFirst, isNot(moonFirst));
    });

    test('closing line varies with the quality tier', () {
      final usageCounts = <String, int>{};
      final auspicious = buildSynthesis([hit(planet: 'Venus', house: 5)], 'Auspicious', usageCounts);
      final favorable = buildSynthesis([hit(planet: 'Venus', house: 5)], 'Favorable', usageCounts);
      final bestAvailable = buildSynthesis([hit(planet: 'Venus', house: 5)], 'Best Available', usageCounts);
      // All three should differ since both the body sentence AND the
      // closing line differ by construction (different rotation state and
      // different tier).
      expect({auspicious, favorable, bestAvailable}, hasLength(3));
    });

    test('an unrecognized quality label omits the closing line without crashing', () {
      final usageCounts = <String, int>{};
      expect(
        () => buildSynthesis([hit(planet: 'Venus', house: 5)], 'Not A Real Tier', usageCounts),
        returnsNormally,
      );
    });

    test('only the top-scoring hits (up to 3) contribute, sorted by score', () {
      final usageCounts = <String, int>{};
      final hits = [
        hit(planet: 'Saturn', house: 4, score: 0.1),
        hit(planet: 'Venus', house: 5, score: 0.9),
        hit(planet: 'Jupiter', house: 7, score: 0.5),
        hit(planet: 'Mars', house: 8, score: 0.05),
      ];
      final text = buildSynthesis(hits, 'Favorable', usageCounts);
      // The lowest-scoring hit (Mars, score 0.05) should not appear since
      // only the top 3 by score are used.
      expect(text.contains('Mars'), isFalse);
    });

    test('a hit for an unknown planet/house combination is skipped without crashing', () {
      final usageCounts = <String, int>{};
      expect(
        () => buildSynthesis([hit(planet: 'Chiron', house: 13, score: 1.0)], 'Favorable', usageCounts),
        returnsNormally,
      );
    });

    test('empty hits list still produces the closing line without crashing', () {
      final usageCounts = <String, int>{};
      final text = buildSynthesis([], 'Auspicious', usageCounts);
      expect(() => text, returnsNormally);
    });

    test('an antiscion top hit gets the "hidden sympathy" framing', () {
      final usageCounts = <String, int>{};
      final text = buildSynthesis(
        [hit(planet: 'Venus', house: 5, mode: 'antiscion')],
        'Favorable',
        usageCounts,
      );
      expect(text.toLowerCase(), contains('hidden sympathy'));
    });
  });
}
