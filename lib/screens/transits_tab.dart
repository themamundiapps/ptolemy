import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/transit_detail_sheet.dart';

/// Astronomicon (bundled as an app asset -- see pubspec.yaml, and
/// lib/widgets/chart_wheel.dart for the original mapping and how it was
/// verified) maps each glyph onto a plain Latin letter/punctuation codepoint
/// rather than the actual Unicode astrological codepoint -- any Text showing
/// one of these MUST scope the font family to just that character, never to
/// a whole string that also contains ordinary English text.
const _astronomiconFontFamily = 'Astronomicon';
const _moonGlyph = 'R';

const _aspectSymbols = {
  'conjunction': '!',
  'sextile': '%',
  'square': '#',
  'trine': r'$',
  'opposition': '"',
};

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// Same "normal white text" used for planet/lot names in the natal Chart
// tab's aspect list (chart_result_screen.dart's _nameColor) -- reused here
// so harmonious transits read consistently with the rest of the app.
const _harmoniousColor = Color(0xFFE8E8E8);
const _tenseColor = Color(0xFFE8C49A);

// Must match this tab's position within ChartResultScreen's TabController
// (Chart, Electional, Temperament, Transits, Analysis) -- used to detect
// "this tab was just selected" so transits recalculate on open rather than
// staying frozen at whatever they were when the chart was first loaded.
const _transitsTabIndex = 3;

/// The Daily Transits tab: today's transiting planetary positions compared
/// against this natal chart. Unlike the other tabs (which fetch once and
/// hold that result for the tab's lifetime), transits are time-sensitive, so
/// this refetches every time the tab becomes selected, not just on first
/// load.
class TransitsTab extends StatefulWidget {
  final ChartResponse result;
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;
  final ApiClient? apiClient;

  const TransitsTab({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    this.apiClient,
    super.key,
  });

  @override
  State<TransitsTab> createState() => _TransitsTabState();
}

class _TransitsTabState extends State<TransitsTab> {
  late final ApiClient _client;
  late Future<TransitsResult> _future;
  TabController? _tabController;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    _client = widget.apiClient ?? ApiClient(baseUrl: defaultBaseUrl());
    _future = _fetch();
  }

  Future<TransitsResult> _fetch() {
    return _client.fetchTransits(
      date: widget.birthDate,
      time: widget.birthTime,
      latitude: widget.latitude,
      longitude: widget.longitude,
      tzOffset: widget.result.utcOffsetUsed,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (controller != null && controller != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = controller;
      _lastIndex = controller.index;
      controller.addListener(_onTabChanged);
    }
  }

  /// Refetches only on the transition into this tab (not on every listener
  /// tick, which fires repeatedly during a swipe) and never while a tab
  /// change is still animating away from this tab.
  void _onTabChanged() {
    final controller = _tabController;
    if (controller == null) return;
    if (controller.index == _transitsTabIndex && _lastIndex != _transitsTabIndex) {
      setState(() => _future = _fetch());
    }
    _lastIndex = controller.index;
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransitsResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Could not calculate today's transits.",
                style: TextStyle(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final now = DateTime.now();
        final dateLabel = '${_monthNames[now.month - 1]} ${now.day}, ${now.year}';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _MoonTodayCard(moonPosition: data.moonPosition, moonNatalAspect: data.moonNatalAspect),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Transits', style: Theme.of(context).textTheme.titleMedium),
                Text(dateLabel, style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            if (data.transits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No exact transits active today. The sky is quiet.',
                  style: TextStyle(color: AppColors.mutedText, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...data.transits.map((t) => _TransitRow(transit: t, apiClient: _client)),
          ],
        );
      },
    );
  }
}

class _MoonTodayCard extends StatelessWidget {
  final MoonPosition moonPosition;
  final Transit? moonNatalAspect;

  const _MoonTodayCard({required this.moonPosition, required this.moonNatalAspect});

  @override
  Widget build(BuildContext context) {
    final aspect = moonNatalAspect;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                _moonGlyph,
                style: TextStyle(fontFamily: _astronomiconFontFamily, fontSize: 30, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${moonPosition.sign} · House ${moonPosition.house}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(moonPosition.phaseName, style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                        const SizedBox(width: 8),
                        _MoonPhaseIndicator(phaseAngle: moonPosition.phaseAngle),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (aspect != null) ...[
            const SizedBox(height: 12),
            Text(
              'Moon ${aspect.isApplying ? "applying to" : "separating from"} ${aspect.aspect} natal ${aspect.natalPlanet}',
              style: const TextStyle(color: AppColors.mutedGold, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small ring gauge showing the Moon's current illuminated fraction --
/// paired with the phase name text as the "phase indicator" the design
/// calls for, without attempting a literal (and hard to verify without a
/// device screen) crescent/gibbous silhouette.
class _MoonPhaseIndicator extends StatelessWidget {
  final double phaseAngle;

  const _MoonPhaseIndicator({required this.phaseAngle});

  @override
  Widget build(BuildContext context) {
    final illuminated = (1 - math.cos(phaseAngle * math.pi / 180)) / 2;
    return SizedBox(width: 16, height: 16, child: CustomPaint(painter: _PhaseRingPainter(illuminated: illuminated)));
  }
}

class _PhaseRingPainter extends CustomPainter {
  final double illuminated;

  _PhaseRingPainter({required this.illuminated});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    final track = Paint()
      ..color = AppColors.mutedText.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * illuminated, false, arc);
  }

  @override
  bool shouldRepaint(covariant _PhaseRingPainter oldDelegate) => oldDelegate.illuminated != illuminated;
}

class _TransitRow extends StatelessWidget {
  final Transit transit;
  final ApiClient apiClient;

  const _TransitRow({required this.transit, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    final symbol = _aspectSymbols[transit.aspect] ?? transit.aspect;
    final textColor = transit.isHarmonious ? _harmoniousColor : _tenseColor;

    return InkWell(
      onTap: () => showTransitDetailSheet(context, apiClient: apiClient, transit: transit),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: textColor, fontSize: 15),
                  children: [
                    TextSpan(text: '${transit.transitingPlanet} '),
                    TextSpan(
                      text: symbol,
                      style: const TextStyle(color: AppColors.gold, fontFamily: _astronomiconFontFamily, fontSize: 18),
                    ),
                    TextSpan(text: ' natal ${transit.natalPlanet}'),
                  ],
                ),
              ),
            ),
            Text(
              '${transit.orb.toStringAsFixed(1)}° · ${transit.isApplying ? "applying" : "separating"}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
