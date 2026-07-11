import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptolemy/models/chart_models.dart';
import 'package:ptolemy/screens/electional_tab.dart';
import 'package:ptolemy/services/reminder_service.dart';

/// In-memory fake so reminder interactions can be tested deterministically
/// -- flutter_test has no platform channel for the real notification or
/// shared_preferences plugins to call into.
class _FakeReminderService extends ReminderService {
  final Set<String> _set = {};
  bool grantPermission = true;
  String? lastScheduledThemeLabel;

  String _key(String themeKey, String date) => '$themeKey|$date';

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  Future<void> scheduleReminder({
    required String themeKey,
    required String themeLabel,
    required String date,
    required TimeOfDay time,
  }) async {
    lastScheduledThemeLabel = themeLabel;
    _set.add(_key(themeKey, date));
  }

  @override
  Future<void> cancelReminder({required String themeKey, required String date}) async {
    _set.remove(_key(themeKey, date));
  }

  @override
  Future<bool> isReminderSet({required String themeKey, required String date}) async =>
      _set.contains(_key(themeKey, date));
}

ElectionalDay _day({String date = '2026-07-10', String bestTime = '18:00', String qualityLabel = 'Favorable'}) {
  return ElectionalDay(
    date: date,
    bestTime: bestTime,
    qualityLabel: qualityLabel,
    reasons: const ['Test reason'],
    hits: const [],
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('no bell icon shown before a reminder is set', (tester) async {
    final fake = _FakeReminderService();
    await tester.pumpWidget(_wrap(DayTile(
      rank: 1,
      day: _day(),
      themeKey: 'travel',
      themeLabel: 'Travel',
      synthesis: 'Test synthesis.',
      reminderService: fake,
    )));
    await tester.pump();
    expect(find.text('🔔'), findsNothing);
  });

  testWidgets('tapping Add Reminder, then confirming a time, schedules a reminder and shows the bell', (tester) async {
    final fake = _FakeReminderService();
    await tester.pumpWidget(_wrap(DayTile(
      rank: 1,
      day: _day(),
      themeKey: 'travel',
      themeLabel: 'Travel',
      synthesis: 'Test synthesis.',
      reminderService: fake,
    )));
    await tester.pump();

    // Expand the card, then tap "Add Reminder".
    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    expect(find.text('Add Reminder'), findsOneWidget);

    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();

    // The time picker dialog should be open, pre-filled from bestTime
    // ("18:00" -> 6:00 PM). Confirm it.
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(fake.lastScheduledThemeLabel, 'Travel');
    expect(find.text('🔔'), findsOneWidget);
    expect(find.text('Update Reminder'), findsOneWidget);
  });

  testWidgets('denied notification permission shows a message and does not schedule', (tester) async {
    final fake = _FakeReminderService()..grantPermission = false;
    await tester.pumpWidget(_wrap(DayTile(
      rank: 1,
      day: _day(),
      themeKey: 'travel',
      themeLabel: 'Travel',
      synthesis: 'Test synthesis.',
      reminderService: fake,
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    await tester.tap(find.text('Add Reminder'));
    await tester.pump();

    expect(find.textContaining('Notification permission is required'), findsOneWidget);
    expect(find.text('🔔'), findsNothing);
  });

  testWidgets('tapping the bell then confirming cancels the reminder', (tester) async {
    final fake = _FakeReminderService();
    await fake.scheduleReminder(
      themeKey: 'travel',
      themeLabel: 'Travel',
      date: '2026-07-10',
      time: const TimeOfDay(hour: 18, minute: 0),
    );

    await tester.pumpWidget(_wrap(DayTile(
      rank: 1,
      day: _day(),
      themeKey: 'travel',
      themeLabel: 'Travel',
      synthesis: 'Test synthesis.',
      reminderService: fake,
    )));
    // Let the async initState load of isReminderSet resolve.
    await tester.pump();
    await tester.pump();

    expect(find.text('🔔'), findsOneWidget);
    await tester.tap(find.text('🔔'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel reminder?'), findsOneWidget);
    await tester.tap(find.text('Cancel reminder'));
    await tester.pumpAndSettle();

    expect(find.text('🔔'), findsNothing);
    expect(await fake.isReminderSet(themeKey: 'travel', date: '2026-07-10'), isFalse);
  });

  testWidgets('tapping the bell then "Keep it" leaves the reminder in place', (tester) async {
    final fake = _FakeReminderService();
    await fake.scheduleReminder(
      themeKey: 'travel',
      themeLabel: 'Travel',
      date: '2026-07-10',
      time: const TimeOfDay(hour: 18, minute: 0),
    );

    await tester.pumpWidget(_wrap(DayTile(
      rank: 1,
      day: _day(),
      themeKey: 'travel',
      themeLabel: 'Travel',
      synthesis: 'Test synthesis.',
      reminderService: fake,
    )));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('🔔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(find.text('🔔'), findsOneWidget);
    expect(await fake.isReminderSet(themeKey: 'travel', date: '2026-07-10'), isTrue);
  });
}
