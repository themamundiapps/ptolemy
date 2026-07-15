import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/widgets/chart_wheel.dart';

ZodiacPosition _pos(double longitude) => ZodiacPosition(
  longitude: longitude,
  sign: 'Aries',
  signLongitude: longitude % 30,
  house: 1,
  retrograde: false,
  dignities: const [],
);

ChartResponse _chartWith(Map<String, double> planetLongitudes, {double fortune = 200, double spirit = 220}) {
  return ChartResponse(
    julianDayUt: 0,
    sect: 'diurnal',
    timezoneId: null,
    utcOffsetUsed: 0,
    tzSource: 'auto',
    ascendant: _pos(0),
    midheaven: _pos(270),
    planets: planetLongitudes.map((name, lon) => MapEntry(name, _pos(lon))),
    lotOfFortune: _pos(fortune),
    lotOfSpirit: _pos(spirit),
    aspects: const [],
  );
}

void main() {
  group('computeWheelPlacements', () {
    test('four planets clustered within one sign stay clear of each other on a small phone-sized wheel', () {
      // Mirrors the reported real-device bug: several planets in one sign,
      // on a small baseRadius the way a small phone screen produces
      // (baseRadius ~70px is roughly what a 360dp-wide phone yields).
      final result = _chartWith({'Sun': 0, 'Mercury': 6, 'Venus': 12, 'Moon': 18});
      final placements = computeWheelPlacements(
        result: result,
        signStart: 0,
        center: const Offset(150, 150),
        baseRadius: 70,
      );

      final entries = placements.entries.where((e) => ['Sun', 'Mercury', 'Venus', 'Moon'].contains(e.key)).toList();
      final points = entries.map((e) => e.value.point).toList();
      for (var i = 0; i < points.length; i++) {
        for (var j = i + 1; j < points.length; j++) {
          final distance = (points[i] - points[j]).distance;
          expect(
            distance,
            greaterThanOrEqualTo(15.0),
            reason: 'placements $i and $j are only $distance px apart -- glyphs would overlap',
          );
        }
      }
      for (final e in entries) {
        expect(e.value.clusterSize, 4);
      }
    });

    test('band radius never reaches zero or negative, even with many conjunct bodies on a small wheel', () {
      final result = _chartWith({'Sun': 10, 'Moon': 11, 'Mercury': 12, 'Venus': 13, 'Mars': 14, 'Jupiter': 15, 'Saturn': 16});
      final placements = computeWheelPlacements(
        result: result,
        signStart: 0,
        center: const Offset(60, 60),
        baseRadius: 30,
      );

      for (final entry in placements.entries) {
        expect(entry.value.radius, greaterThan(0), reason: '${entry.key} has non-positive radius ${entry.value.radius}');
      }
    });

    test('planetGlyphFontSize is a single fixed size, small enough for a 4-body cluster to stay clear', () {
      expect(planetGlyphFontSize, greaterThan(0));
      expect(planetGlyphFontSize, lessThanOrEqualTo(15));
    });

    test('widely separated planets are not forced into the same cluster', () {
      final result = _chartWith({'Sun': 0, 'Moon': 90, 'Mercury': 180, 'Venus': 270});
      final placements = computeWheelPlacements(
        result: result,
        signStart: 0,
        center: const Offset(150, 150),
        baseRadius: 100,
      );

      // Widely spaced planets should all sit on the outermost band (no
      // radial stacking needed) since none are within the clustering gap.
      for (final name in ['Sun', 'Moon', 'Mercury', 'Venus']) {
        expect(placements[name]!.radius, 100.0);
      }
    });
  });
}
