import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/transits_tab.dart';
import 'package:ptolemy/services/api_client.dart';

ZodiacPosition _pos(double longitude) => ZodiacPosition(
  longitude: longitude,
  sign: 'Aries',
  signLongitude: longitude % 30,
  house: 1,
  retrograde: false,
  dignities: const [],
);

ChartResponse _natalChart() {
  return ChartResponse(
    julianDayUt: 0,
    sect: 'diurnal',
    timezoneId: null,
    utcOffsetUsed: 0,
    tzSource: 'auto',
    ascendant: _pos(0),
    midheaven: _pos(270),
    planets: {
      for (final name in ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']) name: _pos(0),
    },
    lotOfFortune: _pos(200),
    lotOfSpirit: _pos(220),
    aspects: const [],
  );
}

// Deliberately unreachable (port 1 is never a live HTTP server) so the
// transits fetch fails fast with a connection error -- but note that per
// this project's flutter-test HTTP limitation (see chart_wheel_test.dart's
// neighbors and CLAUDE-level dev notes), ANY real HttpClient call inside
// flutter test is forced to fail regardless of target host, so this only
// ever exercises the fallback/error path, never the real success path.
final _unreachableClient = ApiClient(baseUrl: 'http://127.0.0.1:1');

Widget _harness() {
  return MaterialApp(
    home: Scaffold(
      body: TransitsTab(
        result: _natalChart(),
        birthDate: '1990-06-15',
        birthTime: '14:30',
        latitude: -25.4284,
        longitude: -49.2733,
        apiClient: _unreachableClient,
      ),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator immediately after opening', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows fallback text when the transits fetch fails', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text("Could not calculate today's transits."), findsOneWidget);
  });
}
