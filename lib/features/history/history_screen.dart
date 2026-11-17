import 'package:flutter/material.dart';

import '../../domain/gold_assessment.dart';
import '../../services/local_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<GoldAssessment>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalDatabase.instance.listAssessments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<GoldAssessment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <GoldAssessment>[];
          if (items.isEmpty) {
            return const Center(child: Text('No saved assessments yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text('${item.mode} • ${item.createdAt.toLocal().toString().split(' ')[0]}'),
                  trailing: Text('${item.result['maximumBid'] ?? 0.0}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
