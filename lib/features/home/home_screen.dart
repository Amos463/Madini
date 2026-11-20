import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/app_localizations.dart';
import '../../core/format.dart';
import '../../domain/gold_assessment.dart';
import '../../services/backup_reminder.dart';
import '../../services/local_database.dart';
import '../common/assessment_tile.dart';
import '../valuation/dore_screen.dart';
import '../valuation/valuation_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.get('appTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'Kumbukumbu na makadirio ya ununuzi wa ore',
                    'Ore purchase records and estimates'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                tr(context, 'Makadirio ya kusaidia uamuzi; si cheti cha assay wala ofa rasmi.',
                    'Decision-support estimates; not an assay certificate or a formal offer.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: LocalDatabase.instance.changes,
                builder: (context, _, __) => FutureBuilder<bool>(
                  future: LocalDatabase.instance
                      .countAssessments()
                      .then(BackupReminder.isDue)
                      .catchError((_) => false),
                  builder: (context, snapshot) => snapshot.data == true
                      ? Card(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              const Icon(Icons.backup_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(tr(context,
                                    'Hujafanya backup hivi karibuni. Simu ikipotea au ikibadilishwa, rekodi zako hupotea bila backup. Nenda Mipangilio → Tengeneza backup salama.',
                                    'No recent backup. If the phone is lost or replaced, your records are lost without a backup. Go to Settings → Create secure backup.')),
                              ),
                            ]),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ValuationScreen()),
                ),
                icon: const Icon(Icons.calculate),
                label: Text(strings.get('newAssessment')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DoreScreen()),
                ),
                icon: const Icon(Icons.scale_outlined),
                label: Text(tr(context, 'Ununuzi wa doré / dhahabu', 'Dore / gold purchase')),
              ),
              const SizedBox(height: 20),
              Text(strings.get('recentAssessments'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: LocalDatabase.instance.changes,
                  builder: (context, _, __) => FutureBuilder<List<GoldAssessment>>(
                    future: LocalDatabase.instance.listAssessments(limit: 4),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) return ErrorText(snapshot.error);
                      final items = snapshot.data ?? const <GoldAssessment>[];
                      if (items.isEmpty) {
                        return Center(
                          child: Text(tr(context, 'Bado hakuna tathmini. Anza tathmini mpya.',
                              'No assessments yet. Start a new one.')),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => AssessmentTile(item: items[i]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
