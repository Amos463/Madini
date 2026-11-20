import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/gold_assessment.dart';
import '../history/assessment_detail_screen.dart';

class AssessmentTile extends StatelessWidget {
  const AssessmentTile({super.key, required this.item});
  final GoldAssessment item;

  @override
  Widget build(BuildContext context) {
    final bid = item.maximumBid;
    return Card(
      child: ListTile(
        title: Text(item.title),
        subtitle: Text('${modeLabel(context, item.mode)} • ${dateOnly(item.createdAt)}'),
        trailing: item.isField || bid == null
            ? Text(tr(context, 'Hakuna bei', 'No price'),
                style: Theme.of(context).textTheme.bodySmall)
            : Text(formatMoney(bid), style: Theme.of(context).textTheme.titleSmall),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AssessmentDetailScreen(assessment: item)),
        ),
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.error, {super.key});
  final Object? error;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(context, 'Imeshindikana kusoma data: $error', 'Could not read data: $error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
