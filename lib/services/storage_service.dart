import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/birth_data.dart';
import '../models/chart_models.dart';

/// Wraps shared_preferences for the three bits of on-device state Session 9
/// needs to persist: whether onboarding has been shown, the current sign-in
/// session (Google or guest), and the last-computed chart (kept alongside
/// the birth data that produced it, since the chart screen also needs the
/// raw date/time/lat/long that aren't reconstructable from ChartResponse).
class StorageService {
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kAuthMode = 'auth_mode';
  static const _kGoogleId = 'google_id';
  static const _kGoogleName = 'google_name';
  static const _kGoogleEmail = 'google_email';
  static const _kBirthDataJson = 'birth_data_json';
  static const _kChartJson = 'chart_json';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<bool> hasSeenOnboarding() async => (await _prefs).getBool(_kOnboardingSeen) ?? false;

  static Future<void> setOnboardingSeen() async => (await _prefs).setBool(_kOnboardingSeen, true);

  static Future<AuthSession?> loadSession() async {
    final prefs = await _prefs;
    final mode = prefs.getString(_kAuthMode);
    if (mode == 'google') {
      final id = prefs.getString(_kGoogleId);
      if (id == null) return null;
      return AuthSession.google(
        googleId: id,
        googleName: prefs.getString(_kGoogleName) ?? '',
        googleEmail: prefs.getString(_kGoogleEmail) ?? '',
      );
    }
    if (mode == 'guest') return const AuthSession.guest();
    return null;
  }

  static Future<void> saveGoogleSession({required String id, required String name, required String email}) async {
    final prefs = await _prefs;
    await prefs.setString(_kAuthMode, 'google');
    await prefs.setString(_kGoogleId, id);
    await prefs.setString(_kGoogleName, name);
    await prefs.setString(_kGoogleEmail, email);
  }

  static Future<void> saveGuestSession() async => (await _prefs).setString(_kAuthMode, 'guest');

  static Future<BirthData?> loadBirthData() async {
    final raw = (await _prefs).getString(_kBirthDataJson);
    if (raw == null) return null;
    return BirthData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<ChartResponse?> loadCachedChart() async {
    final raw = (await _prefs).getString(_kChartJson);
    if (raw == null) return null;
    return ChartResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveChart(BirthData birthData, ChartResponse chart) async {
    final prefs = await _prefs;
    await prefs.setString(_kBirthDataJson, jsonEncode(birthData.toJson()));
    await prefs.setString(_kChartJson, jsonEncode(chart.toJson()));
  }

  static Future<void> clearChart() async {
    final prefs = await _prefs;
    await prefs.remove(_kBirthDataJson);
    await prefs.remove(_kChartJson);
  }
}
