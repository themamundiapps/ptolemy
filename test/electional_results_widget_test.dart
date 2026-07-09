import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/electional_tab.dart';

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

ElectionalDay day({
  required String date,
  String bestTime = '10:00',
  required String qualityLabel,
  List<String>? reasons,
  List<ElectionalHit>? hits,
}) {
  return ElectionalDay(
    date: date,
    bestTime: bestTime,
    qualityLabel: qualityLabel,
    reasons: reasons ?? ['Test reason'],
    hits: hits ?? [hit(planet: 'Venus', house: 5, isSupporting: true)],
  );
}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ResultsList', () {
    testWidgets('renders the theme label in the header', (tester) async {
      final result = ElectionalResult(
        theme: 'love_relationships',
        themeLabel: 'Love & Relationships',
        banner: null,
        note: null,
        days: [day(date: '2026-07-10', qualityLabel: 'Auspicious')],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'love_relationships', onBack: () {})));
      expect(find.textContaining('Love & Relationships'), findsWidgets);
    });

    testWidgets('renders one DayTile per day', (tester) async {
      final result = ElectionalResult(
        theme: 'love_relationships',
        themeLabel: 'Love & Relationships',
        banner: null,
        note: null,
        days: [
          day(date: '2026-07-10', qualityLabel: 'Auspicious'),
          day(date: '2026-07-11', qualityLabel: 'Favorable'),
          day(date: '2026-07-12', qualityLabel: 'Best Available'),
        ],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'love_relationships', onBack: () {})));
      expect(find.byType(DayTile), findsNWidgets(3));
    });

    testWidgets('shows the banner text when present', (tester) async {
      final result = ElectionalResult(
        theme: 'love_relationships',
        themeLabel: 'Love & Relationships',
        banner: 'Venus is retrograde during this period.',
        note: null,
        days: [],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'love_relationships', onBack: () {})));
      expect(find.textContaining('Venus is retrograde'), findsOneWidget);
    });

    testWidgets('shows the note text when present', (tester) async {
      final result = ElectionalResult(
        theme: 'travel',
        themeLabel: 'Travel',
        banner: null,
        note: 'No strongly favorable configurations exist in this period.',
        days: [day(date: '2026-07-10', qualityLabel: 'Best Available')],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'travel', onBack: () {})));
      expect(find.textContaining('No strongly favorable configurations'), findsOneWidget);
    });

    testWidgets('shows the generic empty-state text only when days is empty and note is null', (tester) async {
      final result = ElectionalResult(
        theme: 'travel',
        themeLabel: 'Travel',
        banner: null,
        note: null,
        days: [],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'travel', onBack: () {})));
      expect(find.textContaining('No favorable moments found'), findsOneWidget);
    });

    testWidgets('does not show the generic empty-state text when a note is already present', (tester) async {
      final result = ElectionalResult(
        theme: 'travel',
        themeLabel: 'Travel',
        banner: null,
        note: 'No favorable configurations found in this period. Try extending your search.',
        days: [],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'travel', onBack: () {})));
      // The note itself contains similar wording, so assert there is exactly
      // one occurrence of the phrase, not a duplicate generic fallback too.
      expect(find.textContaining('No favorable'), findsOneWidget);
    });

    testWidgets('both banner and note can render together', (tester) async {
      final result = ElectionalResult(
        theme: 'love_relationships',
        themeLabel: 'Love & Relationships',
        banner: 'Venus is retrograde during this period.',
        note: 'No favorable configurations found in this period.',
        days: [],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'love_relationships', onBack: () {})));
      expect(find.textContaining('Venus is retrograde'), findsOneWidget);
      expect(find.textContaining('No favorable configurations found'), findsOneWidget);
    });

    testWidgets('back button invokes onBack', (tester) async {
      var backTapped = false;
      final result = ElectionalResult(
        theme: 'travel',
        themeLabel: 'Travel',
        banner: null,
        note: null,
        days: [],
      );
      await tester.pumpWidget(wrap(ResultsList(result: result, themeKey: 'travel', onBack: () => backTapped = true)));
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backTapped, isTrue);
    });
  });

  group('DayTile', () {
    testWidgets('shows the Auspicious badge with its glyph', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', qualityLabel: 'Auspicious'),
        themeKey: 'travel', // not a favorable day for travel, keeps the ruler line out of the way
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('✦'), findsOneWidget);
      expect(find.textContaining('Auspicious'), findsOneWidget);
    });

    testWidgets('shows the Favorable badge with its glyph', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', qualityLabel: 'Favorable'),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('◆'), findsOneWidget);
    });

    testWidgets('shows the Best Available badge with its glyph', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', qualityLabel: 'Best Available'),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('◇'), findsOneWidget);
    });

    testWidgets('shows humanized best time, not raw HH:MM', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', bestTime: '07:15', qualityLabel: 'Favorable'),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('early morning'), findsOneWidget);
      expect(find.textContaining('07:15'), findsNothing);
    });

    testWidgets('shows the day-ruler line on a favorable weekday for the theme', (tester) async {
      // 2026-01-02 is a Friday -- favorable for love_relationships (Venus).
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-01-02', qualityLabel: 'Favorable'),
        themeKey: 'love_relationships',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('Ruled by Venus'), findsOneWidget);
    });

    testWidgets('hides the day-ruler line on a non-favorable weekday for the theme', (tester) async {
      // 2026-01-06 is a Tuesday -- not favorable for love_relationships.
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-01-06', qualityLabel: 'Favorable'),
        themeKey: 'love_relationships',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('Ruled by'), findsNothing);
    });

    testWidgets('tapping the tile expands it and shows the synthesis text', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', qualityLabel: 'Favorable'),
        themeKey: 'travel',
        synthesis: 'A very specific synthesis sentence for this test.',
      )));
      expect(find.text('A very specific synthesis sentence for this test.'), findsNothing);
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(find.text('A very specific synthesis sentence for this test.'), findsOneWidget);
    });

    testWidgets('expanding planetary details merges direct+antiscion hits into one row', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [
            hit(planet: 'Jupiter', house: 7, aspect: 'trine', mode: 'direct', score: 0.9),
            hit(planet: 'Jupiter', house: 7, aspect: 'sextile', mode: 'antiscion', score: 0.5),
          ],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      // Expand the tile, then expand planetary details.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('direct + antiscion'), findsOneWidget);
      expect(find.text('direct'), findsNothing);
      expect(find.text('antiscion'), findsNothing);
    });

    testWidgets('a benefic trine hit shows the gold star in planetary details', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [hit(planet: 'Venus', house: 5, aspect: 'trine', mode: 'direct')],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('★'), findsOneWidget);
    });

    testWidgets('a malefic square hit shows the warning triangle in planetary details', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [hit(planet: 'Mars', house: 5, aspect: 'square', mode: 'direct')],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('△'), findsOneWidget);
    });

    testWidgets('a cazimi hit shows the gold badge and explanatory subtitle in planetary details', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [hit(planet: 'Venus', house: 5, aspect: 'conjunction', mode: 'direct', isCazimi: true)],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('☀ Cazimi'), findsOneWidget);
      expect(
        find.textContaining('in the heart of the Sun'),
        findsOneWidget,
      );
    });

    testWidgets('a non-cazimi hit does not show the cazimi badge or subtitle', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [hit(planet: 'Venus', house: 5, aspect: 'trine', mode: 'direct', isCazimi: false)],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('☀ Cazimi'), findsNothing);
      expect(find.textContaining('in the heart of the Sun'), findsNothing);
    });

    testWidgets('shows the reasons a day qualifies without needing to expand', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          reasons: ['The Moon is waxing, traditionally a time of growth and increase'],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      // Not gated behind the expand tap -- visible immediately.
      expect(find.textContaining('The Moon is waxing'), findsOneWidget);
    });

    testWidgets('shows a fallback message when there are no positive reasons (Best Available)', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(date: '2026-07-10', qualityLabel: 'Best Available', reasons: []),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      expect(find.textContaining('Meets the essential requirements'), findsOneWidget);
    });

    testWidgets('splits hits into Supporting aspects and Present but not counted sections', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [
            hit(planet: 'Jupiter', house: 9, aspect: 'trine', isSupporting: true),
            hit(planet: 'Sun', house: 9, aspect: 'square', isSupporting: false),
          ],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('Supporting aspects'), findsOneWidget);
      expect(find.text('Present but not counted'), findsOneWidget);
    });

    testWidgets('a direct/antiscion pair split across supporting and not-counted is not merged', (tester) async {
      // If only one mode of a direct+antiscion pair actually counted toward
      // the day's classification, merging them into a single "direct +
      // antiscion" line would misrepresent which one mattered -- they
      // should land in separate sections instead, unmerged.
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Favorable',
          hits: [
            hit(planet: 'Jupiter', house: 9, aspect: 'trine', mode: 'direct', isSupporting: true),
            hit(planet: 'Jupiter', house: 9, aspect: 'sextile', mode: 'antiscion', isSupporting: false),
          ],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('direct + antiscion'), findsNothing);
      expect(find.text('direct'), findsOneWidget);
      expect(find.text('antiscion'), findsOneWidget);
    });

    testWidgets('omits the Supporting aspects header when nothing supports the day', (tester) async {
      await tester.pumpWidget(wrap(DayTile(
        rank: 1,
        day: day(
          date: '2026-07-10',
          qualityLabel: 'Best Available',
          reasons: [],
          hits: [hit(planet: 'Sun', house: 9, aspect: 'square', isSupporting: false)],
        ),
        themeKey: 'travel',
        synthesis: 'Test synthesis text.',
      )));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.text('Planetary details'));
      await tester.pump();
      expect(find.text('Supporting aspects'), findsNothing);
      expect(find.text('Present but not counted'), findsOneWidget);
    });
  });
}
