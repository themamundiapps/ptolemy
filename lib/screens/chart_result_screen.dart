import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/aspect_detail_sheet.dart';
import '../widgets/chart_wheel.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/lot_detail_sheet.dart';
import '../widgets/planet_detail_sheet.dart';
import 'electional_tab.dart';
import 'settings_screen.dart';
import 'temperament_screen.dart';

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

class ChartResultScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ptolemy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.gold),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.mutedText,
            indicatorColor: AppColors.gold,
            tabs: [Tab(text: 'Chart'), Tab(text: 'Electional'), Tab(text: 'Temperament')],
          ),
        ),
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _ChartTab(result: result),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTab extends StatelessWidget {
  final ChartResponse result;

  const _ChartTab({required this.result});

  String _timezoneLabel() {
    final sign = result.utcOffsetUsed >= 0 ? '+' : '';
    final offset = 'UTC$sign${result.utcOffsetUsed}';
    if (result.tzSource == 'manual') return '$offset (manual override)';
    return '${result.timezoneId} ($offset)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        AspectRatio(
          aspectRatio: 1,
          child: ChartWheel(
            result: result,
            onPlanetTap: (name) => _showPlanetDetails(context, result, name),
          ),
        ),
        const SizedBox(height: 24),
        Text('Planets', style: theme.textTheme.titleMedium),
        const Divider(height: 20),
        ..._planetOrder
            .where(result.planets.containsKey)
            .map((name) => _PlanetRow(result: result, name: name, position: result.planets[name]!)),
        const SizedBox(height: 16),
        Text('Lots', style: theme.textTheme.titleMedium),
        const Divider(height: 20),
        _LotRow(label: 'Lot of Fortune', lotKey: 'fortune', position: result.lotOfFortune),
        _LotRow(label: 'Lot of Spirit', lotKey: 'spirit', position: result.lotOfSpirit),
        const SizedBox(height: 16),
        Text('Aspects', style: theme.textTheme.titleMedium),
        const Divider(height: 20),
        if (result.aspects.isEmpty)
          const Text('No major aspects within orb.', style: TextStyle(color: AppColors.mutedText))
        else
          ...result.aspects.map((a) => _AspectRow(aspect: a)),
      ],
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
          ],
        ),
      ),
    );
  }
}
