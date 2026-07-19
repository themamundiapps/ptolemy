import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../services/error_messages.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/city_search_field.dart';
import '../widgets/example_reading.dart';
import '../widgets/pro_status_builder.dart';
import 'paywall_screen.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _planetOrder = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

const _subtitleStyle = TextStyle(color: AppColors.mutedText, fontSize: 14, height: 1.5);

const _exampleSynastryText = '''
The connection between these two nativities is marked above all by the conjunction of the first native's Venus with the second native's Ascendant — one of the most traditionally significant inter-aspects for romantic connection, indicating that the first native's Venusian quality is immediately and viscerally felt by the second as part of their personal world. Valens considers such configurations productive of lasting attachment.

The Sun of the first native falls in the seventh house of the second — a placement that makes the first native's solar authority and public presence a defining feature of the second native's experience of significant relationship. The second native tends to see the first through a lens of admiration and, at times, the particular tension that comes from being in proximity to someone whose solar force exceeds one's own.

The square between the first native's Mars and the second native's Moon introduces a recurring friction: the first native's directness and martial energy periodically disrupts the second native's emotional equilibrium. This is not a fatal configuration — Valens notes that squares between Mars and the Moon produce intensity rather than permanent damage — but it requires conscious management rather than wishful thinking.

The trine between Jupiter of the first native and Saturn of the second is the most stabilizing aspect in the comparison: it suggests that the first native's expansive optimism finds genuine structural support in the second native's discipline and endurance, producing a connection that improves over time rather than burning out quickly.
''';

enum _Step { empty, form, loading, results }

/// The Synastry tab: compares the chart owner's own nativity (passed in as
/// birthDate/birthTime/latitude/longitude, same as every other tab on this
/// screen) against a second person's birth data, entered here. Unlike
/// AnalysisTab's single cache slot keyed by the exact chart, this only keys
/// the cache on the *owner's* chart -- reopening the tab resumes the most
/// recent comparison, whoever the second person was; "New Comparison" is
/// the explicit way to start over with someone else.
class SynastryTab extends StatefulWidget {
  final String birthDate;
  final String birthTime;
  final double latitude;
  final double longitude;
  final double? tzOffset;
  final ApiClient? apiClient;

  const SynastryTab({
    required this.birthDate,
    required this.birthTime,
    required this.latitude,
    required this.longitude,
    this.tzOffset,
    this.apiClient,
    super.key,
  });

  @override
  State<SynastryTab> createState() => _SynastryTabState();
}

class _SynastryTabState extends State<SynastryTab> {
  _Step _step = _Step.empty;
  SynastryResult? _result;
  String? _errorMessage;

  ApiClient get _client => widget.apiClient ?? ApiClient(baseUrl: defaultBaseUrl());

  String get _ownerKey => StorageService.chartAnalysisKey(
        date: widget.birthDate,
        time: widget.birthTime,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await StorageService.loadCachedSynastry(_ownerKey);
    if (!mounted || cached == null) return;
    setState(() {
      _result = cached;
      _step = _Step.results;
    });
  }

  void _startForm() => setState(() {
        _errorMessage = null;
        _step = _Step.form;
      });

  Future<void> _calculate({
    required String? partnerName,
    required String partnerDate,
    required String partnerTime,
    required double partnerLatitude,
    required double partnerLongitude,
  }) async {
    setState(() {
      _step = _Step.loading;
      _errorMessage = null;
    });
    try {
      final userId = await StorageService.resolveUserId();
      final result = await _client.fetchSynastry(
        personA: SynastryPersonInput(
          date: widget.birthDate,
          time: widget.birthTime,
          latitude: widget.latitude,
          longitude: widget.longitude,
          tzOffset: widget.tzOffset,
        ),
        personB: SynastryPersonInput(
          name: partnerName,
          date: partnerDate,
          time: partnerTime,
          latitude: partnerLatitude,
          longitude: partnerLongitude,
        ),
        userId: userId,
      );
      await StorageService.saveSynastry(_ownerKey, result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _errorMessage = friendlyApiError(e);
      });
    }
  }

  Future<void> _newComparison() async {
    await StorageService.clearSynastry();
    if (!mounted) return;
    setState(() {
      _result = null;
      _errorMessage = null;
      _step = _Step.form;
    });
  }

  /// Gates [_newComparison] behind a confirmation whenever it would discard
  /// an already-computed comparison -- "New Comparison" used to clear the
  /// cache immediately on tap, so backing out of the new-partner form (there
  /// is no cancel button in it) silently lost the old one with no way back.
  Future<void> _confirmNewComparison() async {
    final previousPartner = _result?.personBName;
    if (previousPartner != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace comparison?'),
          content: Text('This will replace your current comparison with $previousPartner. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Replace')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _newComparison();
  }

  @override
  Widget build(BuildContext context) {
    return ProStatusBuilder(
      builder: (context, isPro) {
        if (!isPro) return const _LockedSynastry();

        switch (_step) {
          case _Step.empty:
            return _EmptyView(onAddPerson: _startForm);
          case _Step.form:
            return _FormView(onSubmit: _calculate, errorMessage: _errorMessage);
          case _Step.loading:
            return const _LoadingView();
          case _Step.results:
            return _ResultsView(result: _result!, onNewComparison: _confirmNewComparison);
        }
      },
    );
  }
}

/// Two overlapping circles, drawn rather than relying on a Material icon --
/// there's no built-in glyph for it, same rationale as
/// widgets/armillary_sphere_icon.dart.
class _OverlappingCirclesIcon extends StatelessWidget {
  static const double _size = 56;

  const _OverlappingCirclesIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(_size, _size), painter: _OverlappingCirclesPainter());
  }
}

class _OverlappingCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.32;
    final offset = size.width * 0.18;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;

    canvas.drawCircle(Offset(size.width / 2 - offset, centerY), radius, paint);
    canvas.drawCircle(Offset(size.width / 2 + offset, centerY), radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAddPerson;

  const _EmptyView({required this.onAddPerson});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _OverlappingCirclesIcon(),
          const SizedBox(height: 20),
          Text('Synastry', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            "Compare your natal chart with another person's to receive a traditional reading of your connection.",
            style: _subtitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text(
            'What a Synastry reading looks like:',
            style: TextStyle(color: AppColors.mutedText, fontStyle: FontStyle.italic, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const ExampleReading(text: _exampleSynastryText, showLabel: false),
          ),
          const SizedBox(height: 28),
          SizedBox(width: 220, child: FilledButton(onPressed: onAddPerson, child: const Text('Add a Person'))),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Comparing the two charts...',
            style: TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

typedef _SynastrySubmit = Future<void> Function({
  required String? partnerName,
  required String partnerDate,
  required String partnerTime,
  required double partnerLatitude,
  required double partnerLongitude,
});

class _FormView extends StatefulWidget {
  final _SynastrySubmit onSubmit;
  final String? errorMessage;

  const _FormView({required this.onSubmit, required this.errorMessage});

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CityResult? _city;
  DateTime? _date;
  TimeOfDay? _time;
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  String _formatDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  String _formatTime(TimeOfDay t) => '${_twoDigits(t.hour)}:${_twoDigits(t.minute)}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      setState(() => _localError = 'Please select a date and time of birth.');
      return;
    }
    setState(() => _localError = null);
    final city = _city!;
    final date = _date!;
    final time = _time!;
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
    widget.onSubmit(
      partnerName: _nameController.text.trim().isEmpty ? 'Your partner' : _nameController.text.trim(),
      partnerDate: dateStr,
      partnerTime: _formatTime(time),
      partnerLatitude: city.latitude,
      partnerLongitude: city.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorMessage ?? _localError;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a Person', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Their name (optional)'),
            ),
            const SizedBox(height: 20),
            CitySearchField(
              apiClient: ApiClient(baseUrl: defaultBaseUrl()),
              onSelected: (city) => setState(() => _city = city),
            ),
            const SizedBox(height: 20),
            _PickerField(label: 'Date of birth', value: _date == null ? null : _formatDate(_date!), onTap: _pickDate),
            const SizedBox(height: 20),
            _PickerField(label: 'Time of birth (24h)', value: _time == null ? null : _formatTime(_time!), onTap: _pickTime),
            const SizedBox(height: 32),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(onPressed: _submit, child: const Text('Calculate Synastry')),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value ?? 'Select…', style: TextStyle(color: value == null ? AppColors.mutedText : AppColors.bodyText)),
      ),
    );
  }
}

// Loose, sentence-friendly verb for each aspect -- distinct from
// _aspectSymbols below, which is for the compact glyph shown in the
// inter-aspect list rows.
const _aspectVerbs = {
  'conjunction': 'conjunct',
  'sextile': 'sextile',
  'square': 'square',
  'trine': 'trine',
  'opposition': 'oppose',
};

const _angleFullNames = {'ASC': 'Ascendant', 'MC': 'Midheaven'};

/// One line summarizing the connection from its strongest (lowest-orb) hits
/// -- [result.aspects] already arrives orb-sorted from the backend. Null
/// when there's nothing within orb to summarize.
String? _compatibilitySummary(SynastryResult result) {
  if (result.aspects.isEmpty) return null;
  return result.aspects.take(2).map((a) {
    final verb = _aspectVerbs[a.aspect] ?? a.aspect;
    final target = a.isAngle ? (_angleFullNames[a.planetB] ?? a.planetB) : a.planetB;
    return '${a.planetA} $verb $target';
  }).join(' · ');
}

class _ResultsView extends StatelessWidget {
  final SynastryResult result;
  final VoidCallback onNewComparison;

  const _ResultsView({required this.result, required this.onNewComparison});

  @override
  Widget build(BuildContext context) {
    final summary = _compatibilitySummary(result);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('${result.personAName} & ${result.personBName}', style: Theme.of(context).textTheme.headlineLarge),
        if (summary != null) ...[
          const SizedBox(height: 6),
          Text(summary, style: const TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        _SynastryAnalysisBody(text: result.analysis),
        const SizedBox(height: 12),
        _HouseOverlaysSection(result: result),
        _InterAspectsSection(result: result),
        const SizedBox(height: 24),
        FilledButton(onPressed: onNewComparison, child: const Text('New Comparison')),
      ],
    );
  }
}

/// Splits the AI's plain-text reading into paragraphs, rendering any short,
/// unpunctuated line as a gold section header -- same heuristic as
/// analysis_tab.dart's _AnalysisBody, duplicated locally since it's a small,
/// self-contained bit of formatting rather than shared state.
class _SynastryAnalysisBody extends StatelessWidget {
  final String text;

  const _SynastryAnalysisBody({required this.text});

  static const _sentenceEndings = {'.', '!', '?', '"', '”', ':'};

  bool _looksLikeHeader(String block) {
    if (block.isEmpty || block.length > 60 || block.contains('\n')) return false;
    return !_sentenceEndings.contains(block[block.length - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = text.split(RegExp(r'\n\s*\n')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          Text(
            block,
            style: _looksLikeHeader(block)
                ? const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w600)
                : const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// Astronomicon maps each glyph onto a plain Latin letter/punctuation
// codepoint -- see chart_result_screen.dart's identical note. Any Text
// showing one of these must scope the font family to just that character.
const _astronomiconFontFamily = 'Astronomicon';

const _aspectSymbols = {
  'conjunction': '!',
  'sextile': '%',
  'square': '#',
  'trine': r'$',
  'opposition': '"',
};

class _HouseOverlaysSection extends StatelessWidget {
  final SynastryResult result;

  const _HouseOverlaysSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final overlaysA = result.houseOverlays.where((o) => o.fromChart == 'A').toList()
      ..sort((a, b) => _planetOrder.indexOf(a.planet).compareTo(_planetOrder.indexOf(b.planet)));
    final overlaysB = result.houseOverlays.where((o) => o.fromChart == 'B').toList()
      ..sort((a, b) => _planetOrder.indexOf(a.planet).compareTo(_planetOrder.indexOf(b.planet)));

    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: AppColors.gold,
      collapsedIconColor: AppColors.gold,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text('House Overlays', style: Theme.of(context).textTheme.titleMedium),
      children: [
        for (final o in overlaysA)
          _OverlayRow(planet: o.planet, house: o.house, ownerName: result.personAName, otherName: result.personBName),
        for (final o in overlaysB)
          _OverlayRow(planet: o.planet, house: o.house, ownerName: result.personBName, otherName: result.personAName),
      ],
    );
  }
}

class _InterAspectsSection extends StatelessWidget {
  final SynastryResult result;

  const _InterAspectsSection({required this.result});

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
      title: Text('Inter-aspects', style: Theme.of(context).textTheme.titleMedium),
      children: [
        if (result.aspects.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No major inter-aspects within orb.', style: TextStyle(color: AppColors.mutedText)),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('★ marks an aspect to a chart angle (ASC/MC) — traditionally the most significant kind.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11, fontStyle: FontStyle.italic)),
          ),
          for (final a in result.aspects)
            _InterAspectRow(aspect: a, personAName: result.personAName, personBName: result.personBName),
        ],
      ],
    );
  }
}

class _OverlayRow extends StatelessWidget {
  final String planet;
  final int house;
  final String ownerName;
  final String otherName;

  const _OverlayRow({required this.planet, required this.house, required this.ownerName, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        "$ownerName's $planet falls in House $house of $otherName",
        style: const TextStyle(color: AppColors.bodyText, fontSize: 14),
      ),
    );
  }
}

class _InterAspectRow extends StatelessWidget {
  final SynastryAspect aspect;
  final String personAName;
  final String personBName;

  const _InterAspectRow({required this.aspect, required this.personAName, required this.personBName});

  @override
  Widget build(BuildContext context) {
    final symbol = _aspectSymbols[aspect.aspect] ?? aspect.aspect;
    // planet_a always belongs to whichever native from_chart names -- for
    // plain planet-to-planet aspects that's always native A (see
    // app/routers/chart.py), but for angle aspects it can be either, since
    // both directions (A's planets vs B's angles, and B's vs A's) are
    // checked. The second side always belongs to the other native.
    final ownerName = aspect.fromChart == 'A' ? personAName : personBName;
    final otherName = aspect.fromChart == 'A' ? personBName : personAName;
    final targetLabel = aspect.isAngle ? 'natal ${aspect.planetB}' : aspect.planetB;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: aspect.isAngle ? const Text('★', style: TextStyle(color: AppColors.gold, fontSize: 12)) : null,
          ),
          Expanded(
            child: Text('${aspect.planetA} ($ownerName)', style: const TextStyle(color: AppColors.bodyText, fontSize: 14)),
          ),
          SizedBox(
            width: 36,
            child: Text(
              symbol,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold, fontSize: 20, fontFamily: _astronomiconFontFamily),
            ),
          ),
          Expanded(
            child: Text(
              '$targetLabel ($otherName)',
              style: const TextStyle(color: AppColors.bodyText, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Text('${aspect.orb.toStringAsFixed(1)}°', style: const TextStyle(color: AppColors.mutedGold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LockedSynastry extends StatelessWidget {
  const _LockedSynastry();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Synastry', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            "Compare your natal chart with another person's to receive a traditional reading of your connection.",
            style: _subtitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline, color: AppColors.gold, size: 28),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: FilledButton(
              onPressed: () => showPaywallScreen(context),
              child: const Text('Unlock with Ptolemy Pro'),
            ),
          ),
          const SizedBox(height: 40),
          const ExampleReading(text: _exampleSynastryText),
        ],
      ),
    );
  }
}
