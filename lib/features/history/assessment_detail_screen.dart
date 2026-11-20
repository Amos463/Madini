import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/actual_history.dart';
import '../../domain/assessment_summary.dart';
import '../../domain/gold_assessment.dart';
import '../../domain/integrity_seal.dart';
import '../../domain/recovery_models.dart';
import '../../services/certificate_vault.dart';
import '../../services/local_database.dart';
import '../../services/report_service.dart';
import '../../services/temp_files.dart';
import '../../services/valuation_engine.dart';
import '../valuation/dore_screen.dart';
import '../valuation/valuation_screen.dart';

class AssessmentDetailScreen extends StatefulWidget {
  const AssessmentDetailScreen({super.key, required this.assessment});
  final GoldAssessment assessment;

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  late GoldAssessment _assessment;
  late final Future<List<List<Map<String, Object?>>>> _extra;

  @override
  void initState() {
    super.initState();
    _assessment = widget.assessment;
    _extra = Future.wait([
      LocalDatabase.instance.listAssaySamples(_assessment.id),
      LocalDatabase.instance.listCertificates(_assessment.id),
    ]);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Futa tathmini hii?', 'Delete this assessment?')),
        content: Text(tr(c,
            'Itafutwa pamoja na assay samples na vyeti vilivyoambatishwa. Hatua hii haiwezi kurudishwa (isipokuwa kwa backup).',
            'It will be deleted with its assay samples and attached certificates. This cannot be undone (except from a backup).')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Ghairi', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Futa', 'Delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LocalDatabase.instance.deleteAssessment(_assessment.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _shareCertificate(Map<String, Object?> row) async {
    try {
      final bytes = await CertificateVault.decryptFile(row['private_path'] as String);
      await TempFiles.shareBytes(bytes, row['file_name'] as String);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<String?> _askCorrectionReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Sababu ya kurekebisha', 'Reason for correction')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(c, 'Matokeo ya zamani yatahifadhiwa kwenye historia; hayafutwi.',
                'The previous outcome is kept in the history; it is not deleted.')),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(labelText: tr(c, 'Sababu (inahitajika)', 'Reason (required)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr(c, 'Ghairi', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(c, text);
            },
            child: Text(tr(c, 'Endelea', 'Continue')),
          ),
        ],
      ),
    );
  }

  Future<void> _recordActual() async {
    final isDore = _assessment.mode == 'dore';
    String? reason;
    if (_assessment.values['actualOutcome'] is Map) {
      // Marekebisho ya matokeo yaliyopo yanahitaji sababu; toleo la zamani linahifadhiwa.
      reason = await _askCorrectionReason();
      if (reason == null || !mounted) return;
    }
    final outcome = await showDialog<ActualOutcome>(
      context: context,
      builder: (_) => _ActualOutcomeDialog(isDore: isDore),
    );
    if (outcome == null) return;
    try {
      final stamped = ActualOutcome(
        productMassGrams: outcome.productMassGrams,
        purityFraction: outcome.purityFraction,
        salePricePerGram: outcome.salePricePerGram,
        chemicalCosts: isDore ? null : outcome.chemicalCosts,
        processingCosts: outcome.processingCosts,
        transportCosts: outcome.transportCosts,
        otherCosts: outcome.otherCosts,
        reference: outcome.reference,
        recordedAt: DateTime.now().toIso8601String(),
      );
      final Map<String, dynamic> comparisonMap;
      final List<String> warnings;
      if (isDore) {
        final c = ValuationEngine.compareActualDoreForStored(_assessment.values, stamped);
        comparisonMap = c.toMap();
        warnings = c.warnings;
      } else {
        final c = ValuationEngine.compareActualForStored(_assessment.values, stamped);
        comparisonMap = c.toMap();
        warnings = c.warnings;
      }
      var acknowledged = false;
      if (warnings.isNotEmpty) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr(c, 'Maonyo kwenye matokeo halisi', 'Warnings on the actual outcome')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in warnings) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $w')),
                  const SizedBox(height: 6),
                  Text(tr(c, 'Hakiki uzito, purity na rejea kabla ya kuhifadhi. Ukiendelea, rekodi itawekwa alama ya "inahitaji ukaguzi".',
                      'Check the mass, purity and reference before saving. If you continue, the record is flagged "needs review".')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Rudi nirekebishe', 'Go back and fix'))),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Hifadhi hata hivyo', 'Save anyway'))),
            ],
          ),
        );
        if (proceed != true) return;
        acknowledged = true;
      }
      // Toleo jipya; la zamani (kama lipo) linahamia kwenye historia ya matoleo.
      final versioned = ActualOutcomeVersioning.apply(
        values: _assessment.values,
        result: _assessment.result,
        newOutcome: stamped.toMap(),
        newComparison: comparisonMap,
        nowIso: stamped.recordedAt,
        correctionReason: reason,
        needsReview: acknowledged,
      );
      final updated = GoldAssessment(
        id: _assessment.id,
        title: _assessment.title,
        mode: _assessment.mode,
        assessmentType: _assessment.assessmentType,
        createdAt: _assessment.createdAt,
        formulaVersion: _assessment.formulaVersion,
        values: versioned.values,
        result: versioned.result,
        notes: _assessment.notes,
      );
      await LocalDatabase.instance.recordActualOutcome(updated, auditDetails: {
        'version': versioned.version,
        'reference': stamped.reference,
        'needsReview': acknowledged,
        if (reason != null) 'correctionReason': reason,
      });
      if (mounted) setState(() => _assessment = updated);
      _snack(tr(context, 'Matokeo halisi (toleo ${versioned.version}) yamehifadhiwa.',
          'Actual outcome (version ${versioned.version}) saved.'));
    } catch (e) {
      final msg = e is ArgumentError ? '${e.message}' : '$e';
      _snack(tr(context, 'Imeshindikana: $msg', 'Failed: $msg'));
    }
  }

  Widget _row(SummaryRow row) {
    final sw = Localizations.localeOf(context).languageCode == 'sw';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(sw ? row.sw : row.en, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(flex: 5, child: Text(row.value)),
        ],
      ),
    );
  }

  Widget _recheckCard() {
    if (_assessment.isField) return const SizedBox.shrink();
    final a = _assessment;
    final check = a.mode == 'dore'
        ? ValuationEngine.recheckStoredDore(
            values: a.values, result: a.result, storedFormulaVersion: a.formulaVersion)
        : ValuationEngine.recheckStored(
            values: a.values, result: a.result, storedFormulaVersion: a.formulaVersion);
    return FutureBuilder<SealStatus>(
      future: IntegritySeal.verify(a.values, a.result, a.formulaVersion),
      builder: (context, snap) {
        final seal = snap.data;
        final broken = seal == SealStatus.broken;
        final ok = !broken && (check.matches || check.formulaChanged);
        final lines = <String>[];
        if (broken) {
          lines.add(tr(context,
              'Muhuri wa uadilifu HAUENDANI: rekodi ilibadilishwa baada ya kuhifadhiwa (nje ya app au kwa hitilafu). Usiitegemee; linganisha na backup.',
              'The integrity seal does NOT match: the record was changed after it was saved (outside the app or by a fault). Do not rely on it; compare with a backup.'));
        } else if (seal == SealStatus.valid) {
          lines.add(tr(context, 'Muhuri wa uadilifu: sawa (rekodi haijabadilishwa tangu ihifadhiwe).',
              'Integrity seal: valid (the record is unchanged since it was saved).'));
        } else if (seal == SealStatus.missing) {
          lines.add(tr(context, 'Rekodi hii ya toleo la zamani haina muhuri wa uadilifu.',
              'This record from an earlier version has no integrity seal.'));
        }
        if (check.formulaChanged && !check.matches) {
          lines.add(tr(context,
              'Rekodi ilihifadhiwa kwa formula ${check.storedFormulaVersion}; injini ya sasa ni ${ValuationEngine.formulaVersion}. Tofauti ndogo zinatarajiwa na si ushahidi wa kubadilishwa; namba zilizohifadhiwa ndizo rasmi za rekodi hii.',
              'Saved with formula ${check.storedFormulaVersion}; the current engine is ${ValuationEngine.formulaVersion}. Small differences are expected and are not evidence of tampering; the stored numbers are the record of truth.'));
        } else if (!check.matches) {
          lines.add(tr(context, 'Hesabu iliyorudiwa HAILINGANI na iliyohifadhiwa.',
              'The re-run calculation does NOT match the stored one.'));
          for (final d in check.differences) {
            lines.add('• $d');
          }
        } else {
          lines.add(tr(context, 'Hesabu imerudiwa na injini ya sasa: matokeo yanalingana.',
              'Calculation re-run with the current engine: results match.'));
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ok ? Icons.verified_outlined : Icons.warning_amber_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(l, style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _assessment;
    final sw = Localizations.localeOf(context).languageCode == 'sw';
    final sections = AssessmentSummary.build(a);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        actions: [
          IconButton(
            tooltip: tr(context, 'Futa', 'Delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _recheckCard(),
          for (final section in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sw ? section.sw : section.en, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final row in section.rows) _row(row),
                    for (final note in section.notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $note', style: Theme.of(context).textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
          FutureBuilder<List<List<Map<String, Object?>>>>(
            future: _extra,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final samples = snap.data![0];
              final certs = snap.data![1];
              return Column(children: [
                if (samples.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Assay samples', style: Theme.of(context).textTheme.titleSmall),
                        for (final s in samples)
                          Text('${s['sample_code']}: ${s['grade_gpt']} g/t'
                              '${(s['laboratory'] as String?)?.isNotEmpty == true ? ' • ${s['laboratory']}' : ''}'),
                      ]),
                    ),
                  ),
                for (final c in certs)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text('${c['file_name']}'),
                      subtitle: Text(tr(context, 'Gusa kushiriki/kufungua (inafunguliwa kutoka encryption)',
                          'Tap to share/open (decrypted on demand)')),
                      onTap: () => _shareCertificate(c),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              try {
                await ReportService.share(a);
              } catch (e) {
                _snack('$e');
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(tr(context, 'Ripoti ya PDF', 'PDF report')),
          ),
          if (!a.isField) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _recordActual,
              icon: const Icon(Icons.scale_outlined),
              label: Text(a.values['actualOutcome'] is Map
                  ? tr(context, 'Sasisha matokeo halisi ya uchakataji', 'Update actual processing outcome')
                  : tr(context, a.mode == 'dore' ? 'Rekodi matokeo halisi ya refinery' : 'Rekodi matokeo halisi ya uchakataji',
                      a.mode == 'dore' ? 'Record actual refinery outcome' : 'Record actual processing outcome')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => a.mode == 'dore' ? DoreScreen(template: a) : ValuationScreen(template: a),
                ),
              ),
              icon: const Icon(Icons.copy_outlined),
              label: Text(tr(context, 'Nakili kama tathmini mpya', 'Copy as new assessment')),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActualOutcomeDialog extends StatefulWidget {
  const _ActualOutcomeDialog({this.isDore = false});
  final bool isDore;

  @override
  State<_ActualOutcomeDialog> createState() => _ActualOutcomeDialogState();
}

class _ActualOutcomeDialogState extends State<_ActualOutcomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mass = TextEditingController();
  final _purity = TextEditingController();
  final _reference = TextEditingController();
  final _price = TextEditingController();
  final _chemical = TextEditingController();
  final _processing = TextEditingController();
  final _transport = TextEditingController();
  final _other = TextEditingController();

  @override
  void dispose() {
    for (final c in [_mass, _purity, _reference, _price, _chemical, _processing, _transport, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _opt(TextEditingController c) => parseNum(c.text);

  Widget _field(String label, TextEditingController c,
      {String? suffix, String? Function(String?)? validator, bool numeric = true, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'Matokeo halisi ya uchakataji', 'Actual processing outcome')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(widget.isDore ? tr(context, 'Uzito wa refinery/mnunuzi', 'Refinery/buyer mass') : tr(context, 'Uzito wa bidhaa ya dhahabu', 'Gold product mass'), _mass,
                  suffix: 'g', validator: numValidator(context, positive: true)),
              _field('Purity', _purity,
                  suffix: '%',
                  helper: tr(context,
                      'Fine gold = uzito × purity (inakokotolewa mara moja tu).',
                      'Fine gold = mass × purity (applied once only).'),
                  validator: numValidator(context, positive: true, max: 100)),
              _field(tr(context, 'Rejea (risiti ya refinery/mnunuzi/ripoti ya purity)', 'Reference (refinery/buyer receipt/purity report)'),
                  _reference,
                  numeric: false,
                  validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'Inahitajika', 'Required') : null),
              _field(tr(context, 'Bei halisi ya kuuzia (hiari)', 'Actual sale price (optional)'), _price,
                  suffix: 'TZS/g', validator: numValidator(context, required: false, positive: true)),
              if (!widget.isDore)
                _field(tr(context, 'Kemikali halisi (hiari)', 'Actual chemicals (optional)'), _chemical,
                    suffix: 'TZS', validator: numValidator(context, required: false, min: 0)),
              _field(widget.isDore ? tr(context, 'Refining/assay halisi (hiari)', 'Actual refining/assay (optional)') : tr(context, 'Usindikaji halisi (hiari)', 'Actual processing (optional)'), _processing,
                  suffix: 'TZS', validator: numValidator(context, required: false, min: 0)),
              _field(tr(context, 'Usafirishaji halisi (hiari)', 'Actual transport (optional)'), _transport,
                  suffix: 'TZS', validator: numValidator(context, required: false, min: 0)),
              _field(tr(context, 'Nyinginezo halisi (hiari)', 'Actual other (optional)'), _other,
                  suffix: 'TZS', validator: numValidator(context, required: false, min: 0)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Ghairi', 'Cancel'))),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              ActualOutcome(
                productMassGrams: parseNum(_mass.text)!,
                purityFraction: parseNum(_purity.text)! / 100,
                salePricePerGram: _opt(_price),
                chemicalCosts: widget.isDore ? null : _opt(_chemical),
                processingCosts: _opt(_processing),
                transportCosts: _opt(_transport),
                otherCosts: _opt(_other),
                reference: _reference.text.trim(),
              ),
            );
          },
          child: Text(tr(context, 'Hifadhi', 'Save')),
        ),
      ],
    );
  }
}
