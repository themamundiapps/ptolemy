import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels local "auspicious moment" reminders for electional
/// results, and tracks (via shared_preferences) which day/theme combos
/// currently have one set, so the UI can show a bell indicator.
///
/// Uses [AndroidScheduleMode.inexactAllowWhileIdle] rather than an exact
/// alarm mode -- a reminder firing within a few minutes of the requested
/// time is entirely acceptable for this feature, and it avoids requiring
/// the user to grant the separate "exact alarm" permission (Android 12+),
/// which carries its own Play Store policy restrictions.
class ReminderService {
  /// The real, plugin-backed instance used throughout the app. A plain
  /// (non-private) constructor is used -- rather than a private one -- so
  /// widget tests can extend this class with a fake in-memory
  /// implementation and inject it via DayTile's optional reminderService
  /// param, since flutter_test has no platform channel for the real
  /// notification/shared_preferences plugins to call into.
  static final ReminderService instance = ReminderService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Requests Android 13+'s runtime POST_NOTIFICATIONS permission. Returns
  /// true on any platform where no explicit runtime grant is needed (older
  /// Android, non-Android platforms).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  int _idFor(String themeKey, String date) => '$themeKey|$date'.hashCode & 0x7fffffff;

  String _prefsKey(String themeKey, String date) => 'reminder_$themeKey|$date';

  /// Schedules a reminder for [date] (ISO "YYYY-MM-DD") at [time], local to
  /// this device. Throws if the resulting moment has already passed.
  ///
  /// [DateTime]'s local constructor already accounts for the device's
  /// timezone (including DST), so its millisecondsSinceEpoch is already the
  /// correct absolute instant to fire at -- wrapping it in a TZDateTime via
  /// `.from()` (which preserves that instant regardless of which Location
  /// it's tagged with) satisfies the plugin's API without needing to look
  /// up the device's IANA timezone name separately.
  Future<void> scheduleReminder({
    required String themeKey,
    required String themeLabel,
    required String date,
    required TimeOfDay time,
  }) async {
    await _ensureInitialized();
    final parts = date.split('-').map(int.parse).toList();
    final localMoment = DateTime(parts[0], parts[1], parts[2], time.hour, time.minute);
    if (localMoment.isBefore(DateTime.now())) {
      throw StateError('That time has already passed.');
    }
    final scheduled = tz.TZDateTime.from(localMoment, tz.UTC);

    await _plugin.zonedSchedule(
      id: _idFor(themeKey, date),
      scheduledDate: scheduled,
      title: 'Ptolemy',
      body: '✦ Your auspicious moment for $themeLabel — the chart favors action now. — Ptolemy',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'electional_reminders',
          'Electional Reminders',
          channelDescription: 'Reminders for auspicious electional moments you\'ve set in Ptolemy',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey(themeKey, date), scheduled.millisecondsSinceEpoch);
  }

  Future<void> cancelReminder({required String themeKey, required String date}) async {
    await _ensureInitialized();
    await _plugin.cancel(id: _idFor(themeKey, date));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(themeKey, date));
  }

  /// False on any failure (including running somewhere shared_preferences
  /// has no platform implementation, e.g. an unmocked test) rather than
  /// throwing -- the bell indicator simply stays hidden in that case.
  Future<bool> isReminderSet({required String themeKey, required String date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_prefsKey(themeKey, date));
    } catch (_) {
      return false;
    }
  }
}
