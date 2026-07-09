import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

void showLotDetailSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required String lotKey,
  required String lotLabel,
  required ZodiacPosition position,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
            Text(lotLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FutureBuilder<Interpretation>(
              future: apiClient.fetchLotInterpretation(lot: lotKey, sign: position.sign, house: position.house),
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
                return Text(
                  snapshot.data!.body,
                  style: const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.5),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
