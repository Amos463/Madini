import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/format.dart';
import '../../domain/gold_assessment.dart';
import '../../services/local_database.dart';
import '../common/assessment_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<GoldAssessment>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalDatabase.instance.searchAssessments('');
    LocalDatabase.instance.changes.addListener(_run);
  }

  void _run() {
    if (!mounted) return;
    setState(() => _future = LocalDatabase.instance.searchAssessments(_controller.text));
  }

  @override
  void dispose() {
    LocalDatabase.instance.changes.removeListener(_run);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('search'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: (_) => _run(),
              decoration: InputDecoration(
                hintText: strings.get('searchHint'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<GoldAssessment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return ErrorText(snapshot.error);
                  final data = snapshot.data ?? const <GoldAssessment>[];
                  if (data.isEmpty) {
                    return Center(child: Text(tr(context, 'Hakuna rekodi zinazolingana.', 'No matching records found.')));
                  }
                  return ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => AssessmentTile(item: data[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
