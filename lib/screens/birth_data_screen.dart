import 'package:flutter/material.dart';

import '../models/birth_data.dart';
import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../services/app_flow.dart';
import '../services/error_messages.dart';
import '../theme.dart';
import '../widgets/city_search_field.dart';
import 'chart_result_screen.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class BirthDataScreen extends StatefulWidget {
  /// A friendly message to show up front -- e.g. when startup tried to load
  /// a saved chart from the backend and couldn't reach it, so the user
  /// lands here instead of silently.
  final String? loadError;

  const BirthDataScreen({this.loadError, super.key});

  @override
  State<BirthDataScreen> createState() => _BirthDataScreenState();
}

class _BirthDataScreenState extends State<BirthDataScreen> {
  final _formKey = GlobalKey<FormState>();

  CityResult? _city;
  DateTime? _date;
  TimeOfDay? _time;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.loadError;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      setState(() => _error = 'Please select a date and time of birth.');
      return;
    }
    final city = _city!;
    final date = _date!;
    final time = _time!;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ApiClient(baseUrl: defaultBaseUrl());
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
      final timeStr = _formatTime(time);
      final result = await client.fetchPositions(
        date: dateStr,
        time: timeStr,
        latitude: city.latitude,
        longitude: city.longitude,
      );
      await AppFlow.saveChartAfterCalculation(
        BirthData(cityName: city.name, latitude: city.latitude, longitude: city.longitude, date: dateStr, time: timeStr),
        result,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChartResultScreen(
            result: result,
            birthDate: dateStr,
            birthTime: timeStr,
            latitude: city.latitude,
            longitude: city.longitude,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = friendlyApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ptolemy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CitySearchField(
                  apiClient: ApiClient(baseUrl: defaultBaseUrl()),
                  onSelected: (city) => setState(() => _city = city),
                ),
                const SizedBox(height: 20),
                _PickerField(
                  label: 'Date of birth',
                  value: _date == null ? null : _formatDate(_date!),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 20),
                _PickerField(
                  label: 'Time of birth (24h)',
                  value: _time == null ? null : _formatTime(_time!),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 8),
                Text(
                  'If birth time is unknown, enter 12:00 — house positions may be inaccurate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: 32),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                        )
                      : const Text('Calculate Chart'),
                ),
              ],
            ),
          ),
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
        child: Text(
          value ?? 'Select…',
          style: TextStyle(color: value == null ? AppColors.mutedText : AppColors.bodyText),
        ),
      ),
    );
  }
}
