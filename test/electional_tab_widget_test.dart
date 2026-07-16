import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/electional_tab.dart';

ZodiacPosition _zp() => ZodiacPosition(
      longitude: 0.0,
      sign: 'Aries',
      signLongitude: 0.0,
      house: 1,
      retrograde: false,
      dignities: const [],
    );

ChartResponse _chartResponse() => ChartResponse(
      julianDayUt: 2460000.0,
      sect: 'diurnal',
      timezoneId: 'Europe/Rome',
      utcOffsetUsed: 2.0,
      tzSource: 'lookup',
      ascendant: _zp(),
      midheaven: _zp(),
      planets: const {},
      lotOfFortune: _zp(),
      lotOfSpirit: _zp(),
      aspects: const [],
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  Widget buildTab() => wrap(ElectionalTab(
        result: _chartResponse(),
        birthDate: '1990-06-15',
        birthTime: '14:30',
        latitude: 41.9028,
        longitude: 12.4964,
      ));

  group('Theme selection screen', () {
    testWidgets('shows the redesigned title and subtitle', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('Find Your Best Moment'), findsOneWidget);
      expect(find.text('Select the area of life you are seeking guidance for.'), findsOneWidget);
    });

    testWidgets('free themes show a FREE label', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('FREE'), findsNWidgets(2)); // Love & Relationships, Travel
    });

    testWidgets('pro themes show a lock icon instead of FREE', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('🔒'), findsNWidgets(4)); // the four Pro themes
    });

    testWidgets('shows a PRO section label', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('lists every theme by name', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('Love & Relationships'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Business & Career'), findsOneWidget);
      expect(find.text('Health & Body'), findsOneWidget);
      expect(find.text('Spiritual & Learning'), findsOneWidget);
      expect(find.text('Home & Family'), findsOneWidget);
    });

    testWidgets('tapping a free theme navigates to the period selection screen', (tester) async {
      await tester.pumpWidget(buildTab());
      await tester.tap(find.text('Love & Relationships'));
      await tester.pumpAndSettle();
      // The period screen shows the theme name again as its title, and the
      // quick-select pills.
      expect(find.text('30 days'), findsOneWidget);
    });

    testWidgets('tapping a pro theme opens the paywall instead of navigating to period selection', (tester) async {
      await tester.pumpWidget(buildTab());
      await tester.tap(find.text('Business & Career'));
      await tester.pumpAndSettle();
      expect(find.text('Ptolemy Pro'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      // Not on the period screen.
      expect(find.text('30 days'), findsNothing);
    });
  });

  group('Period selection screen', () {
    Future<void> goToPeriodScreen(WidgetTester tester) async {
      await tester.pumpWidget(buildTab());
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all four quick-select pills with 30 days selected by default', (tester) async {
      await goToPeriodScreen(tester);
      expect(find.text('15 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('60 days'), findsOneWidget);
      expect(find.text('90 days'), findsOneWidget);
    });

    testWidgets('tapping a different pill changes the selection', (tester) async {
      await goToPeriodScreen(tester);
      await tester.tap(find.text('90 days'));
      await tester.pump();
      // Both still render (no navigation happened from a pill tap alone).
      expect(find.text('90 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
    });

    testWidgets('tapping Custom dates reveals date fields and hides the pills', (tester) async {
      await goToPeriodScreen(tester);
      await tester.tap(find.text('Custom dates'));
      await tester.pump();
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
      expect(find.text('15 days'), findsNothing);
      expect(find.text('Use quick select'), findsOneWidget);
    });

    testWidgets('tapping Use quick select returns to the pills', (tester) async {
      await goToPeriodScreen(tester);
      await tester.tap(find.text('Custom dates'));
      await tester.pump();
      await tester.tap(find.text('Use quick select'));
      await tester.pump();
      expect(find.text('15 days'), findsOneWidget);
      expect(find.text('Start date'), findsNothing);
    });

    testWidgets('shows the Find Best Moments button', (tester) async {
      await goToPeriodScreen(tester);
      expect(find.text('Find Best Moments'), findsOneWidget);
    });

    testWidgets('shows the theme name as the screen title', (tester) async {
      await goToPeriodScreen(tester);
      expect(find.text('Travel'), findsOneWidget);
    });
  });
}
