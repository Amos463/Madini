import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_localizations.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/assay_analysis.dart';
import '../../domain/gold_assessment.dart';
import '../../domain/integrity_seal.dart';
import '../../domain/recovery_models.dart';
import '../../domain/valuation_models.dart';
import '../../services/certificate_vault.dart';
import '../../services/local_database.dart';
import '../../services/report_service.dart';
import '../../services/valuation_engine.dart';
import 'dore_screen.dart';

class ValuationScreen extends StatefulWidget {
  const ValuationScreen({super.key, this.template});

  /// Tathmini ya zamani ya kunakiliwa kama msingi wa mpya (tarehe ya bei,
  /// cheti na uthibitisho wa utofauti hazinakiliwi).
  final GoldAssessment? template;

  @override
  State<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sampleIdController = TextEditingController();
  final _lotIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _sellerLicenceController = TextEditingController();
  final _mtf23Controller = TextEditingController();
  final _notesController = TextEditingController();
  final _wetWeightController = TextEditingController();
  final _moistureController = TextEditingController();
  final _gradeController = TextEditingController();
  final _additionalGradesController = TextEditingController();
  final _recoveryController = TextEditingController();
  final _payabilityController = TextEditingController();
  final _processingCostController = TextEditingController();
  final _transportCostController = TextEditingController();
  final _otherCostController = TextEditingController();
  final _priceController = TextEditingController();
  final _usdOzController = TextEditingController();
  final _fxController = TextEditingController();
  final _priceSourceController = TextEditingController();
  final _royaltyController = TextEditingController();
  final _inspectionController = TextEditingController();
  final _otherStatutoryController = TextEditingController();
  final _stressPriceController = TextEditingController(text: '10');
  final _stressRecoveryController = TextEditingController(text: '5');
  final _sulfideController = TextEditingController();
  final _evidenceRefController = TextEditingController();
  final _chemicalCostController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _statutoryRefController = TextEditingController();
  final _labNameController = TextEditingController();
  final _certificateController = TextEditingController();
  final _targetProfitController = TextEditingController();
  final _targetMarginController = TextEditingController();
  final _fieldPointsController = TextEditingController(text: '1');
  final _fieldObservationsController = TextEditingController();

  PlatformFile? _certificateFile;
  bool _representativeSample = false;
  bool _ackVariance = false;
  bool _ackIndicative = false;
  bool _statutoryVerified = false;
  bool _ackZeroStatutory = false;
  String _oreType = OreTypes.other;
  String _recoveryEvidence = RecoveryEvidenceTypes.assumption;
  bool _saving = false;
  String _mode = 'laboratory';
  String _targetMode = 'fixed';
  String _gradeBasis = 'mean';
  String _priceMethod = 'tzs';
  DateTime? _priceQuotedAt;
  String? _varianceNote; // huwekwa pale utofauti mkubwa unapogunduliwa

  List<TextEditingController> get _all => [
        _titleController, _sampleIdController, _lotIdController, _locationController,
        _sellerNameController, _sellerLicenceController, _mtf23Controller, _notesController,
        _wetWeightController, _moistureController, _gradeController, _additionalGradesController,
        _recoveryController, _payabilityController, _processingCostController,
        _transportCostController, _otherCostController, _priceController, _usdOzController,
        _fxController, _priceSourceController, _royaltyController, _inspectionController,
        _otherStatutoryController, _stressPriceController, _stressRecoveryController, _sulfideController, _evidenceRefController,
        _chemicalCostController, _purchasePriceController, _statutoryRefController, _labNameController, _certificateController,
        _targetProfitController, _targetMarginController, _fieldPointsController,
        _fieldObservationsController,
      ];

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) _applyTemplate(t);
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(num v, {double scale = 1}) {
    final scaled = double.parse((v * scale).toStringAsFixed(6));
    final s = scaled.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  void _setNum(TextEditingController c, Object? v, {double scale = 1}) {
    if (v is num) c.text = _fmt(v, scale: scale);
  }

  void _setText(TextEditingController c, Object? v) {
    if (v is String) c.text = v;
  }

  void _applyTemplate(GoldAssessment t) {
    final v = t.values;
    _setText(_titleController, '${v['title'] ?? t.title} (nakala)');
    _setText(_sampleIdController, v['sampleId']);
    _setText(_lotIdController, v['lotId']);
    _setText(_locationController, v['sourceLocation']);
    _setText(_sellerNameController, v['sellerName']);
    _setText(_sellerLicenceController, v['sellerLicence']);
    _setText(_notesController, v['notes']);
    _setNum(_wetWeightController, v['wetWeight']);
    _setNum(_moistureController, v['moistureFraction'], scale: 100);
    _setNum(_gradeController, v['gradeGramsPerTonne']);
    final grades = v['assayGradesGpt'];
    if (grades is List && grades.length > 1) {
      _additionalGradesController.text = grades.skip(1).join('; ');
    }
    _setNum(_recoveryController, v['recoveryFraction'], scale: 100);
    _setNum(_payabilityController, v['payabilityFraction'], scale: 100);
    _setNum(_processingCostController, v['processingCosts']);
    _setNum(_transportCostController, v['transportCosts']);
    _setNum(_otherCostController, v['otherCosts']);
    _setNum(_priceController, v['goldPricePerGram']);
    _setText(_priceSourceController, v['goldPriceSource']);
    _setNum(_royaltyController, v['royaltyPercent']);
    _setNum(_inspectionController, v['inspectionFeePercent']);
    _setNum(_otherStatutoryController, v['otherStatutoryPercent']);
    _setNum(_stressPriceController, v['stressPricePercent']);
    _setNum(_stressRecoveryController, v['stressRecoveryPoints']);
    _setText(_labNameController, v['laboratoryName']);
    _setText(_certificateController, v['certificateNumber']);
    _setNum(_targetProfitController, v['targetProfit']);
    _setNum(_targetMarginController, v['targetMarginPercent']);
    if (v['targetMode'] == 'percentage') _targetMode = 'percentage';
    if (v['gradeBasis'] is String) _gradeBasis = v['gradeBasis'] as String;
    if (v['oreType'] is String && OreTypes.all.contains(v['oreType'])) _oreType = v['oreType'] as String;
    _setNum(_sulfideController, v['sulfidePercent']);
    if (v['recoveryEvidence'] is String && RecoveryEvidenceTypes.all.contains(v['recoveryEvidence'])) {
      _recoveryEvidence = v['recoveryEvidence'] as String;
    }
    _setText(_evidenceRefController, v['recoveryEvidenceRef']);
    _setNum(_chemicalCostController, v['chemicalCosts']);
    _setNum(_purchasePriceController, v['purchasePrice']);
    // Uthibitisho wa makato HAUNAKILIWI: viwango vinaweza kuwa vimebadilika; mtumiaji athibitishe upya.
    _statutoryVerified = false;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (!mounted || result == null) return;
    final selected = result.files.single;
    if (selected.size > 25 * 1024 * 1024) {
      _snack(tr(context, 'Cheti kisizidi MB 25.', 'Certificate must be under 25 MB.'));
      return;
    }
    setState(() => _certificateFile = selected);
  }

  Future<void> _pickPriceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _priceQuotedAt ?? now,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _priceQuotedAt = picked);
  }

  Future<void> _calculateAndSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _calculateAndSaveInternal();
    } catch (error) {
      final msg = error is ArgumentError ? '${error.message}' : '$error';
      _snack(tr(context, 'Imeshindikana kukokotoa/kuhifadhi: $msg', 'Could not calculate/save: $msg'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _n(TextEditingController c) => parseNum(c.text) ?? 0;

  Future<void> _calculateAndSaveInternal() async {
    if (!_formKey.currentState!.validate()) return;
    final id = const Uuid().v4();
    final common = <String, dynamic>{
      'title': _titleController.text.trim(),
      'sampleId': _sampleIdController.text.trim(),
      'lotId': _lotIdController.text.trim(),
      'sourceLocation': _locationController.text.trim(),
      'sellerName': _sellerNameController.text.trim(),
      'sellerLicence': _sellerLicenceController.text.trim(),
      'mtf23Reference': _mtf23Controller.text.trim(),
    };

    if (_mode == 'field') {
      final points = int.tryParse(_fieldPointsController.text.trim()) ?? 0;
      if (points < 1) return;
      final assessment = GoldAssessment(
        id: id,
        title: _titleController.text.trim(),
        mode: 'field',
        assessmentType: 'field_screening',
        createdAt: DateTime.now(),
        formulaVersion: ValuationEngine.formulaVersion,
        values: {
          ...common,
          'samplingPoints': points,
          'representativeClaimed': _representativeSample,
          'observations': _fieldObservationsController.text.trim(),
        },
        result: {
          'valuationAvailable': false,
          'confidence': 'Screening only - laboratory assay required for grade and purchase valuation',
          'recommendation': points < 3 || !_representativeSample
              ? 'Evidence is limited. Collect more representative samples and obtain a laboratory assay before a large purchase.'
              : 'Field observations recorded. They do not establish a gold grade; obtain a laboratory assay before pricing.',
        },
        notes: _fieldObservationsController.text.trim(),
      );
      await LocalDatabase.instance.saveBundle(assessment: assessment);
      if (!mounted) return;
      await _showResult(assessment);
      return;
    }

    // ------------------------------------------------------------ laboratory
    final quotedAt = _priceQuotedAt;
    if (quotedAt == null) {
      _snack(tr(context, 'Chagua tarehe ambayo bei ya dhahabu ilitolewa.',
          'Choose the date the gold price was quoted.'));
      return;
    }
    final primary = parseNum(_gradeController.text)!;
    final extra = parseGradeList(_additionalGradesController.text) ?? <double>[];
    final grades = <double>[primary, ...extra];
    final analysis = AssayAnalysisEngine.analyse(grades);
    final lowest = grades.reduce(math.min);
    final highest = grades.reduce(math.max);
    final expectedGrade = _gradeBasis == 'lowest'
        ? lowest
        : _gradeBasis == 'primary'
            ? primary
            : analysis.meanGramsPerTonne;

    final highVariance = analysis.requiresAcknowledgement;
    final cvNow = analysis.coefficientOfVariationPercent;
    final varianceNote = highVariance
        ? 'CV ${cvNow == null ? 'n/a' : '${cvNow.toStringAsFixed(1)}%'}'
            '${analysis.rangeRatio == null ? '' : ', max/min ${analysis.rangeRatio!.toStringAsFixed(1)}×'}'
        : null;
    if (mounted && _varianceNote != varianceNote) {
      setState(() => _varianceNote = varianceNote);
    }
    if (highVariance && !_ackVariance) {
      _snack(tr(context,
          'Utofauti wa assay ni mkubwa ($varianceNote). Kagua sampuli, kisha tiki kisanduku cha kukiri utofauti ili kuendelea.',
          'Assay variance is high ($varianceNote). Review sampling, then tick the acknowledgement box to continue.'));
      return;
    }

    final double price = _priceMethod == 'usd'
        ? PriceConverter.usdPerOunceToTzsPerGram(
            parseNum(_usdOzController.text)!, parseNum(_fxController.text)!)
        : parseNum(_priceController.text)!;

    // Kanuni ya ushahidi wa recovery (inatekelezwa pia na injini).
    final evidenced = RecoveryEvidenceTypes.isEvidenced(_recoveryEvidence);
    if (OreTypes.requiresEvidence(_oreType) && !evidenced) {
      _snack(tr(context,
          'Ore ya sulfide haiwezi kuthaminiwa kwa recovery ya kudhani. Weka jaribio la metallurgical au historia ya uzalishaji pamoja na rejea yake.',
          'Sulfide ore cannot be valued with an assumed recovery. Provide a metallurgical test or production history with its reference.'));
      return;
    }
    if (!evidenced && !_ackIndicative) {
      _snack(tr(context,
          'Recovery ni dhana tu. Tiki kisanduku cha kukiri kuwa bei ni ya KUKADIRIA tu, au weka ushahidi wa recovery.',
          'Recovery is an assumption. Tick the box to confirm the bid is INDICATIVE only, or provide recovery evidence.'));
      return;
    }

    final statutoryTotal = _n(_royaltyController) + _n(_inspectionController) + _n(_otherStatutoryController);
    if (statutoryTotal == 0 && !_ackZeroStatutory && !_statutoryVerified) {
      _snack(tr(context,
          'Makato ya kisheria ni 0%. Tiki kisanduku cha kuthibitisha kuwa ni kwa makusudi (hakuna makato), au weka viwango rasmi.',
          'Statutory deductions are 0%. Tick the box to confirm this is intentional (no deductions), or enter the official rates.'));
      return;
    }

    final priceSource = _priceSourceController.text.trim();
    final base = ValuationInput(
      title: _titleController.text.trim(),
      mode: 'laboratory',
      wetWeight: parseNum(_wetWeightController.text)!,
      moistureFraction: parseNum(_moistureController.text)! / 100,
      gradeGramsPerTonne: expectedGrade,
      recoveryFraction: parseNum(_recoveryController.text)! / 100,
      payabilityFraction: parseNum(_payabilityController.text)! / 100,
      processingCosts: _n(_processingCostController),
      chemicalCosts: _n(_chemicalCostController),
      transportCosts: _n(_transportCostController),
      otherCosts: _n(_otherCostController),
      goldPricePerGram: price,
      targetProfit: _n(_targetProfitController),
      targetMarginPercent: _n(_targetMarginController),
      targetMode: _targetMode,
      notes: _notesController.text,
      sampleId: _sampleIdController.text.trim(),
      royaltyPercent: _n(_royaltyController),
      inspectionFeePercent: _n(_inspectionController),
      otherStatutoryPercent: _n(_otherStatutoryController),
      oreType: _oreType,
      sulfidePercent: parseNum(_sulfideController.text),
      recoveryEvidence: _recoveryEvidence,
      recoveryEvidenceRef: _evidenceRefController.text.trim(),
      purchasePrice: _n(_purchasePriceController),
      statutoryVerified: _statutoryVerified,
      statutoryReference: _statutoryRefController.text.trim(),
    );
    // Scenarios zinatoka kwenye injini ile ile (grade + bei + recovery).
    final stressPct = (parseNum(_stressPriceController.text) ?? 0).clamp(0, 90).toDouble();
    final stressPts = (parseNum(_stressRecoveryController.text) ?? 0).clamp(0, 50).toDouble();
    final set = ValuationEngine.scenarios(
      base,
      lowestGrade: lowest,
      highestGrade: highest,
      stressPricePercent: stressPct,
      stressRecoveryPoints: stressPts,
    );
    final conservative = set.conservative;
    final expected = set.expected;

    final warnings = <String>[
      ...analysis.warnings,
      ...ValuationEngine.advisories(base),
      if (DateTime.now().difference(quotedAt).inDays > 7)
        tr(context, 'Bei ina zaidi ya siku 7; ithibitishe upya.', 'Price is more than 7 days old; re-verify it.'),
      if (highVariance)
        tr(context, 'Utofauti mkubwa wa assay umekiriwa na mtumiaji; tumia hali ya conservative.',
            'High assay variance acknowledged by user; prefer the conservative scenario.'),
      if (_n(_royaltyController) + _n(_inspectionController) + _n(_otherStatutoryController) == 0)
        tr(context, 'Makato ya kisheria yamewekwa 0%; thibitisha na mamlaka/mtaalamu.',
            'Statutory deductions are 0%; confirm with the authority/an expert.'),
      if (analysis.count == 1 && stressPct == 0 && stressPts == 0)
        tr(context, 'Scenarios zote tatu zinafanana: assay moja na mshtuko 0.',
            'All three scenarios are identical: single assay and zero stress.'),
      if (conservative.maximumBid <= 0)
        tr(context, 'Hali ya conservative haitoi bei chanya.', 'The conservative scenario gives no positive bid.'),
      if (_certificateFile == null && _certificateController.text.trim().isEmpty)
        tr(context, 'Hakuna cheti wala namba ya cheti iliyowekwa.', 'No certificate file or number recorded.'),
    ];

    final valuesMap = <String, dynamic>{}..addAll(base.toMap()
        ..addAll({
          ...common,
          'assayGradesGpt': grades,
          'gradeBasis': _gradeBasis,
          'stressPricePercent': stressPct,
          'stressRecoveryPoints': stressPts,
          'laboratoryName': _labNameController.text.trim(),
          'certificateNumber': _certificateController.text.trim(),
          'goldPriceSource': priceSource,
          'goldPriceQuotedAt': dateOnly(quotedAt),
          'goldPriceSavedAt': DateTime.now().toIso8601String(),
          'priceInputMethod': _priceMethod,
          if (_priceMethod == 'usd') 'usdPerOunce': parseNum(_usdOzController.text),
          if (_priceMethod == 'usd') 'tzsPerUsd': parseNum(_fxController.text),
        }));
    final resultMap = <String, dynamic>{}..addAll(expected.toMap()
        ..addAll({
          'currency': 'TZS',
          'goldPriceUnit': 'TZS per gram',
          'goldPriceSource': priceSource,
          'goldPriceQuotedAt': dateOnly(quotedAt),
          'assayComparison': analysis.toMap(),
          'scenarios': set.toMap(),
          'warnings': warnings,
        }));
    // Muhuri wa uadilifu: unagundua mabadiliko yoyote baada ya kuhifadhi.
    final sealedResult = await IntegritySeal.seal(valuesMap, resultMap, ValuationEngine.formulaVersion);

    final assessment = GoldAssessment(
      id: id,
      title: base.title,
      mode: 'laboratory',
      assessmentType: 'laboratory',
      createdAt: DateTime.now(),
      formulaVersion: ValuationEngine.formulaVersion,
      values: valuesMap,
      result: sealedResult,
      notes: base.notes,
    );

    final samples = <Map<String, Object?>>[
      for (var i = 0; i < grades.length; i++)
        {
          'id': const Uuid().v4(),
          'sample_code': i == 0 ? base.sampleId : '${base.sampleId}-${i + 1}',
          'laboratory': _labNameController.text.trim(),
          'certificate_number': _certificateController.text.trim(),
          'grade_gpt': grades[i],
          'sampled_at': null,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }
    ];
    final priceRecord = <String, Object?>{
      'id': const Uuid().v4(),
      'price_tzs_g': price,
      'source': priceSource,
      'recorded_at': quotedAt.toUtc().toIso8601String(),
      'is_manual': 1,
      'note': 'saved_at ${DateTime.now().toUtc().toIso8601String()}',
    };

    EncryptedCertificate? enc;
    final file = _certificateFile;
    if (file != null && file.bytes != null) {
      enc = await CertificateVault.encryptToFile(file.bytes!);
    }
    try {
      await LocalDatabase.instance.saveBundle(
        assessment: assessment,
        samples: samples,
        priceRecord: priceRecord,
        certificate: enc == null
            ? null
            : {
                'id': enc.id,
                'sample_code': base.sampleId,
                'file_name': file!.name,
                'private_path': enc.path,
                'sha256': enc.sha256,
              },
      );
    } catch (_) {
      // Muamala umeshindwa: usiache faili la cheti yatima.
      if (enc != null) await CertificateVault.deleteFile(enc.path);
      rethrow;
    }
    if (mounted) {
      setState(() {
        _certificateFile = null;
        _ackVariance = false;
        _ackIndicative = false;
        _ackZeroStatutory = false;
        _varianceNote = null;
      });
      await _showResult(assessment);
    }
  }

  Future<void> _showResult(GoldAssessment assessment) async {
    final strings = AppLocalizations.of(context);
    final r = assessment.result;
    final scenarios = r['scenarios'] is Map ? r['scenarios'] as Map : const {};
    final warnings = r['warnings'] is List ? r['warnings'] as List : const [];
    String m(Object? v) => v is num ? formatMoney(v) : '-';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(assessment.isField
            ? tr(dialogContext, 'Field screening imehifadhiwa', 'Field screening saved')
            : strings.get('results')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: assessment.isField
                ? [
                    Text(tr(dialogContext,
                        'Hakuna grade ya g/t wala bei ya ununuzi iliyokadiriwa kutokana na uchunguzi wa uga.',
                        'No g/t grade or purchase price has been inferred from field observations.')),
                    const SizedBox(height: 8),
                    Text('${r['recommendation']}'),
                  ]
                : [
                    for (final name in ['conservative', 'expected', 'optimistic'])
                      if (scenarios[name] is Map) ...[
                        Text(
                          '${name.toUpperCase()} (${formatGrams((scenarios[name] as Map)['gradeUsed'] as num)} g/t)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${tr(dialogContext, 'Bei ya juu ya kununua', 'Maximum bid')} (TZS): ${m((scenarios[name] as Map)['maximumBid'])}'),
                        Text('${tr(dialogContext, 'Bei/recovery zilizotumika', 'Price/recovery used')}: ${m((scenarios[name] as Map)['priceUsed'])} TZS/g • ${(((scenarios[name] as Map)['recoveryUsed'] as num? ?? 0) * 100).toStringAsFixed(1)}%'),
                        Text('${tr(dialogContext, 'Mapato', 'Revenue')} (TZS): ${m((scenarios[name] as Map)['revenue'])}'),
                        if (name == 'expected')
                          Text('${tr(dialogContext, 'Faida (kabla ya ununuzi kama haijawekwa)', 'Profit (before purchase if not entered)')} (TZS): ${m((scenarios[name] as Map)['profit'])}'),
                        Text('${tr(dialogContext, 'Makato ya kisheria', 'Statutory')} (TZS): ${m((scenarios[name] as Map)['statutoryDeductions'])}'),
                        const SizedBox(height: 8),
                      ],
                    Text('${r['confidence']}'),
                    const SizedBox(height: 8),
                    for (final w in warnings) Text('• $w'),
                  ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ReportService.share(assessment);
              } catch (e) {
                _snack(tr(dialogContext, 'Ripoti imeshindikana: $e', 'Report failed: $e'));
              }
            },
            child: Text(strings.get('report')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr(dialogContext, 'Sawa', 'OK')),
          ),
        ],
      ),
    );
  }

  Widget _f(String label, TextEditingController controller,
      {String? suffix,
      String? hint,
      String? helper,
      String? Function(String?)? validator,
      bool numeric = false,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
            labelText: label, suffixText: suffix, hintText: hint, helperText: helper,
            helperMaxLines: 3),
        validator: validator,
      ),
    );
  }

  Widget _h(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? tr(context, 'Inahitajika', 'Required') : null;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('valuation'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DoreScreen()),
                ),
                icon: const Icon(Icons.scale_outlined),
                label: Text(tr(c, 'Unanunua doré/dhahabu (si ore)? Tumia fomu ya doré', 'Buying dore/gold (not ore)? Use the dore form')),
              ),
            ),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'laboratory', label: Text(strings.get('labAssessment'))),
                ButtonSegment(value: 'field', label: Text(strings.get('fieldAssessment'))),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            _f(tr(c, 'Jina la tathmini / loti ya ore', 'Assessment / ore lot name'), _titleController, validator: _req),
            _f('Sample ID', _sampleIdController, validator: _req),
            _f('Lot ID', _lotIdController, helper: tr(c, 'Hiari', 'Optional')),
            _f(tr(c, 'Eneo / chanzo cha sampuli', 'Sample source / location'), _locationController),
            _f(tr(c, 'Jina la muuzaji', 'Seller name'), _sellerNameController,
                helper: tr(c, 'Hiari. Ni taarifa binafsi; linda simu yako.', 'Optional. Personal data; protect your phone.')),
            _f(tr(c, 'Leseni / ID ya muuzaji', 'Seller licence / ID'), _sellerLicenceController),
            if (_mode == 'field') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tr(c,
                      'UCHUNGUZI WA UGA TU: dhahabu inayoonekana au panning haibadilishwi kuwa g/t. Pata assay ya maabara ya sampuli inayowakilisha kabla ya kuweka bei.',
                      'FIELD SCREENING ONLY: visible gold and panning are not converted into g/t. Obtain a representative laboratory assay before setting a price.')),
                ),
              ),
              const SizedBox(height: 12),
              _f(tr(c, 'Idadi ya maeneo ya sampuli', 'Number of sampling points'), _fieldPointsController,
                  numeric: true,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1
                        ? tr(c, 'Weka namba nzima ≥ 1', 'Enter a whole number ≥ 1')
                        : null;
                  }),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _representativeSample,
                onChanged: (v) => setState(() => _representativeSample = v ?? false),
                title: Text(tr(c, 'Naamini sampuli inawakilisha loti nzima', 'I believe the sample represents the whole lot')),
                subtitle: Text(tr(c, 'Ni kauli ya mtumiaji, si uthibitisho huru.', 'This is the user’s statement, not independent verification.')),
              ),
              _f(tr(c, 'Panning, chembe zinazoonekana na uchunguzi mwingine', 'Panning, visible particles and other observations'),
                  _fieldObservationsController, maxLines: 4),
            ] else ...[
              _h(tr(c, 'Uzito na assay', 'Weight and assay')),
              _f(tr(c, 'Uzito mbichi', 'Wet weight'), _wetWeightController,
                  suffix: 'kg', numeric: true, validator: numValidator(c, positive: true)),
              _f(tr(c, 'Unyevu (moisture)', 'Moisture'), _moistureController,
                  suffix: '%', numeric: true, hint: '8', validator: numValidator(c, min: 0, max: 99)),
              _f(tr(c, 'Grade ya assay ya maabara (ya msingi)', 'Laboratory assay grade (primary)'), _gradeController,
                  suffix: 'g/t', numeric: true, validator: numValidator(c, min: 0)),
              _f(tr(c, 'Matokeo mengine ya assay (hiari)', 'Other assay results (optional)'), _additionalGradesController,
                  hint: '3.8; 4.1; 5.0',
                  helper: tr(c, 'Tenganisha kwa ; au nafasi. Tumia nukta kwa desimali.', 'Separate with ; or spaces. Use a dot for decimals.'),
                  validator: (v) => parseGradeList(v) == null
                      ? tr(c, 'Tumia namba zisizo hasi zilizotenganishwa kwa ; au nafasi', 'Use non-negative numbers separated by ; or spaces')
                      : null),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _gradeBasis,
                  decoration: InputDecoration(labelText: tr(c, 'Grade inayotumika kwa hali ya "expected"', 'Grade used for the "expected" scenario')),
                  items: [
                    DropdownMenuItem(value: 'mean', child: Text(tr(c, 'Wastani wa assay zote', 'Mean of all assays'))),
                    DropdownMenuItem(value: 'primary', child: Text(tr(c, 'Assay ya msingi tu', 'Primary assay only'))),
                    DropdownMenuItem(value: 'lowest', child: Text(tr(c, 'Assay ya chini kabisa (tahadhari)', 'Lowest assay (cautious)'))),
                  ],
                  onChanged: (v) => setState(() => _gradeBasis = v ?? 'mean'),
                ),
              ),
              _f(tr(c, 'Jina la maabara (si uthibitisho wa cheti)', 'Laboratory name (not certificate verification)'), _labNameController),
              _f(tr(c, 'Namba ya cheti cha assay (ingizo la mtumiaji)', 'Assay certificate number (user entry)'), _certificateController),
              OutlinedButton.icon(
                onPressed: _pickCertificate,
                icon: const Icon(Icons.attach_file),
                label: Text(_certificateFile == null
                    ? tr(c, 'Ambatisha cheti (PDF/JPG/PNG)', 'Attach certificate (PDF/JPG/PNG)')
                    : '${tr(c, 'Cheti', 'Certificate')}: ${_certificateFile!.name}'),
              ),
              _h(tr(c, 'Aina ya ore na ushahidi wa recovery', 'Ore type and recovery evidence')),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _oreType,
                  decoration: InputDecoration(labelText: tr(c, 'Aina ya ore', 'Ore type')),
                  items: [
                    for (final t in OreTypes.all)
                      DropdownMenuItem(value: t, child: Text(OreTypes.label(t, sw: isSw(c)))),
                  ],
                  onChanged: (v) => setState(() => _oreType = v ?? OreTypes.other),
                ),
              ),
              _f(tr(c, 'Asilimia ya sulfide (hiari)', 'Sulfide percentage (optional)'), _sulfideController,
                  suffix: '%', numeric: true,
                  helper: tr(c, 'Ni taarifa tu. Asilimia ya sulfide pekee haitabiri recovery.',
                      'Information only. Sulfide percentage alone does not predict recovery.'),
                  validator: numValidator(c, required: false, min: 0, max: 100)),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _recoveryEvidence,
                  decoration: InputDecoration(labelText: tr(c, 'Ushahidi wa recovery', 'Recovery evidence')),
                  items: [
                    for (final t in RecoveryEvidenceTypes.all)
                      DropdownMenuItem(value: t, child: Text(RecoveryEvidenceTypes.label(t, sw: isSw(c)))),
                  ],
                  onChanged: (v) => setState(() {
                    _recoveryEvidence = v ?? RecoveryEvidenceTypes.assumption;
                    _ackIndicative = false;
                  }),
                ),
              ),
              if (RecoveryEvidenceTypes.isEvidenced(_recoveryEvidence))
                _f(tr(c, 'Rejea ya ushahidi (namba ya ripoti ya jaribio / kundi-kipindi cha uzalishaji)',
                        'Evidence reference (test report no. / production batch-period)'),
                    _evidenceRefController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? tr(c, 'Inahitajika', 'Required') : null)
              else ...[
                Text(
                  OreTypes.requiresEvidence(_oreType)
                      ? tr(c, 'Ore ya sulfide: hairuhusiwi kutumia recovery ya kudhani. Chagua jaribio la metallurgical au historia ya uzalishaji.',
                          'Sulfide ore: an assumed recovery is not allowed. Choose a metallurgical test or production history.')
                      : tr(c, 'Hakuna ushahidi: bei itawekwa alama ya KUKADIRIA TU.',
                          'No evidence: the bid will be marked INDICATIVE ONLY.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!OreTypes.requiresEvidence(_oreType))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _ackIndicative,
                    onChanged: (v) => setState(() => _ackIndicative = v ?? false),
                    title: Text(tr(c, 'Naelewa bei hii ni ya kukadiria tu (recovery haijathibitishwa)',
                        'I understand this bid is indicative only (recovery unverified)')),
                  ),
              ],
              _h(tr(c, 'Mawazo ya usindikaji', 'Processing assumptions')),
              _f(tr(c, 'Recovery (dhana)', 'Recovery (assumption)'), _recoveryController,
                  suffix: '%', numeric: true, hint: '75', validator: numValidator(c, min: 0, max: 100)),
              _f(tr(c, 'Payability (dhana)', 'Payability (assumption)'), _payabilityController,
                  suffix: '%', numeric: true, hint: '90', validator: numValidator(c, min: 0, max: 100)),
              _h(tr(c, 'Gharama (TZS)', 'Costs (TZS)')),
              _f(tr(c, 'Kemikali (cyanide, lime, reagents n.k.)', 'Chemicals (cyanide, lime, reagents etc.)'), _chemicalCostController,
                  suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
              _f(tr(c, 'Usindikaji', 'Processing'), _processingCostController,
                  suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
              _f(tr(c, 'Usafirishaji', 'Transport'), _transportCostController,
                  suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
              _f(tr(c, 'Nyinginezo', 'Other'), _otherCostController,
                  suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
              _h(tr(c, 'Bei ya dhahabu', 'Gold price')),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _priceMethod,
                  decoration: InputDecoration(labelText: tr(c, 'Njia ya kuingiza bei', 'Price entry method')),
                  items: [
                    DropdownMenuItem(value: 'tzs', child: Text(tr(c, 'TZS kwa gramu', 'TZS per gram'))),
                    DropdownMenuItem(value: 'usd', child: Text(tr(c, 'USD kwa ounce + kiwango cha TZS/USD', 'USD per ounce + TZS/USD rate'))),
                  ],
                  onChanged: (v) => setState(() => _priceMethod = v ?? 'tzs'),
                ),
              ),
              if (_priceMethod == 'tzs')
                _f(tr(c, 'Bei', 'Price'), _priceController,
                    suffix: 'TZS/g', numeric: true, validator: numValidator(c, positive: true))
              else ...[
                _f(tr(c, 'Bei ya dunia', 'World price'), _usdOzController,
                    suffix: 'USD/oz', numeric: true, validator: numValidator(c, positive: true)),
                _f(tr(c, 'Kiwango cha ubadilishaji', 'Exchange rate'), _fxController,
                    suffix: 'TZS/USD', numeric: true, validator: numValidator(c, positive: true),
                    helper: tr(c, '1 troy ounce = 31.1034768 g', '1 troy ounce = 31.1034768 g')),
              ],
              _f(tr(c, 'Chanzo cha bei', 'Price source'), _priceSourceController,
                  hint: tr(c, 'mf. Tume ya Madini / nukuu ya mnunuzi', 'e.g. Mining Commission / buyer quote'),
                  validator: _req),
              OutlinedButton.icon(
                onPressed: _pickPriceDate,
                icon: const Icon(Icons.event),
                label: Text(_priceQuotedAt == null
                    ? tr(c, 'Chagua tarehe ya bei (inahitajika)', 'Choose price date (required)')
                    : '${tr(c, 'Bei ya tarehe', 'Price quoted on')}: ${dateOnly(_priceQuotedAt!)}'),
              ),
              _h(tr(c, 'Makato ya kisheria (% ya mapato)', 'Statutory deductions (% of revenue)')),
              Text(
                tr(c,
                    'Weka viwango rasmi vya sasa kutoka Tume ya Madini/mtaalamu (viwango hubadilika). Hakuna thamani ya msingi: andika 0 kama hakuna. Makato yanahesabiwa kama % ya mapato na yanapunguzwa kutoka bei ya juu (yaani mnunuzi ndiye anayebeba); kama muuzaji analipa, weka 0.',
                    'Enter the current official rates from the Mining Commission/an expert (rates change). There is no default: type 0 if none. Deductions are % of revenue and reduce the maximum bid (the buyer bears them); if the seller pays them, enter 0.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _f('Royalty', _royaltyController, suffix: '%', numeric: true, hint: '0', validator: numValidator(c, min: 0, max: 100)),
              _f('Inspection fee', _inspectionController, suffix: '%', numeric: true, hint: '0', validator: numValidator(c, min: 0, max: 100)),
              _f(tr(c, 'Makato mengine (VAT/withholding n.k.)', 'Other (VAT/withholding etc.)'), _otherStatutoryController,
                  suffix: '%', numeric: true, validator: numValidator(c, min: 0, max: 100)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _royaltyController.text = '4';
                    _inspectionController.text = '0';
                  }),
                  child: Text(tr(c, 'Jaza mfano wa BoT (4% / 0%) — thibitisha', 'Fill BoT example (4% / 0%) — verify')),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _statutoryVerified,
                onChanged: (v) => setState(() => _statutoryVerified = v ?? false),
                title: Text(tr(c, 'Nimethibitisha viwango hivi na mamlaka/mtaalamu',
                    'I confirmed these rates with the authority/an expert')),
                subtitle: Text(tr(c, 'Programu haithibitishi sheria; hii ni kauli yako.',
                    'The app does not verify the law; this is your statement.')),
              ),
              if (_statutoryVerified)
                _f(tr(c, 'Rejea ya uthibitisho (barua/tangazo/jina la mtaalamu)', 'Confirmation reference (letter/notice/expert name)'),
                    _statutoryRefController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? tr(c, 'Inahitajika', 'Required') : null),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _ackZeroStatutory,
                onChanged: (v) => setState(() => _ackZeroStatutory = v ?? false),
                title: Text(tr(c, 'Makato 0% ni kwa makusudi (hakuna makato)', 'A 0% deduction is intentional (no deductions)')),
                subtitle: Text(tr(c, 'Tiki hapa tu kama royalty, inspection na mengine yote ni 0.',
                    'Tick only if royalty, inspection and other deductions are all 0.')),
              ),
              _f(tr(c, 'MTF 23 / control number (hiari)', 'MTF 23 / control number (optional)'), _mtf23Controller),
              _h(tr(c, 'Bei ya ununuzi na lengo la faida', 'Purchase price and target profit')),
              _f(tr(c, 'Bei halisi ya ununuzi wa ore (hiari)', 'Actual ore purchase price (optional)'), _purchasePriceController,
                  suffix: 'TZS', numeric: true, hint: '0',
                  helper: tr(c, 'Ikiachwa 0, "faida" ni kabla ya ununuzi.', 'If left 0, "profit" is before purchase.'),
                  validator: numValidator(c, required: false, min: 0)),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _targetMode,
                  decoration: InputDecoration(labelText: tr(c, 'Aina ya lengo', 'Target rule')),
                  items: [
                    DropdownMenuItem(value: 'fixed', child: Text(tr(c, 'Faida maalum (TZS)', 'Fixed target profit (TZS)'))),
                    DropdownMenuItem(value: 'percentage', child: Text(tr(c, 'Margin (% ya mapato)', 'Target margin (% of revenue)'))),
                  ],
                  onChanged: (v) => setState(() => _targetMode = v ?? 'fixed'),
                ),
              ),
              if (_targetMode == 'fixed')
                _f(tr(c, 'Faida lengwa', 'Target profit'), _targetProfitController,
                    suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0))
              else
                _f(tr(c, 'Margin lengwa', 'Target margin'), _targetMarginController,
                    suffix: '%', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0, max: 100)),
              if (_varianceNote != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ackVariance,
                  onChanged: (v) => setState(() => _ackVariance = v ?? false),
                  title: Text(tr(c,
                      'Naukiri utofauti mkubwa wa assay ($_varianceNote)',
                      'I acknowledge the high assay variance ($_varianceNote)')),
                  subtitle: Text(tr(c, 'Hakiki sampuli na utumie hali ya conservative.',
                      'Review sampling and prefer the conservative scenario.')),
                ),
              _h(tr(c, 'Unyeti wa scenarios', 'Scenario sensitivity')),
              _f(tr(c, 'Mshtuko wa bei (±)', 'Price shock (±)'), _stressPriceController,
                  suffix: '%', numeric: true, hint: '10',
                  helper: tr(c, 'Conservative: bei chini; optimistic: bei juu. 0 = hakuna.', 'Conservative: lower price; optimistic: higher. 0 = none.'),
                  validator: numValidator(c, min: 0, max: 90)),
              _f(tr(c, 'Mshtuko wa recovery (± pointi)', 'Recovery shock (± points)'), _stressRecoveryController,
                  suffix: 'pts', numeric: true, hint: '5',
                  helper: tr(c, 'Conservative: recovery chini; optimistic: juu. 0 = hakuna.', 'Conservative: lower recovery; optimistic: higher. 0 = none.'),
                  validator: numValidator(c, min: 0, max: 50)),
              _f(tr(c, 'Mawazo na maelezo', 'Assumptions and notes'), _notesController, maxLines: 4),
              Text(
                tr(c, 'Bei inaingizwa kwa mkono. Thibitisha chanzo, sarafu na tarehe kwa uhuru kabla ya kutegemea matokeo.',
                    'Price is entered manually. Independently verify the source, currency and date before relying on the result.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _calculateAndSave,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate),
              label: Text(strings.get('calculate')),
            ),
          ],
        ),
      ),
    );
  }
}
