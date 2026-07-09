import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

const _calculationIntro =
    'Following the method described by Claudius Ptolemy in the Tetrabiblos (Book I, Chapters 4 and 8; '
    'Book III, Chapter 11), the temperament is determined by observing the Ascending sign, the planets '
    'upon it, the ruler of the Ascendant, the phase and sign of the Moon, and the season of birth. The '
    'qualities of each significator — Hot, Cold, Moist, or Dry — are collected and weighed against one '
    'another.';

/// The Temperament tab, shown alongside Chart and Electional on the natal
/// chart screen. Fetches the calculation for the same birth data used to
/// generate the chart, reusing its already-resolved UTC offset.
class TemperamentTab extends StatefulWidget {
  final ChartResponse result;
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;

  const TemperamentTab({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<TemperamentTab> createState() => _TemperamentTabState();
}

class _TemperamentTabState extends State<TemperamentTab> {
  late final Future<TemperamentResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient(baseUrl: defaultBaseUrl()).fetchTemperament(
      date: widget.birthDate,
      time: widget.birthTime,
      latitude: widget.latitude,
      longitude: widget.longitude,
      tzOffset: widget.result.utcOffsetUsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TemperamentResult>(
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
                'Could not calculate temperament.',
                style: TextStyle(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _TemperamentContent(temperament: snapshot.data!);
      },
    );
  }
}

class _TemperamentContent extends StatelessWidget {
  final TemperamentResult temperament;

  const _TemperamentContent({required this.temperament});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(temperament.temperament, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(
          temperament.qualities,
          style: const TextStyle(color: AppColors.mutedGold, fontSize: 16, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        _QualityBar(leftLabel: 'Cold', rightLabel: 'Hot', value: temperament.netHeat),
        const SizedBox(height: 14),
        _QualityBar(leftLabel: 'Dry', rightLabel: 'Moist', value: temperament.netMoisture),
        const SizedBox(height: 24),
        Text(
          temperament.description,
          style: const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          temperament.citation,
          style: const TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 28),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            collapsedIconColor: AppColors.gold,
            iconColor: AppColors.gold,
            title: Text('How this was calculated', style: theme.textTheme.titleMedium),
            children: [
              const SizedBox(height: 8),
              Text(
                _calculationIntro,
                style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              ...temperament.factors.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(f.detail, style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A horizontal Cold↔Hot or Dry↔Moist axis with a gold marker positioned
/// proportionally to [value] (e.g. net_heat or net_moisture). The marker sits
/// dead center at 0 and moves toward whichever end dominates.
class _QualityBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final int value;
  static const _maxMagnitude = 6;

  const _QualityBar({required this.leftLabel, required this.rightLabel, required this.value});

  @override
  Widget build(BuildContext context) {
    final fraction = (value / _maxMagnitude).clamp(-1.0, 1.0);
    final position = (fraction + 1) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const markerSize = 16.0;
            final trackWidth = constraints.maxWidth;
            final markerLeft = (position * (trackWidth - markerSize)).clamp(0.0, trackWidth - markerSize);
            return SizedBox(
              height: markerSize,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    left: trackWidth / 2 - 1,
                    child: Container(width: 2, height: 12, color: Colors.white24),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
            Text(rightLabel, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
