import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';

class CitySearchField extends StatefulWidget {
  final ApiClient apiClient;
  final ValueChanged<CityResult?> onSelected;

  const CitySearchField({required this.apiClient, required this.onSelected, super.key});

  @override
  State<CitySearchField> createState() => CitySearchFieldState();
}

class CitySearchFieldState extends State<CitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<CityResult> _suggestions = [];
  bool _loading = false;
  CityResult? _selected;
  String? _error;

  void _onChanged(String query) {
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onSelected(null);
    }
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.apiClient.searchCities(query);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _error = 'City search failed: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(CityResult city) {
    _debounce?.cancel();
    setState(() {
      _selected = city;
      _controller.text = city.name;
      _suggestions = [];
    });
    widget.onSelected(city);
  }

  String? validator(String? _) => _selected == null ? 'Select a city from the suggestions' : null;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Birth city',
            hintText: 'Start typing a city name…',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onChanged,
          validator: validator,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Material(
              type: MaterialType.card,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  final city = _suggestions[i];
                  return ListTile(
                    dense: true,
                    title: Text(city.name),
                    onTap: () => _select(city),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
