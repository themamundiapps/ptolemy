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
  final ApiClient? apiClient;

  const TemperamentTab({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    this.apiClient,
    super.key,
  });

  @override
  State<TemperamentTab> createState() => _TemperamentTabState();
}

class _TemperamentTabState extends State<TemperamentTab> {
  late final Future<TemperamentResult> _future;
  late final Future<TemperamentExpanded> _expandedFuture;

  @override
  void initState() {
    super.initState();
    final client = widget.apiClient ?? ApiClient(baseUrl: defaultBaseUrl());
    _future = client.fetchTemperament(
      date: widget.birthDate,
      time: widget.birthTime,
      latitude: widget.latitude,
      longitude: widget.longitude,
      tzOffset: widget.result.utcOffsetUsed,
    );
    // The expanded content is keyed by temperament name, which is only known
    // once the base calculation returns -- chained onto _future rather than
    // fetched independently so it can't race ahead with a stale/guessed name.
    _expandedFuture = _future.then(
      (result) => client.fetchTemperamentExpanded(temperament: result.temperament),
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
        return _TemperamentContent(temperament: snapshot.data!, expandedFuture: _expandedFuture);
      },
    );
  }
}

class _TemperamentContent extends StatelessWidget {
  final TemperamentResult temperament;
  final Future<TemperamentExpanded> expandedFuture;

  const _TemperamentContent({required this.temperament, required this.expandedFuture});

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
        FutureBuilder<TemperamentExpanded>(
          future: expandedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
              );
            }
            // Fails gracefully: no expanded content is not worth surfacing as
            // an error, the rest of the temperament screen is already usable.
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final expanded = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    collapsedIconColor: AppColors.gold,
                    iconColor: AppColors.gold,
                    title: Text('Health Tendencies', style: theme.textTheme.titleMedium),
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        expanded.healthTendencies.text,
                        style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.5),
                      ),
                      if (expanded.healthTendencies.citation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          expanded.healthTendencies.citation,
                          style: const TextStyle(
                            color: AppColors.mutedGold,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                _ProSection(
                  title: 'Traditional Recommendations',
                  // For now every user is treated as free, same as the
                  // Electional theme paywall -- Pro entitlement isn't wired
                  // up to anything real yet.
                  isUnlocked: false,
                  onLockedTap: () => _showTemperamentProSheet(context),
                  children: [_RecommendationsBody(text: expanded.traditionalRecommendations.text)],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
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

void _showTemperamentProSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Traditional Recommendations are available with Ptolemy Pro. Unlock all themes and support '
            'traditional astrology.',
            style: TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () {}, child: const Text('Unlock with Pro')),
          ),
        ],
      ),
    ),
  );
}

/// A collapsible section whose header is either locked (tapping it calls
/// [onLockedTap] instead of expanding -- used for the Pro-gated Traditional
/// Recommendations) or, once unlocked, behaves like a normal expand/collapse
/// tile. Kept separate from the plain [ExpansionTile] used for Health
/// Tendencies because ExpansionTile always toggles on tap; gating that tap
/// behind an entitlement check needs its own expand state.
class _ProSection extends StatefulWidget {
  final String title;
  final bool isUnlocked;
  final VoidCallback onLockedTap;
  final List<Widget> children;

  const _ProSection({
    required this.title,
    required this.isUnlocked,
    required this.onLockedTap,
    required this.children,
  });

  @override
  State<_ProSection> createState() => _ProSectionState();
}

class _ProSectionState extends State<_ProSection> {
  bool _expanded = false;

  void _handleTap() {
    if (!widget.isUnlocked) {
      widget.onLockedTap();
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
                if (!widget.isUnlocked) ...[
                  const Icon(Icons.lock_outline, color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.gold),
              ],
            ),
          ),
        ),
        if (widget.isUnlocked && _expanded) ...widget.children,
      ],
    );
  }
}

/// Renders Traditional Recommendations' "**Label:** body" paragraphs (as
/// produced by the backend content parser) with the label as a small gold
/// caps sub-header and the body text below it in the app's standard body
/// color, rather than as one undifferentiated block of prose.
class _RecommendationsBody extends StatelessWidget {
  final String text;

  const _RecommendationsBody({required this.text});

  static final _labelPattern = RegExp(r'^\*\*(.+?):\*\*\s*(.*)$', dotAll: true);

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildParagraph(paragraph),
            ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String paragraph) {
    final match = _labelPattern.firstMatch(paragraph);
    if (match == null) {
      return Text(paragraph, style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.4));
    }
    final label = match.group(1)!;
    final body = match.group(2)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.4)),
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
