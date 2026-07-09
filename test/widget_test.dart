import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ptolemy/main.dart';

/// AppStartupScreen shows an indeterminate CircularProgressIndicator while
/// it resolves the saved session, which schedules frames forever -- so
/// pumpAndSettle() would time out waiting for it. A few bounded pumps get
/// past the async gap (SharedPreferences + navigation) without that trap.
Future<void> _pumpPastStartup(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Fresh app launch shows the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PtolemyApp());
    await _pumpPastStartup(tester);

    expect(find.text('PTOLEMY'), findsOneWidget);
    expect(find.text('Traditional Astrology Made Simple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Guest Mode'), findsOneWidget);
    expect(find.text('Your chart will be saved on this device only.'), findsOneWidget);
  });

  testWidgets('Guest mode on first launch shows onboarding, then the birth data form', (WidgetTester tester) async {
    await tester.pumpWidget(const PtolemyApp());
    await _pumpPastStartup(tester);

    await tester.tap(find.text('Guest Mode'));
    await _pumpPastStartup(tester);

    expect(find.text('The sky at the moment of your birth was not random.'), findsOneWidget);

    // Swipe through the three onboarding pages to reach "Get Started".
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Three tools. One tradition.'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Ptolemy'), findsOneWidget);
    expect(find.text('Calculate Chart'), findsOneWidget);
    expect(find.text('Birth city'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Time of birth (24h)'), findsOneWidget);
  });
}
