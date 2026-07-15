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
  static const _kAnalysisChartKey = 'chart_analysis_chart_key';
  static const _kAnalysisText = 'chart_analysis_text';

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

  /// Clears everything tied to the current sign-in -- session, cached chart,
  /// and cached analysis -- so a signed-out device behaves like a fresh
  /// install rather than silently reloading the previous account's data if
  /// someone signs back in. Onboarding-seen is deliberately left alone: that
  /// flag is about whether this device has ever seen the intro, not about
  /// which account is signed in.
  static Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_kAuthMode);
    await prefs.remove(_kGoogleId);
    await prefs.remove(_kGoogleName);
    await prefs.remove(_kGoogleEmail);
    await clearChart();
    await clearAnalysis();
  }

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

  /// Identifies which nativity a cached Chart Analysis reading belongs to,
  /// so a stale reading from a previously-viewed chart is never shown
  /// against a different one.
  static String chartAnalysisKey({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
  }) => '$date|$time|$latitude|$longitude';

  /// Returns the cached reading only if it was generated for [chartKey];
  /// otherwise null, so a reading generated for a since-changed birth chart
  /// is never mistaken for a fresh one.
  static Future<String?> loadCachedAnalysis(String chartKey) async {
    final prefs = await _prefs;
    if (prefs.getString(_kAnalysisChartKey) != chartKey) return null;
    return prefs.getString(_kAnalysisText);
  }

  static Future<void> saveAnalysis(String chartKey, String text) async {
    final prefs = await _prefs;
    await prefs.setString(_kAnalysisChartKey, chartKey);
    await prefs.setString(_kAnalysisText, text);
  }

  static Future<void> clearAnalysis() async {
    final prefs = await _prefs;
    await prefs.remove(_kAnalysisChartKey);
    await prefs.remove(_kAnalysisText);
  }
}
