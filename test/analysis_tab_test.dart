import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ptolemy/screens/analysis_tab.dart';
import 'package:ptolemy/services/api_client.dart';
import 'package:ptolemy/services/storage_service.dart';

// Deliberately unreachable (port 1 is never a live HTTP server) so the
// analysis fetch fails fast with a connection error, exercising the
// generate-failure path deterministically without a live backend -- same
// pattern as aspect_detail_sheet_test.dart / planet_detail_sheet_test.dart.
final _unreachableClient = ApiClient(baseUrl: 'http://127.0.0.1:1');

/// A fetch that only resolves when the test tells it to, via [completer] --
/// needed because flutter_test's forced-400 fake HTTP response resolves
/// fast enough to complete within the same pump() as the triggering tap,
/// making the transient loading state otherwise unobservable in a test.
class _DeferredApiClient extends ApiClient {
  final Completer<String> completer = Completer<String>();
  _DeferredApiClient() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<String> fetchChartAnalysis({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    double? tzOffset,
  }) => completer.future;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the title and a Generate button when nothing is cached', (tester) async {
    await tester.pumpWidget(_wrap(AnalysisTab(
      birthDate: '1990-06-15',
      birthTime: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
      apiClient: _unreachableClient,
    )));
    await tester.pump();

    expect(find.text('Chart Analysis'), findsOneWidget);
    expect(find.text('Generate My Reading'), findsOneWidget);
    expect(find.text('This may take a moment'), findsOneWidget);
    expect(find.text('Regenerate ↺'), findsNothing);
  });

  testWidgets('tapping Generate shows a loading state, then falls back to an error message on failure', (tester) async {
    final deferred = _DeferredApiClient();
    await tester.pumpWidget(_wrap(AnalysisTab(
      birthDate: '1990-06-15',
      birthTime: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
      apiClient: deferred,
    )));
    await tester.pump();

    await tester.tap(find.text('Generate My Reading'));
    await tester.pump();
    expect(find.text('Ptolemy is reading your chart...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    deferred.completer.completeError(ApiException('connection refused'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not generate a reading'), findsOneWidget);
    expect(find.text('Generate My Reading'), findsOneWidget);
  });

  testWidgets('a real (fast-failing) fetch eventually shows the error message', (tester) async {
    await tester.pumpWidget(_wrap(AnalysisTab(
      birthDate: '1990-06-15',
      birthTime: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
      apiClient: _unreachableClient,
    )));
    await tester.pump();

    await tester.tap(find.text('Generate My Reading'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not generate a reading'), findsOneWidget);
    expect(find.text('Generate My Reading'), findsOneWidget);
  });

  testWidgets('a cached reading for this exact chart is shown immediately, without calling the API', (tester) async {
    final chartKey = StorageService.chartAnalysisKey(
      date: '1990-06-15',
      time: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
    );
    SharedPreferences.setMockInitialValues({
      'chart_analysis_chart_key': chartKey,
      'chart_analysis_text': 'A cached reading of this specific nativity.',
    });

    await tester.pumpWidget(_wrap(AnalysisTab(
      birthDate: '1990-06-15',
      birthTime: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
      apiClient: _unreachableClient,
    )));
    await tester.pump();
    await tester.pump();

    expect(find.text('A cached reading of this specific nativity.'), findsOneWidget);
    expect(find.text('Generate My Reading'), findsNothing);
    expect(find.text('Regenerate ↺'), findsOneWidget);
  });

  testWidgets('a cached reading for a different chart is not shown', (tester) async {
    SharedPreferences.setMockInitialValues({
      'chart_analysis_chart_key': StorageService.chartAnalysisKey(
        date: '2000-01-01',
        time: '00:00',
        latitude: 0,
        longitude: 0,
      ),
      'chart_analysis_text': 'A reading for a totally different chart.',
    });

    await tester.pumpWidget(_wrap(AnalysisTab(
      birthDate: '1990-06-15',
      birthTime: '14:30',
      latitude: -25.4284,
      longitude: -49.2733,
      apiClient: _unreachableClient,
    )));
    await tester.pump();
    await tester.pump();

    expect(find.text('A reading for a totally different chart.'), findsNothing);
    expect(find.text('Generate My Reading'), findsOneWidget);
  });
}
