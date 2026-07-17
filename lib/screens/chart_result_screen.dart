import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../services/chart_share_service.dart';
import '../theme.dart';
import '../widgets/aspect_detail_sheet.dart';
import '../widgets/chart_wheel.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/house_lord_detail_sheet.dart';
import '../widgets/lot_detail_sheet.dart';
import '../widgets/planet_detail_sheet.dart';
import 'analysis_tab.dart';
import 'electional_tab.dart';
import 'settings_screen.dart';
import 'synastry_tab.dart';
import 'temperament_screen.dart';
import 'transits_tab.dart';

const _planetOrder = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

void _showPlanetDetails(BuildContext context, ChartResponse result, String name) {
  showPlanetDetailSheet(
    context,
    apiClient: ApiClient(baseUrl: defaultBaseUrl()),
    result: result,
    planetName: name,
  );
}

void _showLotDetails(BuildContext context, String lotKey, String lotLabel, ZodiacPosition position) {
  showLotDetailSheet(
    context,
    apiClient: ApiClient(baseUrl: defaultBaseUrl()),
    lotKey: lotKey,
    lotLabel: lotLabel,
    position: position,
  );
}

void _showAspectDetails(BuildContext context, Aspect aspect) {
  showAspectDetailSheet(
    context,
    apiClient: ApiClient(baseUrl: defaultBaseUrl()),
    aspect: aspect,
  );
}

void _showHouseLordDetails(BuildContext context, HouseLordEntry entry) {
  showHouseLordDetailSheet(
    context,
    apiClient: ApiClient(baseUrl: defaultBaseUrl()),
    entry: entry,
  );
}

class ChartResultScreen extends StatefulWidget {
  final ChartResponse result;
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;

  const ChartResultScreen({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<ChartResultScreen> createState() => _ChartResultScreenState();
}

class _ChartResultScreenState extends State<ChartResultScreen> {
  final _chartTabKey = GlobalKey<_ChartTabState>();
  bool _sharing = false;

  Future<void> _shareChart() async {
    final wheelBoundaryKey = _chartTabKey.currentState?.wheelBoundaryKey;
    if (wheelBoundaryKey == null || _sharing) return;

    setState(() => _sharing = true);
    try {
      await shareNatalChart(context: context, wheelBoundaryKey: wheelBoundaryKey, result: widget.result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create share image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final birthDate = widget.birthDate;
    final birthTime = widget.birthTime;
    final latitude = widget.latitude;
    final longitude = widget.longitude;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ptolemy'),
          actions: [
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                    )
                  : const Icon(Icons.ios_share, color: AppColors.gold),
              tooltip: 'Share chart',
              onPressed: _sharing ? null : _shareChart,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.gold),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.mutedText,
            indicatorColor: AppColors.gold,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Chart'),
              Tab(text: 'Electional'),
              Tab(text: 'Temperament'),
              Tab(text: 'Transits'),
              Tab(text: 'Analysis'),
              Tab(text: 'Synastry'),
            ],
          ),
        ),
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _ChartTab(
                    key: _chartTabKey,
                    result: result,
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                  ElectionalTab(
                    result: result,
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                  TemperamentTab(
                    result: result,
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                  TransitsTab(
                    result: result,
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                  AnalysisTab(
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                    tzOffset: result.utcOffsetUsed,
                  ),
                  SynastryTab(
                    birthDate: birthDate,
                    birthTime: birthTime,
                    latitude: latitude,
                    longitude: longitude,
                    tzOffset: result.utcOffsetUsed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTab extends StatefulWidget {
  final ChartResponse result;
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;

  const _ChartTab({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<_ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<_ChartTab> {
  late final Future<List<HouseLordEntry>> _houseLordsFuture;

  /// Attached to the [RepaintBoundary] around the chart wheel below so the
  /// share feature (triggered from the AppBar, outside this tab) can capture
  /// it as an image on demand.
  final wheelBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Reuses the chart's already-resolved UTC offset (same approach as
    // TemperamentTab) rather than re-resolving it, so this can't disagree
    // with the rest of the chart over which offset applies.
    _houseLordsFuture = ApiClient(baseUrl: defaultBaseUrl()).fetchHouseLords(
      date: widget.birthDate,
      time: widget.birthTime,
      latitude: widget.latitude,
      longitude: widget.longitude,
      tzOffset: widget.result.utcOffsetUsed,
    );
  }

  String _timezoneLabel() {
    final result = widget.result;
    final sign = result.utcOffsetUsed >= 0 ? '+' : '';
    final offset = 'UTC$sign${result.utcOffsetUsed}';
    if (result.tzSource == 'manual') return '$offset (manual override)';
    return '${result.timezoneId} ($offset)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          result.sect[0].toUpperCase() + result.sect.substring(1),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text('Timezone: ${_timezoneLabel()}', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: wheelBoundaryKey,
          child: AspectRatio(
            aspectRatio: 1,
            child: ChartWheel(
              result: result,
              onPlanetTap: (name) => _showPlanetDetails(context, result, name),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Planets', style: theme.textTheme.titleMedium),
        const Divider(height: 20),
        ..._planetOrder
            .where(result.planets.containsKey)
            .map((name) => _PlanetRow(result: result, name: name, position: result.planets[name]!)),
        const SizedBox(height: 8),
        _CollapsibleSection(
          title: 'Lots',
          children: [
            _LotRow(label: 'Lot of Fortune', lotKey: 'fortune', position: result.lotOfFortune),
            _LotRow(label: 'Lot of Spirit', lotKey: 'spirit', position: result.lotOfSpirit),
          ],
        ),
        _CollapsibleSection(
          title: 'Aspects',
          children: [
            if (result.aspects.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('No major aspects within orb.', style: TextStyle(color: AppColors.mutedText)),
              )
            else
              ...result.aspects.map((a) => _AspectRow(aspect: a)),
          ],
        ),
        _CollapsibleSection(
          title: 'House Lords',
          children: [
            FutureBuilder<List<HouseLordEntry>>(
              future: _houseLordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('House lords unavailable.', style: TextStyle(color: AppColors.mutedText)),
                  );
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (entry) => _HouseLordRow(
                          entry: entry,
                          onTap: () => _showHouseLordDetails(context, entry),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Collapsed-by-default section used for Lots, Aspects, and House Lords
/// (unlike Planets, which stays always visible above these). Strips
/// ExpansionTile's default top/bottom divider borders via [shape]/
/// [collapsedShape] so it reads as part of the same plain list rather than
/// a bordered card.
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CollapsibleSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: AppColors.gold,
      collapsedIconColor: AppColors.gold,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      children: children,
    );
  }
}

/// Astronomicon (bundled as an app asset -- see pubspec.yaml, and
/// lib/widgets/chart_wheel.dart for the original mapping and how it was
/// verified) maps each glyph onto a plain Latin letter/punctuation codepoint
/// rather than the actual Unicode astrological codepoint -- any Text showing
/// one of these MUST scope the font family to just that character, never to
/// a whole string that also contains ordinary English text.
const _astronomiconFontFamily = 'Astronomicon';

const _aspectSymbols = {
  'conjunction': '!',
  'sextile': '%',
  'square': '#',
  'trine': r'$',
  'opposition': '"',
};

const _nameColor = Color(0xFFE8E8E8);

/// Small muted chevron appended to every tappable row (planets, lots, house
/// lords, aspects) to signal that tapping opens a detail sheet.
class _TrailingChevron extends StatelessWidget {
  const _TrailingChevron();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chevron_right, size: 18, color: AppColors.gold.withValues(alpha: 0.5));
  }
}

class _AspectRow extends StatelessWidget {
  final Aspect aspect;

  const _AspectRow({required this.aspect});

  @override
  Widget build(BuildContext context) {
    final symbol = _aspectSymbols[aspect.aspect] ?? aspect.aspect;
    const nameStyle = TextStyle(color: _nameColor, fontSize: 15);

    return InkWell(
      onTap: () => _showAspectDetails(context, aspect),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(aspect.planetA, style: nameStyle)),
            SizedBox(
              width: 44,
              child: Text(
                symbol,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontFamily: _astronomiconFontFamily,
                ),
              ),
            ),
            Expanded(child: Text(aspect.planetB, style: nameStyle, textAlign: TextAlign.right)),
            const SizedBox(width: 8),
            const _TrailingChevron(),
          ],
        ),
      ),
    );
  }
}

class _PlanetRow extends StatelessWidget {
  final ChartResponse result;
  final String name;
  final ZodiacPosition position;

  const _PlanetRow({required this.result, required this.name, required this.position});

  @override
  Widget build(BuildContext context) {
    final dignityLabel = position.dignities
        .map((d) => d[0].toUpperCase() + d.substring(1))
        .join(', ');

    return InkWell(
      onTap: () => _showPlanetDetails(context, result, name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 84, child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
            Expanded(
              child: Text(
                '${position.signLongitude.toStringAsFixed(2)}° ${position.sign}'
                '${position.retrograde ? ' (R)' : ''} · House ${position.house}',
              ),
            ),
            if (dignityLabel.isNotEmpty)
              Text(dignityLabel, style: const TextStyle(color: AppColors.gold, fontSize: 12)),
            const SizedBox(width: 6),
            const _TrailingChevron(),
          ],
        ),
      ),
    );
  }
}

class _HouseLordRow extends StatelessWidget {
  final HouseLordEntry entry;
  final VoidCallback onTap;

  const _HouseLordRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dignity = entry.lordDignity;
    final dignityLabel = dignity == null ? '' : dignity[0].toUpperCase() + dignity.substring(1);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text('House ${entry.houseNumber}', style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: Text('${entry.lord} → House ${entry.lordHouse}', style: const TextStyle(color: _nameColor)),
            ),
            if (dignityLabel.isNotEmpty)
              Text(dignityLabel, style: const TextStyle(color: AppColors.mutedGold, fontSize: 12)),
            const SizedBox(width: 6),
            const _TrailingChevron(),
          ],
        ),
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  final String label;
  final String lotKey;
  final ZodiacPosition position;

  const _LotRow({required this.label, required this.lotKey, required this.position});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showLotDetails(context, lotKey, label, position),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 130, child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            Expanded(
              child: Text('${position.signLongitude.toStringAsFixed(2)}° ${position.sign} · House ${position.house}'),
            ),
            const SizedBox(width: 6),
            const _TrailingChevron(),
          ],
        ),
      ),
    );
  }
}
