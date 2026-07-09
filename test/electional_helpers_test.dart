import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/electional_helpers.dart';

ElectionalHit hit({
  String planet = 'Venus',
  int house = 5,
  String houseName = 'Love & Pleasure',
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
  group('formatDayHeading', () {
    test('formats an ISO date as weekday, month, day', () {
      // 2026-07-08 is a Wednesday.
      expect(formatDayHeading('2026-07-08'), 'Wednesday, July 8');
    });

    test('does not zero-pad the day number', () {
      expect(formatDayHeading('2026-01-05'), 'Monday, January 5');
    });
  });

  group('humanizedTimeOfDay', () {
    final expectations = <String, String>{
      '05:00': 'early morning',
      '08:59': 'early morning',
      '09:00': 'late morning',
      '11:59': 'late morning',
      '12:00': 'midday',
      '13:59': 'midday',
      '14:00': 'afternoon',
      '16:59': 'afternoon',
      '17:00': 'early evening',
      '19:59': 'early evening',
      '20:00': 'night',
      '23:59': 'night',
      '00:00': 'late night',
      '04:59': 'late night',
    };

    expectations.forEach((time, expected) {
      test('$time -> $expected', () {
        expect(humanizedTimeOfDay(time), expected);
      });
    });
  });

  group('favorableRulerFor', () {
    test('returns the ruling planet on a favorable weekday for the theme', () {
      // Friday 2026-01-02 is a favorable day for love_relationships (Venus).
      final friday = DateTime(2026, 1, 2);
      expect(friday.weekday, DateTime.friday);
      expect(favorableRulerFor('love_relationships', friday), 'Venus');
    });

    test('returns the ruling planet for the other favorable weekday too', () {
      // Monday 2026-01-05 is also favorable for love_relationships (Moon).
      final monday = DateTime(2026, 1, 5);
      expect(monday.weekday, DateTime.monday);
      expect(favorableRulerFor('love_relationships', monday), 'Moon');
    });

    test('returns null on a non-favorable weekday', () {
      // Tuesday 2026-01-06 is not favorable for love_relationships.
      final tuesday = DateTime(2026, 1, 6);
      expect(tuesday.weekday, DateTime.tuesday);
      expect(favorableRulerFor('love_relationships', tuesday), isNull);
    });

    test('returns null for an unknown theme key', () {
      final friday = DateTime(2026, 1, 2);
      expect(favorableRulerFor('not_a_real_theme', friday), isNull);
    });

    test('every theme entry resolves to a real day ruler', () {
      for (final entry in favorableWeekdaysByTheme.entries) {
        for (final weekday in entry.value) {
          expect(dayRulers.containsKey(weekday), isTrue, reason: '${entry.key} references weekday $weekday');
        }
      }
    });
  });

  group('qualityIndicatorFor', () {
    test('benefic trine gets a star', () {
      expect(qualityIndicatorFor(hit(planet: 'Venus', aspect: 'trine')), '★');
    });

    test('benefic sextile gets a star', () {
      expect(qualityIndicatorFor(hit(planet: 'Jupiter', aspect: 'sextile')), '★');
    });

    test('benefic conjunction gets a star', () {
      expect(qualityIndicatorFor(hit(planet: 'Venus', aspect: 'conjunction')), '★');
    });

    test('benefic square gets a warning triangle, not a star', () {
      expect(qualityIndicatorFor(hit(planet: 'Jupiter', aspect: 'square')), '△');
    });

    test('benefic opposition gets a warning triangle, not a star', () {
      expect(qualityIndicatorFor(hit(planet: 'Venus', aspect: 'opposition')), '△');
    });

    test('malefic square gets a warning triangle', () {
      expect(qualityIndicatorFor(hit(planet: 'Mars', aspect: 'square')), '△');
    });

    test('malefic opposition gets a warning triangle', () {
      expect(qualityIndicatorFor(hit(planet: 'Saturn', aspect: 'opposition')), '△');
    });

    test('malefic trine gets no indicator', () {
      expect(qualityIndicatorFor(hit(planet: 'Mars', aspect: 'trine')), isNull);
    });

    test('malefic conjunction gets no indicator', () {
      expect(qualityIndicatorFor(hit(planet: 'Saturn', aspect: 'conjunction')), isNull);
    });

    test('neutral planet in a harmonious aspect gets no indicator (star is benefic-only)', () {
      for (final aspect in ['trine', 'sextile', 'conjunction']) {
        expect(qualityIndicatorFor(hit(planet: 'Sun', aspect: aspect)), isNull, reason: 'Sun $aspect');
        expect(qualityIndicatorFor(hit(planet: 'Moon', aspect: aspect)), isNull, reason: 'Moon $aspect');
        expect(qualityIndicatorFor(hit(planet: 'Mercury', aspect: aspect)), isNull, reason: 'Mercury $aspect');
      }
    });

    test('neutral planet square/opposition gets a warning triangle too', () {
      // A square is geometrically tense regardless of which planet forms
      // it -- this is the fix for squares from the Sun/Moon/Mercury looking
      // unexplained next to a favorable label.
      for (final aspect in ['square', 'opposition']) {
        expect(qualityIndicatorFor(hit(planet: 'Sun', aspect: aspect)), '△', reason: 'Sun $aspect');
        expect(qualityIndicatorFor(hit(planet: 'Moon', aspect: aspect)), '△', reason: 'Moon $aspect');
        expect(qualityIndicatorFor(hit(planet: 'Mercury', aspect: aspect)), '△', reason: 'Mercury $aspect');
      }
    });
  });

  group('groupHits', () {
    test('merges a direct+antiscion pair on the same planet/house into one entry', () {
      final hits = [
        hit(planet: 'Jupiter', house: 7, aspect: 'trine', mode: 'direct', score: 0.9),
        hit(planet: 'Jupiter', house: 7, aspect: 'sextile', mode: 'antiscion', score: 0.5),
      ];
      final grouped = groupHits(hits);
      expect(grouped, hasLength(1));
      expect(grouped.first.modeLabel, 'direct + antiscion');
    });

    test('the merged entry keeps the higher-scoring hit as the displayed one', () {
      final hits = [
        hit(planet: 'Jupiter', house: 7, aspect: 'trine', mode: 'direct', score: 0.9),
        hit(planet: 'Jupiter', house: 7, aspect: 'sextile', mode: 'antiscion', score: 0.5),
      ];
      final grouped = groupHits(hits);
      expect(grouped.first.hit.aspect, 'trine');
      expect(grouped.first.hit.mode, 'direct');
    });

    test('does not merge hits on different houses even for the same planet', () {
      final hits = [
        hit(planet: 'Jupiter', house: 5, aspect: 'trine', mode: 'direct'),
        hit(planet: 'Jupiter', house: 7, aspect: 'sextile', mode: 'antiscion'),
      ];
      final grouped = groupHits(hits);
      expect(grouped, hasLength(2));
      expect(grouped.map((g) => g.modeLabel), everyElement(isNot('direct + antiscion')));
    });

    test('does not merge two direct hits on the same planet/house (defensive: should not happen upstream)', () {
      final hits = [
        hit(planet: 'Venus', house: 5, aspect: 'trine', mode: 'direct'),
        hit(planet: 'Venus', house: 5, aspect: 'square', mode: 'direct'),
      ];
      final grouped = groupHits(hits);
      expect(grouped, hasLength(2));
    });

    test('a lone direct hit keeps its own mode label', () {
      final hits = [hit(planet: 'Sun', house: 10, mode: 'direct')];
      final grouped = groupHits(hits);
      expect(grouped, hasLength(1));
      expect(grouped.first.modeLabel, 'direct');
    });

    test('a lone antiscion hit keeps its own mode label', () {
      final hits = [hit(planet: 'Sun', house: 10, mode: 'antiscion')];
      final grouped = groupHits(hits);
      expect(grouped, hasLength(1));
      expect(grouped.first.modeLabel, 'antiscion');
    });

    test('empty input produces empty output', () {
      expect(groupHits([]), isEmpty);
    });

    test('multiple distinct planet/house pairs all survive independently', () {
      final hits = [
        hit(planet: 'Venus', house: 5, mode: 'direct'),
        hit(planet: 'Jupiter', house: 7, mode: 'direct'),
        hit(planet: 'Sun', house: 1, mode: 'direct'),
      ];
      expect(groupHits(hits), hasLength(3));
    });

    test('a lone cazimi hit carries isCazimi through to the grouped entry', () {
      final hits = [hit(planet: 'Venus', house: 5, mode: 'direct', isCazimi: true)];
      final grouped = groupHits(hits);
      expect(grouped.first.isCazimi, isTrue);
    });

    test('a non-cazimi hit does not carry isCazimi', () {
      final hits = [hit(planet: 'Venus', house: 5, mode: 'direct', isCazimi: false)];
      final grouped = groupHits(hits);
      expect(grouped.first.isCazimi, isFalse);
    });

    test('cazimi on the direct hit of a merged direct+antiscion pair survives merging', () {
      final hits = [
        hit(planet: 'Venus', house: 5, aspect: 'trine', mode: 'direct', score: 0.5, isCazimi: true),
        hit(planet: 'Venus', house: 5, aspect: 'sextile', mode: 'antiscion', score: 0.9, isCazimi: false),
      ];
      final grouped = groupHits(hits);
      // The antiscion hit outscores the direct one and is the one displayed,
      // but the group must still surface isCazimi=true -- it describes the
      // planet's real-body relationship to the Sun, which the antiscion
      // point (a mirrored, non-physical position) can never be.
      expect(grouped, hasLength(1));
      expect(grouped.first.hit.mode, 'antiscion');
      expect(grouped.first.isCazimi, isTrue);
    });
  });
}
