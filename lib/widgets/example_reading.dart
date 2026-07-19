import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown below the main CTA on the Analysis and Synastry tabs before the
/// user has generated their own reading, so they know what they're paying
/// for. Paragraphs use the same body style as a real generated reading.
class ExampleReading extends StatelessWidget {
  final String text;

  /// Set false when the caller already renders its own "example" label
  /// above this widget (e.g. inside a bordered card), so the two labels
  /// don't stack.
  final bool showLabel;

  const ExampleReading({required this.text, this.showLabel = true, super.key});

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n\s*\n')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          const Text(
            'Example reading',
            style: TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.gold.withValues(alpha: 0.4)),
          const SizedBox(height: 18),
        ],
        for (final paragraph in paragraphs) ...[
          Text(paragraph, style: const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
