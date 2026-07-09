/// Pure, side-effect-free logic used by the Electional results screen —
/// pulled out of electional_tab.dart specifically so it can be unit tested
/// directly, without needing to pump a widget tree.
library;

import '../models/chart_models.dart';

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Formats an ISO date as "Tuesday, July 8".
String formatDayHeading(String isoDate) {
  final parts = isoDate.split('-').map(int.parse).toList();
  final dt = DateTime(parts[0], parts[1], parts[2]);
  final weekday = weekdayNames[dt.weekday - 1];
  final month = monthNames[dt.month - 1];
  return '$weekday, $month ${dt.day}';
}

/// Converts an ISO time ("17:30") into a humanized time-of-day label.
String humanizedTimeOfDay(String isoTime) {
  final hour = int.parse(isoTime.split(':')[0]);
  if (hour >= 5 && hour <= 8) return 'early morning';
  if (hour >= 9 && hour <= 11) return 'late morning';
  if (hour >= 12 && hour <= 13) return 'midday';
  if (hour >= 14 && hour <= 16) return 'afternoon';
  if (hour >= 17 && hour <= 19) return 'early evening';
  if (hour >= 20 && hour <= 23) return 'night';
  return 'late night';
}

/// Traditional planetary rulers of the days of the week (Chaldean order).
const Map<int, String> dayRulers = {
  DateTime.monday: 'Moon',
  DateTime.tuesday: 'Mars',
  DateTime.wednesday: 'Mercury',
  DateTime.thursday: 'Jupiter',
  DateTime.friday: 'Venus',
  DateTime.saturday: 'Saturn',
  DateTime.sunday: 'Sun',
};

/// Weekdays whose ruling planet is traditionally favorable for each theme.
const Map<String, Set<int>> favorableWeekdaysByTheme = {
  'love_relationships': {DateTime.friday, DateTime.monday},
  'travel': {DateTime.wednesday, DateTime.thursday},
  'business_career': {DateTime.thursday, DateTime.sunday},
  'health_body': {DateTime.sunday, DateTime.thursday},
  'spiritual_learning': {DateTime.thursday, DateTime.monday},
  'home_family': {DateTime.monday, DateTime.friday},
};

const Map<String, String> planetSymbols = {
  'Sun': '☉',
  'Moon': '☽',
  'Mercury': '☿',
  'Venus': '♀',
  'Mars': '♂',
  'Jupiter': '♃',
  'Saturn': '♄',
};

const Map<String, String> aspectSymbols = {
  'conjunction': '☌',
  'sextile': '⚹',
  'square': '□',
  'trine': '△',
  'opposition': '☍',
};

/// Returns the ruling planet's name if [date]'s weekday is favorable for
/// [themeKey], or null if there's nothing worth showing.
String? favorableRulerFor(String themeKey, DateTime date) {
  final favorableDays = favorableWeekdaysByTheme[themeKey];
  if (favorableDays == null || !favorableDays.contains(date.weekday)) return null;
  return dayRulers[date.weekday];
}

const beneficPlanets = {'Venus', 'Jupiter'};
const harmoniousAspects = {'trine', 'sextile', 'conjunction'};
const tenseAspects = {'square', 'opposition'};

/// Gold star for a benefic in harmonious aspect (trine/sextile/conjunction)
/// only. Squares and oppositions get the warning triangle regardless of
/// which planet forms them — a square is geometrically tense whether it
/// comes from Mars, Saturn, or a luminary, and hiding that fact for
/// "neutral" planets was exactly what made a square look unexplained next
/// to a favorable label.
String? qualityIndicatorFor(ElectionalHit hit) {
  final isBenefic = beneficPlanets.contains(hit.planet);
  if (isBenefic && harmoniousAspects.contains(hit.aspect)) return '★';
  if (tenseAspects.contains(hit.aspect)) return '△';
  return null;
}

/// A planetary-details row after merging a planet's direct and antiscion
/// hits on the same house into one line, so the same planet's two aspect
/// modes don't render as separate rows.
class GroupedHit {
  final ElectionalHit hit;
  final String modeLabel;
  final bool isCazimi;

  const GroupedHit({required this.hit, required this.modeLabel, required this.isCazimi});
}

List<GroupedHit> groupHits(List<ElectionalHit> hits) {
  final byKey = <String, List<ElectionalHit>>{};
  for (final h in hits) {
    byKey.putIfAbsent('${h.planet}-${h.house}', () => []).add(h);
  }

  final grouped = <GroupedHit>[];
  for (final list in byKey.values) {
    final hasDirect = list.any((h) => h.mode == 'direct');
    final hasAntiscion = list.any((h) => h.mode == 'antiscion');
    // Cazimi is a planet-to-Sun relationship (only ever set on the direct
    // hit, see backend), so it's tracked across the whole group rather
    // than trusting whichever single hit byScore.first happens to pick.
    final isCazimi = list.any((h) => h.isCazimi);
    if (list.length == 2 && hasDirect && hasAntiscion) {
      final byScore = [...list]..sort((a, b) => b.score.compareTo(a.score));
      grouped.add(GroupedHit(hit: byScore.first, modeLabel: 'direct + antiscion', isCazimi: isCazimi));
    } else {
      for (final h in list) {
        grouped.add(GroupedHit(hit: h, modeLabel: h.mode == 'antiscion' ? 'antiscion' : 'direct', isCazimi: h.isCazimi));
      }
    }
  }
  return grouped;
}
