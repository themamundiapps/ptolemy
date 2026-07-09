import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/birth_data.dart';
import '../models/chart_models.dart';
import '../screens/birth_data_screen.dart';
import '../screens/chart_result_screen.dart';
import '../screens/onboarding_screen.dart';
import 'api_client.dart';
import 'error_messages.dart';
import 'storage_service.dart';

/// Central place for the "what screen comes next" decisions that Session 9
/// introduces -- used both by the startup screen (returning app open) and
/// by the welcome screen (right after a fresh sign-in), so the two paths
/// can't drift apart.
class AppFlow {
  static void _replace(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  /// Persists a freshly-calculated chart to the local cache and, for
  /// signed-in Google users, best-effort backs it up to the backend too --
  /// a failure here doesn't block navigation since the local cache already
  /// holds the chart.
  static Future<void> saveChartAfterCalculation(BirthData birthData, ChartResponse chart) async {
    await StorageService.saveChart(birthData, chart);
    final session = await StorageService.loadSession();
    if (session != null && session.mode == AuthMode.google && session.googleId != null) {
      try {
        await ApiClient(baseUrl: defaultBaseUrl()).saveUserChart(googleId: session.googleId!, birthData: birthData);
      } catch (_) {}
    }
  }

  /// After a fresh sign-in, or on every app open for a returning user: loads
  /// a saved chart if one exists (local cache first, then the backend for
  /// Google accounts with no local cache -- e.g. a new device), otherwise
  /// routes to onboarding (shown only once ever) and then the birth data
  /// form.
  static Future<void> goToChartOrBirthData(BuildContext context) async {
    final cachedChart = await StorageService.loadCachedChart();
    final cachedBirthData = await StorageService.loadBirthData();
    if (cachedChart != null && cachedBirthData != null) {
      if (!context.mounted) return;
      _replace(
        context,
        ChartResultScreen(
          result: cachedChart,
          birthDate: cachedBirthData.date,
          birthTime: cachedBirthData.time,
          latitude: cachedBirthData.latitude,
          longitude: cachedBirthData.longitude,
        ),
      );
      return;
    }

    String? loadError;
    final session = await StorageService.loadSession();
    if (session != null && session.mode == AuthMode.google && session.googleId != null) {
      try {
        final client = ApiClient(baseUrl: defaultBaseUrl());
        final birthData = await client.fetchUserChart(googleId: session.googleId!);
        if (birthData != null) {
          final chart = await client.fetchPositions(
            date: birthData.date,
            time: birthData.time,
            latitude: birthData.latitude,
            longitude: birthData.longitude,
            tzOffset: birthData.tzOffset,
          );
          await StorageService.saveChart(birthData, chart);
          if (!context.mounted) return;
          _replace(
            context,
            ChartResultScreen(
              result: chart,
              birthDate: birthData.date,
              birthTime: birthData.time,
              latitude: birthData.latitude,
              longitude: birthData.longitude,
            ),
          );
          return;
        }
      } catch (e) {
        loadError = friendlyApiError(e);
      }
    }

    final seen = await StorageService.hasSeenOnboarding();
    if (!context.mounted) return;
    if (!seen) {
      _replace(context, OnboardingScreen(loadError: loadError));
    } else {
      _replace(context, BirthDataScreen(loadError: loadError));
    }
  }
}
