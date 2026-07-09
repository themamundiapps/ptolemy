import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/services/api_client.dart';
import 'package:ptolemy/widgets/aspect_detail_sheet.dart';

Aspect _aspect({
  String planetA = 'Venus',
  String planetB = 'Saturn',
  String aspect = 'trine',
  double orb = 1.23,
}) {
  return Aspect(planetA: planetA, planetB: planetB, aspect: aspect, angle: 120.0, orb: orb);
}

// Deliberately unreachable (port 1 is never a live HTTP server) so the
// interpretation fetch fails fast with a connection error, letting tests
// exercise the fallback-text path deterministically without a live backend.
final _unreachableClient = ApiClient(baseUrl: 'http://127.0.0.1:1');

void main() {
  Future<void> openSheet(WidgetTester tester, Aspect aspect, {ApiClient? apiClient}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAspectDetailSheet(
              context,
              apiClient: apiClient ?? _unreachableClient,
              aspect: aspect,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  group('Lot short-circuit (no network call)', () {
    testWidgets('Lot of Fortune shows the fixed fortune text', (tester) async {
      await openSheet(tester, _aspect(planetA: 'Lot of Fortune', planetB: 'Sun', aspect: 'trine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('material fortune and bodily wellbeing'), findsOneWidget);
    });

    testWidgets('Lot of Spirit shows the fixed spirit text', (tester) async {
      await openSheet(tester, _aspect(planetA: 'Moon', planetB: 'Lot of Spirit', aspect: 'square'));
      await tester.pumpAndSettle();
      expect(find.textContaining("soul's intention and conscious action"), findsOneWidget);
    });

    testWidgets('Lot pair does not show an intro line or orb text', (tester) async {
      await openSheet(tester, _aspect(planetA: 'Lot of Fortune', planetB: 'Sun', aspect: 'trine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Orb:'), findsNothing);
      expect(find.textContaining('natural flow'), findsNothing);
    });

    testWidgets('Lot pair header still shows both names and the symbol', (tester) async {
      await openSheet(tester, _aspect(planetA: 'Lot of Fortune', planetB: 'Sun', aspect: 'trine'));
      await tester.pumpAndSettle();
      expect(find.text('Lot of Fortune △ Sun'), findsOneWidget);
    });
  });

  group('Header', () {
    testWidgets('shows "PlanetA symbol PlanetB" in the example format', (tester) async {
      await openSheet(tester, _aspect(planetA: 'Venus', planetB: 'Saturn', aspect: 'trine'));
      expect(find.text('Venus △ Saturn'), findsOneWidget);
    });

    testWidgets('uses the conjunction glyph', (tester) async {
      await openSheet(tester, _aspect(aspect: 'conjunction'));
      expect(find.text('Venus ☌ Saturn'), findsOneWidget);
    });

    testWidgets('uses the sextile glyph', (tester) async {
      await openSheet(tester, _aspect(aspect: 'sextile'));
      expect(find.text('Venus ⚹ Saturn'), findsOneWidget);
    });

    testWidgets('uses the square glyph', (tester) async {
      await openSheet(tester, _aspect(aspect: 'square'));
      expect(find.text('Venus □ Saturn'), findsOneWidget);
    });

    testWidgets('uses the opposition glyph', (tester) async {
      await openSheet(tester, _aspect(aspect: 'opposition'));
      expect(find.text('Venus ☍ Saturn'), findsOneWidget);
    });
  });

  group('Aspect-type introduction line', () {
    testWidgets('conjunction', (tester) async {
      await openSheet(tester, _aspect(aspect: 'conjunction'));
      expect(
        find.text('A conjunction fuses these two principles into a single, undivided force.'),
        findsOneWidget,
      );
    });

    testWidgets('sextile', (tester) async {
      await openSheet(tester, _aspect(aspect: 'sextile'));
      expect(
        find.text('A sextile creates cooperative opportunity between these two principles.'),
        findsOneWidget,
      );
    });

    testWidgets('square', (tester) async {
      await openSheet(tester, _aspect(aspect: 'square'));
      expect(
        find.text('A square creates tension and friction between these two principles that demands resolution.'),
        findsOneWidget,
      );
    });

    testWidgets('trine', (tester) async {
      await openSheet(tester, _aspect(aspect: 'trine'));
      expect(
        find.text('A trine connects these two principles with ease and natural flow.'),
        findsOneWidget,
      );
    });

    testWidgets('opposition', (tester) async {
      await openSheet(tester, _aspect(aspect: 'opposition'));
      expect(
        find.text('An opposition places these two principles in direct confrontation across the chart.'),
        findsOneWidget,
      );
    });
  });

  group('Orb', () {
    testWidgets('shows the orb rounded to one decimal place', (tester) async {
      await openSheet(tester, _aspect(orb: 2.567));
      expect(find.text('Orb: 2.6°'), findsOneWidget);
    });

    testWidgets('shows a tidy value for an already-round orb', (tester) async {
      await openSheet(tester, _aspect(orb: 0.0));
      expect(find.text('Orb: 0.0°'), findsOneWidget);
    });
  });

  group('Interpretation fetch states', () {
    testWidgets('shows a loading indicator immediately after opening', (tester) async {
      await openSheet(tester, _aspect());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the specific fallback text when the fetch fails', (tester) async {
      await openSheet(tester, _aspect());
      await tester.pumpAndSettle();
      expect(find.text('Interpretation for this aspect pair is coming in a future update.'), findsOneWidget);
    });
  });
}
