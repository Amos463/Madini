// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_localizations.dart';
import '../../domain/gold_assessment.dart';
import '../../domain/valuation_models.dart';
import '../../services/local_database.dart';
import '../../services/valuation_engine.dart';

class ValuationScreen extends StatefulWidget {
  const ValuationScreen({super.key});

  @override
  State<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Ore Lot A');
  final _sampleIdController = TextEditingController(text: 'SAMPLE-001');
  final _notesController = TextEditingController(text: 'Initial estimate with field observations.');
  final _wetWeightController = TextEditingController(text: '1200');
  final _moistureController = TextEditingController(text: '0.08');
  final _gradeController = TextEditingController(text: '4.2');
  final _recoveryController = TextEditingController(text: '0.72');
  final _payabilityController = TextEditingController(text: '0.9');
  final _processingCostController = TextEditingController(text: '3400');
  final _transportCostController = TextEditingController(text: '1200');
  final _otherCostController = TextEditingController(text: '700');
  final _priceController = TextEditingController(text: '120');
  final _targetProfitController = TextEditingController(text: '2500');
  final _targetMarginController = TextEditingController(text: '18');

  String _mode = 'laboratory';

  @override
  void dispose() {
    _titleController.dispose();
    _sampleIdController.dispose();
    _notesController.dispose();
    _wetWeightController.dispose();
    _moistureController.dispose();
    _gradeController.dispose();
    _recoveryController.dispose();
    _payabilityController.dispose();
    _processingCostController.dispose();
    _transportCostController.dispose();
    _otherCostController.dispose();
    _priceController.dispose();
    _targetProfitController.dispose();
    _targetMarginController.dispose();
    super.dispose();
  }

  Future<void> _calculateAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = ValuationInput(
      title: _titleController.text,
      mode: _mode,
      wetWeight: double.parse(_wetWeightController.text),
      moistureFraction: double.parse(_moistureController.text),
      gradeGramsPerTonne: double.parse(_gradeController.text),
      recoveryFraction: double.parse(_recoveryController.text),
      payabilityFraction: double.parse(_payabilityController.text),
      processingCosts: double.parse(_processingCostController.text),
      transportCosts: double.parse(_transportCostController.text),
      otherCosts: double.parse(_otherCostController.text),
      goldPricePerGram: double.parse(_priceController.text),
      targetProfit: double.parse(_targetProfitController.text),
      targetMarginPercent: double.parse(_targetMarginController.text),
      notes: _notesController.text,
      sampleId: _sampleIdController.text,
    );

    final result = ValuationEngine.calculate(input);
    final assessment = GoldAssessment(
      id: const Uuid().v4(),
      title: input.title,
      mode: input.mode,
      assessmentType: _mode,
      createdAt: DateTime.now(),
      formulaVersion: ValuationEngine.formulaVersion,
      values: input.toMap(),
      result: result.toMap(),
      notes: input.notes,
    );

    await LocalDatabase.instance.insertAssessment(assessment);

    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.get('results')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maximum bid: ${result.maximumBid.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Revenue: ${result.revenue.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(result.confidence),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _exportPdf(assessment);
            },
            child: Text(strings.get('report')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.get('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(GoldAssessment assessment) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MADINI Assessment Report', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 8),
              pw.Text('Title: ${assessment.title}'),
              pw.Text('Mode: ${assessment.mode}'),
              pw.Text('Formula: ${assessment.formulaVersion}'),
              pw.Text('Created: ${assessment.createdAt.toLocal()}'),
              pw.SizedBox(height: 12),
              pw.Text('Maximum bid: ${assessment.result['maximumBid']?.toStringAsFixed(2) ?? '0.00'}'),
              pw.Text('Revenue: ${assessment.result['revenue']?.toStringAsFixed(2) ?? '0.00'}'),
              pw.Text('Confidence: ${assessment.result['confidence'] ?? 'estimate'}'),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${assessment.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Printing.sharePdf(bytes: await pdf.save(), filename: '${assessment.id}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('valuation'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'laboratory', label: Text(strings.get('labAssessment'))),
                ButtonSegment(value: 'field', label: Text(strings.get('fieldAssessment'))),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            _NumberField(controller: _titleController, label: 'Assessment title'),
            const SizedBox(height: 12),
            _NumberField(controller: _sampleIdController, label: 'Sample ID'),
            const SizedBox(height: 12),
            _NumberField(controller: _wetWeightController, label: 'Wet weight (kg)', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _moistureController, label: 'Moisture fraction', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _gradeController, label: 'Grade g/t', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _recoveryController, label: 'Recovery fraction', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _payabilityController, label: 'Payability fraction', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _processingCostController, label: 'Processing cost', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _transportCostController, label: 'Transport cost', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _otherCostController, label: 'Other cost', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _priceController, label: 'Gold price per gram', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _targetProfitController, label: 'Target profit', isNumeric: true),
            const SizedBox(height: 12),
            _NumberField(controller: _targetMarginController, label: 'Target margin %', isNumeric: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _calculateAndSave,
              icon: const Icon(Icons.calculate),
              label: Text(strings.get('calculate')),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.isNumeric = false,
  });

  final TextEditingController controller;
  final String label;
  final bool isNumeric;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        if (isNumeric) {
          final parsed = double.tryParse(value);
          if (parsed == null) {
            return 'Enter a valid number';
          }
        }
        return null;
      },
    );
  }
}
