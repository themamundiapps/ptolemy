import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/services/api_client.dart';
import 'package:ptolemy/services/billing_service.dart';
import 'package:ptolemy/widgets/planet_detail_sheet.dart';

ZodiacPosition _pos({
  double longitude = 40,
  String sign = 'Taurus',
  double signLongitude = 10,
  int house = 2,
  bool retrograde = false,
  List<String> dignities = const [],
}) {
  return ZodiacPosition(
    longitude: longitude,
    sign: sign,
    signLongitude: signLongitude,
    house: house,
    retrograde: retrograde,
    dignities: dignities,
  );
}

ChartResponse _chart({String sect = 'diurnal', List<Aspect> aspects = const []}) {
  return ChartResponse(
    julianDayUt: 0,
    sect: sect,
    timezoneId: null,
    utcOffsetUsed: 0,
    tzSource: 'auto',
    ascendant: _pos(longitude: 0, sign: 'Aries', house: 1),
    midheaven: _pos(longitude: 270, sign: 'Capricorn', house: 10),
    planets: {
      'Sun': _pos(longitude: 100, sign: 'Cancer', house: 4),
      'Moon': _pos(longitude: 200, sign: 'Libra', house: 7),
      'Venus': _pos(longitude: 40, sign: 'Taurus', house: 2, dignities: const ['domicile']),
    },
    lotOfFortune: _pos(longitude: 50, sign: 'Taurus', house: 2),
    lotOfSpirit: _pos(longitude: 60, sign: 'Gemini', house: 3),
    aspects: aspects,
  );
}

// Deliberately unreachable (port 1 is never a live HTTP server) so every
// fetch fails fast with a connection error, exercising the fallback path
// deterministically without a live backend -- same pattern as
// aspect_detail_sheet_test.dart.
final _unreachableClient = ApiClient(baseUrl: 'http://127.0.0.1:1');

void main() {
  setUp(() {
    // showPlanetDetailSheet now resolves a user id (Google id or a
    // persisted device id) via StorageService before fetching Personal
    // Synthesis -- without a mocked SharedPreferences, that platform
    // channel call never resolves and pumpAndSettle hangs.
    SharedPreferences.setMockInitialValues({});
    // Personal Synthesis is Pro-gated; these tests exercise the unlocked
    // content, not the paywall lock card (that's covered separately).
    BillingService.instance.debugIsProOverride = true;
  });

  tearDown(() {
    BillingService.instance.debugIsProOverride = null;
  });

  Future<void> openSheet(WidgetTester tester, {ChartResponse? result, String planetName = 'Venus'}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPlanetDetailSheet(
              context,
              apiClient: _unreachableClient,
              result: result ?? _chart(),
              planetName: planetName,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  testWidgets('shows "Personal Synthesis" (not just "Synthesis")', (tester) async {
    await openSheet(tester);
    expect(find.text('Personal Synthesis'), findsOneWidget);
    expect(find.text('Synthesis'), findsNothing);
  });

  testWidgets('Personal Synthesis is the first section, above the sign and house interpretations', (tester) async {
    await openSheet(tester);

    final synthesisTop = tester.getTopLeft(find.text('Personal Synthesis')).dy;
    final signSectionTop = tester.getTopLeft(find.text('Venus in Taurus')).dy;
    final houseSectionTop = tester.getTopLeft(find.text('Venus in House 2')).dy;

    expect(synthesisTop, lessThan(signSectionTop));
    expect(synthesisTop, lessThan(houseSectionTop));
    expect(signSectionTop, lessThan(houseSectionTop));
  });

  testWidgets('Personal Synthesis shows a loading indicator immediately after opening', (tester) async {
    await openSheet(tester);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('Personal Synthesis falls back to an unavailable message when the fetch fails', (tester) async {
    await openSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text('Calculations temporarily unavailable — please try again shortly.'), findsOneWidget);
  });

  testWidgets('still shows the free sign and house interpretation titles', (tester) async {
    await openSheet(tester);
    expect(find.text('Venus in Taurus'), findsOneWidget);
    expect(find.text('Venus in House 2'), findsOneWidget);
  });

  testWidgets('shows the paywall lock instead of a synthesis fetch when the user is not Pro', (tester) async {
    BillingService.instance.debugIsProOverride = false;
    await openSheet(tester);
    expect(find.text('Unlock with Pro'), findsOneWidget);
    // Still shows the free sections underneath the lock.
    expect(find.text('Venus in Taurus'), findsOneWidget);
  });
}
