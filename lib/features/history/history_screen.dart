import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/format.dart';
import '../../domain/gold_assessment.dart';
import '../../services/local_database.dart';
import '../common/assessment_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('history'))),
      body: ValueListenableBuilder<int>(
        valueListenable: LocalDatabase.instance.changes,
        builder: (context, _, __) => FutureBuilder<List<GoldAssessment>>(
          future: LocalDatabase.instance.listAssessments(limit: 200),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return ErrorText(snapshot.error);
            final items = snapshot.data ?? const <GoldAssessment>[];
            if (items.isEmpty) {
              return Center(child: Text(tr(context, 'Hakuna tathmini zilizohifadhiwa bado.', 'No saved assessments yet.')));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => AssessmentTile(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}
