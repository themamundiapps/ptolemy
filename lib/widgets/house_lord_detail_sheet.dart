import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

const _bodyStyle = TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5);
const _citationStyle = TextStyle(color: AppColors.mutedGold, fontStyle: FontStyle.italic, fontSize: 12, height: 1.4);
const _subtitleStyle = TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.4);

void showHouseLordDetailSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required HouseLordEntry entry,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.mutedText, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Lord of House ${entry.houseNumber} in House ${entry.lordHouse}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.lord} rules ${entry.sign} — placed in House ${entry.lordHouse} (${entry.lordSign})',
              style: _subtitleStyle,
            ),
            const SizedBox(height: 16),
            FutureBuilder<Interpretation>(
              future: apiClient.fetchHouseLordInterpretation(fromHouse: entry.houseNumber, toHouse: entry.lordHouse),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Interpretation unavailable.', style: TextStyle(color: AppColors.mutedText));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snapshot.data!.body, style: _bodyStyle),
                    if (snapshot.data!.citation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(snapshot.data!.citation, style: _citationStyle),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
