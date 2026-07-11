import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../models/electional_theme.dart';
import '../services/api_client.dart';
import '../services/error_messages.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import 'electional_helpers.dart';
import 'electional_synthesis.dart';

enum _Step { theme, dateRange, results }

/// The Electional tab: theme selection → date range → results, all as
/// internal steps within the tab rather than separate pushed routes.
class ElectionalTab extends StatefulWidget {
  final ChartResponse result;
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;

  const ElectionalTab({
    required this.result,
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<ElectionalTab> createState() => _ElectionalTabState();
}

class _ElectionalTabState extends State<ElectionalTab> {
  _Step _step = _Step.theme;
  ElectionalTheme? _selectedTheme;
  Future<ElectionalResult>? _future;

  void _selectTheme(ElectionalTheme theme) {
    setState(() {
      _selectedTheme = theme;
      _step = _Step.dateRange;
    });
  }

  void _calculate(DateTime start, DateTime end) {
    final client = ApiClient(baseUrl: defaultBaseUrl());
    setState(() {
      _future = client.fetchElectional(
        date: widget.birthDate,
        time: widget.birthTime,
        latitude: widget.latitude,
        longitude: widget.longitude,
        tzOffset: widget.result.utcOffsetUsed,
        startDate: _fmt(start),
        endDate: _fmt(end),
        theme: _selectedTheme!.key,
      );
      _step = _Step.results;
    });
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.theme:
        return _ThemeSelectionView(onSelected: _selectTheme);
      case _Step.dateRange:
        return _DateRangeView(
          theme: _selectedTheme!,
          onBack: () => setState(() => _step = _Step.theme),
          onCalculate: _calculate,
        );
      case _Step.results:
        return _ResultsView(
          theme: _selectedTheme!,
          future: _future!,
          onBack: () => setState(() => _step = _Step.dateRange),
        );
    }
  }
}

class _ThemeSelectionView extends StatelessWidget {
  final ValueChanged<ElectionalTheme> onSelected;

  const _ThemeSelectionView({required this.onSelected});

  void _showLockedSheet(BuildContext context) {
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
              'This theme is available with Ptolemy Pro. Unlock all themes and support '
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freeThemes = kElectionalThemes.where((t) => !t.isPro).toList();
    final proThemes = kElectionalThemes.where((t) => t.isPro).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Find Your Best Moment', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Select the area of life you are seeking guidance for.',
          style: TextStyle(color: AppColors.mutedWhite, fontSize: 13),
        ),
        const SizedBox(height: 24),
        for (final t in freeThemes) _ThemeListRow(theme: t, onTap: () => onSelected(t)),
        const SizedBox(height: 10),
        Text('PRO', style: theme.textTheme.titleMedium?.copyWith(fontSize: 13, letterSpacing: 1.5)),
        for (final t in proThemes) _ThemeListRow(theme: t, onTap: () => _showLockedSheet(context)),
      ],
    );
  }
}

/// A single tappable theme row: name + FREE label/lock on one line,
/// description underneath, divider below. Replaces the old card-grid
/// presentation with a plainer, more deliberate list aesthetic.
class _ThemeListRow extends StatelessWidget {
  final ElectionalTheme theme;
  final VoidCallback onTap;

  const _ThemeListRow({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    theme.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                ),
                if (theme.isPro)
                  const Text('🔒', style: TextStyle(fontSize: 15))
                else
                  const Text(
                    'FREE',
                    style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              theme.description,
              style: const TextStyle(color: AppColors.mutedWhite, fontSize: 12.5, height: 1.3),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

class _DateRangeView extends StatefulWidget {
  final ElectionalTheme theme;
  final VoidCallback onBack;
  final void Function(DateTime start, DateTime end) onCalculate;

  const _DateRangeView({required this.theme, required this.onBack, required this.onCalculate});

  @override
  State<_DateRangeView> createState() => _DateRangeViewState();
}

const _kQuickPeriodPresets = [15, 30, 60, 90];
const _kDefaultPreset = 30;

class _DateRangeViewState extends State<_DateRangeView> {
  bool _customMode = false;
  int _selectedPreset = _kDefaultPreset;
  late DateTime _today;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _customStart = _today;
    _customEnd = _today.add(const Duration(days: _kDefaultPreset));
  }

  Future<void> _pickCustomStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStart,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked;
        if (_customEnd.isBefore(_customStart)) _customEnd = _customStart.add(const Duration(days: 30));
      });
    }
  }

  Future<void> _pickCustomEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEnd,
      firstDate: _customStart,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _customEnd = picked);
  }

  String _displayFmt(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

  void _submit() {
    if (_customMode) {
      widget.onCalculate(_customStart, _customEnd);
    } else {
      widget.onCalculate(_today, _today.add(Duration(days: _selectedPreset)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.gold),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Text(
                widget.theme.label,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 28),
        if (!_customMode) ...[
          Row(
            children: [
              for (var i = 0; i < _kQuickPeriodPresets.length; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Expanded(
                  child: _PeriodPill(
                    label: '${_kQuickPeriodPresets[i]} days',
                    selected: _selectedPreset == _kQuickPeriodPresets[i],
                    onTap: () => setState(() => _selectedPreset = _kQuickPeriodPresets[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _customMode = true),
              child: const Text('Custom dates', style: TextStyle(color: AppColors.mutedGold, fontSize: 13)),
            ),
          ),
        ] else ...[
          _DateField(label: 'Start date', value: _displayFmt(_customStart), onTap: _pickCustomStart),
          const SizedBox(height: 16),
          _DateField(label: 'End date', value: _displayFmt(_customEnd), onTap: _pickCustomEnd),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _customMode = false),
              child: const Text('Use quick select', style: TextStyle(color: AppColors.mutedGold, fontSize: 13)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Scanning longer periods takes more time.',
          style: TextStyle(color: AppColors.mutedWhite, fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Find Best Moments'),
          ),
        ),
      ],
    );
  }
}

/// A quick-select period pill (e.g. "30 days") — gold fill when selected,
/// outlined and transparent otherwise.
class _PeriodPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.bodyText,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value, style: const TextStyle(color: AppColors.bodyText)),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final ElectionalTheme theme;
  final Future<ElectionalResult> future;
  final VoidCallback onBack;

  const _ResultsView({required this.theme, required this.future, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ElectionalResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.gold),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.gold), onPressed: onBack),
                    const Text('Scanning planetary transits…', style: TextStyle(color: AppColors.mutedText)),
                  ],
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          final message = snapshot.hasError ? friendlyApiError(snapshot.error!) : 'Could not scan for moments.';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ),
                TextButton(onPressed: onBack, child: const Text('Back')),
              ],
            ),
          );
        }
        return ResultsList(result: snapshot.data!, themeKey: theme.key, onBack: onBack);
      },
    );
  }
}

/// The results list body, taking an already-resolved [ElectionalResult] —
/// kept public (rather than an underscore-private widget) specifically so
/// it can be pumped directly in widget tests with synthetic data, without
/// needing to mock the network call that produces it.
class ResultsList extends StatelessWidget {
  final ElectionalResult result;
  final String themeKey;
  final VoidCallback onBack;

  const ResultsList({required this.result, required this.themeKey, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Shared across every day so that repeated planet/house combinations and
    // closing lines rotate through their variants rather than repeating.
    final usageCounts = <String, int>{};
    final syntheses = [
      for (final day in result.days) buildSynthesis(day.hits, day.qualityLabel, usageCounts),
    ];
    final contextLines = [
      for (final day in result.days) buildContextualAwareness(day.hits, day.qualityLabel),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.gold), onPressed: onBack),
            Expanded(
              child: Text(
                'Best Moments for ${result.themeLabel}',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        if (result.banner != null) ...[
          _InfoBanner(text: result.banner!, color: AppColors.warning),
          const SizedBox(height: 12),
        ],
        if (result.note != null) ...[
          _InfoBanner(text: result.note!, color: AppColors.mutedGold),
          const SizedBox(height: 12),
        ],
        if (result.days.isEmpty && result.note == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No favorable moments found in this period.', style: TextStyle(color: AppColors.mutedText)),
          ),
        for (var i = 0; i < result.days.length; i++)
          DayTile(
            rank: i + 1,
            day: result.days[i],
            themeKey: themeKey,
            themeLabel: result.themeLabel,
            synthesis: syntheses[i],
            contextLine: contextLines[i],
          ),
        const SizedBox(height: 20),
        const Text(
          'Days are judged against a traditional electional checklist — essential conditions '
          '(retrogrades, combustion, void-of-course Moon, afflicted houses), important conditions '
          '(benefic aspects, a waxing Moon), and desirable conditions (favorable planetary day, '
          'Moon applying to a benefic, essential dignity). Method: Claudius Ptolemy, Tetrabiblos.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 11, fontStyle: FontStyle.italic, height: 1.4),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12.5, height: 1.4)),
    );
  }
}

/// The plain-language reasons a day earned its quality label, always shown
/// (not gated behind expansion) since this is the single most important
/// thing for trusting the label — without it, a square or two sitting in
/// the planetary details reads as an unexplained contradiction.
class _WhyThisDay extends StatelessWidget {
  final List<String> reasons;

  const _WhyThisDay({required this.reasons});

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) {
      return const Text(
        'Meets the essential requirements, but no benefic aspect or favorable Moon phase was found today.',
        style: TextStyle(color: AppColors.mutedText, fontSize: 11, fontStyle: FontStyle.italic, height: 1.4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final reason in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '· $reason',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11.5, height: 1.35),
            ),
          ),
      ],
    );
  }
}

/// A single day's result card — kept public for the same widget-testing
/// reason as [ResultsList].
class DayTile extends StatefulWidget {
  final int rank;
  final ElectionalDay day;
  final String themeKey;
  final String? themeLabel;
  final String synthesis;
  final String? contextLine;
  final ReminderService? reminderService;

  const DayTile({
    required this.rank,
    required this.day,
    required this.themeKey,
    this.themeLabel,
    required this.synthesis,
    this.contextLine,
    this.reminderService,
    super.key,
  });

  @override
  State<DayTile> createState() => _DayTileState();
}

class _DayTileState extends State<DayTile> {
  bool _expanded = false;
  bool _detailsExpanded = false;
  bool _reminderSet = false;
  bool _reminderBusy = false;

  ReminderService get _reminders => widget.reminderService ?? ReminderService.instance;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    final isSet = await _reminders.isReminderSet(themeKey: widget.themeKey, date: widget.day.date);
    if (!mounted) return;
    setState(() => _reminderSet = isSet);
  }

  TimeOfDay get _bestTimeOfDay {
    final parts = widget.day.bestTime.split(':').map(int.parse).toList();
    return TimeOfDay(hour: parts[0], minute: parts[1]);
  }

  Future<void> _addReminder() async {
    final granted = await _reminders.requestPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission is required to set a reminder.')),
      );
      return;
    }

    final picked = await showTimePicker(context: context, initialTime: _bestTimeOfDay);
    if (picked == null || !mounted) return;

    setState(() => _reminderBusy = true);
    try {
      await _reminders.scheduleReminder(
        themeKey: widget.themeKey,
        themeLabel: widget.themeLabel ?? widget.themeKey,
        date: widget.day.date,
        time: picked,
      );
      if (!mounted) return;
      setState(() {
        _reminderSet = true;
        _reminderBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for ${formatDayHeading(widget.day.date)} at ${picked.format(context)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reminderBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not set reminder: $e')));
    }
  }

  Future<void> _cancelReminder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel reminder?'),
        content: Text('This removes the reminder set for ${formatDayHeading(widget.day.date)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel reminder')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _reminders.cancelReminder(themeKey: widget.themeKey, date: widget.day.date);
    if (!mounted) return;
    setState(() => _reminderSet = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder cancelled.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${widget.rank}',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatDayHeading(widget.day.date),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                ),
                if (_reminderSet) ...[
                  InkWell(
                    onTap: _cancelReminder,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('🔔', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.mutedText,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                'Best time: ${humanizedTimeOfDay(widget.day.bestTime)}',
                style: const TextStyle(color: AppColors.bodyText, fontSize: 13),
              ),
            ),
            if (_favorableRulerPlanet != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontStyle: FontStyle.italic),
                    children: [
                      TextSpan(
                        text: planetSymbols[_favorableRulerPlanet] ?? '',
                        style: const TextStyle(fontFamily: astronomiconFontFamily),
                      ),
                      TextSpan(text: ' Ruled by $_favorableRulerPlanet'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                _displayLabel,
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: _WhyThisDay(reasons: widget.day.reasons),
            ),
            if (_expanded) ...[
              const SizedBox(height: 14),
              Text(
                widget.synthesis,
                style: const TextStyle(color: AppColors.bodyText, fontSize: 14, height: 1.5),
              ),
              if (widget.contextLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.contextLine!,
                  style: const TextStyle(
                    color: AppColors.mutedGold,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_reminderBusy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                )
              else
                InkWell(
                  onTap: _addReminder,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none, color: AppColors.gold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _reminderSet ? 'Update Reminder' : 'Add Reminder',
                        style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
                child: Row(
                  children: [
                    Text(
                      'Planetary details',
                      style: const TextStyle(color: AppColors.mutedGold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Icon(
                      _detailsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.mutedGold,
                      size: 18,
                    ),
                  ],
                ),
              ),
              if (_detailsExpanded) ...[
                const SizedBox(height: 8),
                ..._detailsSections(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String get _displayLabel {
    final label = widget.day.qualityLabel;
    final symbol = qualitativeSymbols[label] ?? '';
    return symbol.isEmpty ? label : '$symbol $label';
  }

  /// This day's weekday ruler planet, when favorable for the current theme
  /// (shown as "[symbol] Ruled by [Planet]"), otherwise null (nothing shown).
  String? get _favorableRulerPlanet {
    final parts = widget.day.date.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    return favorableRulerFor(widget.themeKey, date);
  }

  /// Splits the day's hits into two labeled groups *before* merging
  /// direct/antiscion pairs, so a pair where only one mode actually counted
  /// toward the day's classification isn't merged into a single misleading
  /// "direct + antiscion" line — each mode lands in its own honest section.
  List<Widget> _detailsSections() {
    final supporting = groupHits(widget.day.hits.where((h) => h.isSupporting).toList());
    final notCounted = groupHits(widget.day.hits.where((h) => !h.isSupporting).toList());

    return [
      if (supporting.isNotEmpty) ...[
        const Text(
          'Supporting aspects',
          style: TextStyle(color: AppColors.mutedGold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        ...supporting.map(_hitRow),
        const SizedBox(height: 8),
      ],
      if (notCounted.isNotEmpty) ...[
        const Text(
          'Present but not counted',
          style: TextStyle(color: AppColors.mutedText, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        ...notCounted.map(_hitRow),
      ],
    ];
  }

  Widget _hitRow(GroupedHit grouped) {
    final hit = grouped.hit;
    final symbol = aspectSymbols[hit.aspect] ?? hit.aspect;
    // "The Sun"/"The Moon" per traditional usage; other planets take no article.
    final subject = (hit.planet == 'Sun' || hit.planet == 'Moon') ? 'The ${hit.planet}' : hit.planet;
    final article = 'aeiou'.contains(hit.aspect[0].toLowerCase()) ? 'an' : 'a';
    // Split around the symbol rather than one interpolated string -- the
    // symbol needs its own TextSpan with the Astronomicon font family, and
    // that font remaps plain Latin letters too, so it can't be applied to
    // the whole sentence.
    final sentencePrefix = '$subject forms $article ${hit.aspect} (';
    final sentenceSuffix = ') with your House ${hit.house} — ${hit.houseName}';
    final indicator = qualityIndicatorFor(hit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (grouped.isCazimi) ...[
                      const _CazimiBadge(),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(color: AppColors.bodyText, fontSize: 13, height: 1.35),
                          children: [
                            TextSpan(text: sentencePrefix),
                            TextSpan(text: symbol, style: const TextStyle(fontFamily: astronomiconFontFamily)),
                            TextSpan(text: sentenceSuffix),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (grouped.isCazimi)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'This planet is in the heart of the Sun — an exceptionally empowering '
                      'condition in traditional astrology.',
                      style: TextStyle(color: AppColors.mutedText, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                grouped.modeLabel,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              if (indicator != null) ...[
                const SizedBox(height: 2),
                Text(
                  indicator,
                  style: TextStyle(
                    color: indicator == '★' ? AppColors.gold : AppColors.warning,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small gold badge marking a cazimi hit — a planet within 17 arcminutes of
/// exact conjunction with the Sun, traditionally "in the heart of the Sun"
/// and exceptionally empowered. Visually distinct from the routine
/// mode/indicator labels since the condition itself is rare and significant.
class _CazimiBadge extends StatelessWidget {
  const _CazimiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cazimiGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.cazimiGold.withValues(alpha: 0.5)),
      ),
      child: const Text(
        '☀ Cazimi',
        style: TextStyle(color: AppColors.cazimiGold, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
