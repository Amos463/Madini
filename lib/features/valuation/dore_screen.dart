import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/dore_models.dart';
import '../../domain/gold_assessment.dart';
import '../../domain/integrity_seal.dart';
import '../../services/certificate_vault.dart';
import '../../services/local_database.dart';
import '../../services/report_service.dart';
import '../../services/valuation_engine.dart';

/// Tathmini ya ununuzi wa doré / dhahabu: uzito, purity (na njia ya kuipima),
/// payability, bei, gharama na makato. Hesabu zote ziko kwenye ValuationEngine.
class DoreScreen extends StatefulWidget {
  const DoreScreen({super.key, this.template});

  /// Tathmini ya doré ya zamani ya kunakiliwa (tarehe ya bei, cheti, uthibitisho
  /// wa makato na viwango vya kukiri havinakiliwi).
  final GoldAssessment? template;

  @override
  State<DoreScreen> createState() => _DoreScreenState();
}

class _DoreScreenState extends State<DoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _sampleId = TextEditingController();
  final _lotId = TextEditingController();
  final _location = TextEditingController();
  final _sellerName = TextEditingController();
  final _sellerLicence = TextEditingController();
  final _mtf23 = TextEditingController();
  final _notes = TextEditingController();
  final _grossMass = TextEditingController();
  final _weightLoss = TextEditingController(text: '0');
  final _scaleResolution = TextEditingController();
  final _purity = TextEditingController();
  final _karat = TextEditingController();
  final _purityRef = TextEditingController();
  final _caution = TextEditingController(
      text: _fmtNum(DorePurityMethods.defaultCautionPoints(DorePurityMethods.visual)));
  final _payability = TextEditingController();
  final _price = TextEditingController();
  final _usdOz = TextEditingController();
  final _fx = TextEditingController();
  final _priceSource = TextEditingController();
  final _refining = TextEditingController();
  final _transport = TextEditingController();
  final _other = TextEditingController();
  final _royalty = TextEditingController();
  final _inspection = TextEditingController();
  final _otherStatutory = TextEditingController();
  final _statutoryRef = TextEditingController();
  final _targetProfit = TextEditingController();
  final _targetMargin = TextEditingController();
  final _purchase = TextEditingController();
  final _stressPurity = TextEditingController(text: '2');
  final _stressPrice = TextEditingController(text: '5');

  String _method = DorePurityMethods.visual;
  String _priceMethod = 'tzs';
  String _targetMode = 'fixed';
  DateTime? _priceQuotedAt;
  bool _statutoryVerified = false;
  bool _ackZeroStatutory = false;
  bool _ackIndicative = false;
  bool _saving = false;
  PlatformFile? _certificateFile;

  static String _fmtNum(num v) {
    final scaled = double.parse(v.toStringAsFixed(6));
    final s = scaled.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  List<TextEditingController> get _all => [
        _title, _sampleId, _lotId, _location, _sellerName, _sellerLicence, _mtf23, _notes,
        _grossMass, _weightLoss, _scaleResolution, _purity, _karat, _purityRef, _caution,
        _payability, _price, _usdOz, _fx, _priceSource, _refining, _transport, _other,
        _royalty, _inspection, _otherStatutory, _statutoryRef, _targetProfit, _targetMargin,
        _purchase, _stressPurity, _stressPrice,
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

  void _setText(TextEditingController c, Object? v) {
    if (v is String) c.text = v;
  }

  void _setNum(TextEditingController c, Object? v, {double scale = 1}) {
    if (v is num) c.text = _fmtNum(v * scale);
  }

  void _applyTemplate(GoldAssessment t) {
    final v = t.values;
    _setText(_title, '${v['title'] ?? t.title} (nakala)');
    _setText(_sampleId, v['sampleId']);
    _setText(_lotId, v['lotId']);
    _setText(_location, v['sourceLocation']);
    _setText(_sellerName, v['sellerName']);
    _setText(_sellerLicence, v['sellerLicence']);
    _setText(_notes, v['notes']);
    _setNum(_grossMass, v['grossMassGrams']);
    _setNum(_weightLoss, v['weightLossFraction'], scale: 100);
    _setNum(_scaleResolution, v['scaleResolutionGrams']);
    _setNum(_purity, v['measuredPurityFraction'], scale: 100);
    if (v['purityMethod'] is String && DorePurityMethods.all.contains(v['purityMethod'])) {
      _method = v['purityMethod'] as String;
    }
    _setText(_purityRef, v['purityReference']);
    _setNum(_caution, v['purityCautionPoints']);
    _setNum(_payability, v['payabilityFraction'], scale: 100);
    _setNum(_price, v['goldPricePerGram']);
    _setText(_priceSource, v['goldPriceSource']);
    _setNum(_refining, v['refiningCosts']);
    _setNum(_transport, v['transportCosts']);
    _setNum(_other, v['otherCosts']);
    _setNum(_royalty, v['royaltyPercent']);
    _setNum(_inspection, v['inspectionFeePercent']);
    _setNum(_otherStatutory, v['otherStatutoryPercent']);
    _setNum(_targetProfit, v['targetProfit']);
    _setNum(_targetMargin, v['targetMarginPercent']);
    if (v['targetMode'] == 'percentage') _targetMode = 'percentage';
    _setNum(_purchase, v['purchasePrice']);
    _setNum(_stressPurity, v['stressPurityPoints']);
    _setNum(_stressPrice, v['stressPricePercent']);
    // Uthibitisho, tarehe ya bei na viwango vya kukiri HAVINAKILIWI.
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  double _n(TextEditingController c) => parseNum(c.text) ?? 0;

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (!mounted || result == null) return;
    final selected = result.files.single;
    if (selected.size > 25 * 1024 * 1024) {
      _snack(tr(context, 'Faili lisizidi MB 25.', 'File must be under 25 MB.'));
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

  void _useKarat() {
    final k = parseNum(_karat.text);
    if (k == null) {
      _snack(tr(context, 'Weka karat sahihi (mf. 22).', 'Enter a valid karat (e.g. 22).'));
      return;
    }
    try {
      final fraction = PurityConverter.karatToFraction(k);
      setState(() => _purity.text = _fmtNum(double.parse((fraction * 100).toStringAsFixed(4))));
    } catch (e) {
      _snack(tr(context, 'Karat lazima iwe zaidi ya 0 na isizidi 24.', 'Karat must be above 0 and at most 24.'));
    }
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

  Future<void> _calculateAndSaveInternal() async {
    if (!_formKey.currentState!.validate()) return;
    final quotedAt = _priceQuotedAt;
    if (quotedAt == null) {
      _snack(tr(context, 'Chagua tarehe ambayo bei ya dhahabu ilitolewa.', 'Choose the date the gold price was quoted.'));
      return;
    }
    final verified = DorePurityMethods.isVerified(_method);
    if (!verified && !_ackIndicative) {
      _snack(tr(context,
          'Purity haijathibitishwa kwa fire assay. Tiki kisanduku cha kukiri kuwa bei ni ya KUKADIRIA tu.',
          'Purity is not backed by a fire assay. Tick the box to confirm the bid is INDICATIVE only.'));
      return;
    }
    final statutoryTotal = _n(_royalty) + _n(_inspection) + _n(_otherStatutory);
    if (statutoryTotal == 0 && !_ackZeroStatutory && !_statutoryVerified) {
      _snack(tr(context,
          'Makato ya kisheria ni 0%. Tiki kisanduku cha kuthibitisha kuwa ni kwa makusudi, au weka viwango rasmi.',
          'Statutory deductions are 0%. Tick the box to confirm this is intentional, or enter the official rates.'));
      return;
    }

    final price = _priceMethod == 'usd'
        ? PriceConverter.usdPerOunceToTzsPerGram(parseNum(_usdOz.text)!, parseNum(_fx.text)!)
        : parseNum(_price.text)!;
    final priceSource = _priceSource.text.trim();
    final base = DoreInput(
      title: _title.text.trim(),
      sampleId: _sampleId.text.trim(),
      grossMassGrams: parseNum(_grossMass.text)!,
      weightLossFraction: _n(_weightLoss) / 100,
      measuredPurityFraction: parseNum(_purity.text)! / 100,
      purityMethod: _method,
      purityReference: _purityRef.text.trim(),
      purityCautionPoints: _n(_caution),
      payabilityFraction: parseNum(_payability.text)! / 100,
      goldPricePerGram: price,
      refiningCosts: _n(_refining),
      transportCosts: _n(_transport),
      otherCosts: _n(_other),
      royaltyPercent: _n(_royalty),
      inspectionFeePercent: _n(_inspection),
      otherStatutoryPercent: _n(_otherStatutory),
      statutoryVerified: _statutoryVerified,
      statutoryReference: _statutoryRef.text.trim(),
      targetMode: _targetMode,
      targetProfit: _n(_targetProfit),
      targetMarginPercent: _n(_targetMargin),
      purchasePrice: _n(_purchase),
      scaleResolutionGrams: parseNum(_scaleResolution.text),
      notes: _notes.text,
    );
    final stressPts = (parseNum(_stressPurity.text) ?? 0).clamp(0, 20).toDouble();
    final stressPct = (parseNum(_stressPrice.text) ?? 0).clamp(0, 90).toDouble();
    final set = ValuationEngine.doreScenarios(base,
        stressPurityPoints: stressPts, stressPricePercent: stressPct);

    final warnings = <String>[
      ...ValuationEngine.doreAdvisories(base),
      if (DateTime.now().difference(quotedAt).inDays > 7)
        tr(context, 'Bei ina zaidi ya siku 7; ithibitishe upya.', 'Price is more than 7 days old; re-verify it.'),
      if (set.conservative.maximumBid <= 0)
        tr(context, 'Hali ya conservative haitoi bei chanya.', 'The conservative scenario gives no positive bid.'),
    ];

    final valuesMap = <String, dynamic>{
      ...base.toMap(),
      'lotId': _lotId.text.trim(),
      'sourceLocation': _location.text.trim(),
      'sellerName': _sellerName.text.trim(),
      'sellerLicence': _sellerLicence.text.trim(),
      'mtf23Reference': _mtf23.text.trim(),
      'goldPriceSource': priceSource,
      'goldPriceQuotedAt': dateOnly(quotedAt),
      'goldPriceSavedAt': DateTime.now().toIso8601String(),
      'priceInputMethod': _priceMethod,
      if (_priceMethod == 'usd') 'usdPerOunce': parseNum(_usdOz.text),
      if (_priceMethod == 'usd') 'tzsPerUsd': parseNum(_fx.text),
      'stressPurityPoints': stressPts,
      'stressPricePercent': stressPct,
    };
    final resultMap = <String, dynamic>{
      ...set.expected.toMap(),
      'currency': 'TZS',
      'goldPriceUnit': 'TZS per gram',
      'goldPriceSource': priceSource,
      'goldPriceQuotedAt': dateOnly(quotedAt),
      'scenarios': set.toMap(),
      'warnings': warnings,
    };
    final sealed = await IntegritySeal.seal(valuesMap, resultMap, ValuationEngine.formulaVersion);
    final assessment = GoldAssessment(
      id: const Uuid().v4(),
      title: base.title,
      mode: 'dore',
      assessmentType: 'dore',
      createdAt: DateTime.now(),
      formulaVersion: ValuationEngine.formulaVersion,
      values: valuesMap,
      result: sealed,
      notes: base.notes,
    );

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
      if (enc != null) await CertificateVault.deleteFile(enc.path);
      rethrow;
    }
    if (!mounted) return;
    setState(() {
      _certificateFile = null;
      _ackIndicative = false;
      _ackZeroStatutory = false;
    });
    await _showResult(assessment);
  }

  Future<void> _showResult(GoldAssessment a) async {
    final r = a.result;
    final scenarios = r['scenarios'] is Map ? r['scenarios'] as Map : const {};
    final warnings = r['warnings'] is List ? r['warnings'] as List : const [];
    String m(Object? v) => v is num ? formatMoney(v) : '-';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'Matokeo ya doré', 'Dore result')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final name in ['conservative', 'expected', 'optimistic'])
                if (scenarios[name] is Map) ...[
                  Text(
                    '${name.toUpperCase()} (purity ${formatFractionAsPercent((scenarios[name] as Map)['purityUsed'] as num)})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${tr(dialogContext, 'Dhahabu safi', 'Fine gold')}: ${formatGrams((scenarios[name] as Map)['fineGold'] as num)} g'),
                  Text('${tr(dialogContext, 'Bei ya juu ya kununua', 'Maximum bid')} (TZS): ${m((scenarios[name] as Map)['maximumBid'])}'),
                  if (name == 'expected')
                    Text('${tr(dialogContext, 'Faida (kabla ya ununuzi kama haijawekwa)', 'Profit (before purchase if not entered)')} (TZS): ${m((scenarios[name] as Map)['profit'])}'),
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
                await ReportService.share(a);
              } catch (e) {
                _snack(tr(dialogContext, 'Ripoti imeshindikana: $e', 'Report failed: $e'));
              }
            },
            child: Text(tr(dialogContext, 'Ripoti', 'Report')),
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
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
            labelText: label, suffixText: suffix, hintText: hint, helperText: helper, helperMaxLines: 3),
        validator: validator,
      ),
    );
  }

  Widget _h(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? tr(context, 'Inahitajika', 'Required') : null;

  @override
  Widget build(BuildContext context) {
    final c = context;
    final verified = DorePurityMethods.isVerified(_method);
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'Ununuzi wa doré / dhahabu', 'Dore / gold purchase'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr(c,
                    'Kwa doré/dhahabu ambayo tayari imechakatwa. Hesabu hii inathamini dhahabu (Au) pekee; silver (Ag), penalties na masharti maalumu ya refinery havijajumuishwa. Tumia purity ya sampuli inayowakilisha doré ile ile baada ya maandalizi yanayolingana na uzito ulioweka. Rejea ya Fire Assay huingizwa na mtumiaji; programu haihakiki uhalisi wake.',
                    'For processed dore/gold. This calculation values gold (Au) only; silver (Ag), penalties and refinery-specific settlement terms are not included. Use purity from a representative sample prepared consistently with the mass entered. Fire Assay references are user-entered and are not authenticated by the app.')),
              ),
            ),
            const SizedBox(height: 12),
            _f(tr(c, 'Jina la tathmini / loti', 'Assessment / lot name'), _title, validator: _req),
            _f('Sample ID', _sampleId, validator: _req),
            _f('Lot ID', _lotId, helper: tr(c, 'Hiari', 'Optional')),
            _f(tr(c, 'Eneo / chanzo', 'Source location'), _location),
            _f(tr(c, 'Jina la muuzaji', 'Seller name'), _sellerName,
                helper: tr(c, 'Hiari. Ni taarifa binafsi; linda simu yako.', 'Optional. Personal data; protect your phone.')),
            _f(tr(c, 'Leseni / ID ya muuzaji', 'Seller licence / ID'), _sellerLicence),
            _h(tr(c, 'Uzito', 'Weight')),
            _f(tr(c, 'Uzito wa doré kwenye mizani', 'Dore mass on the scale'), _grossMass,
                suffix: 'g', numeric: true, validator: numValidator(c, positive: true)),
            _f(tr(c, 'Punguzo la uzito (unyevu/zebaki/slag)', 'Weight deduction (moisture/mercury/slag)'), _weightLoss,
                suffix: '%', numeric: true, hint: '0',
                helper: tr(c, 'Weka 0 tu kama doré imekauka/imechomwa kabisa.', 'Use 0 only if the dore is fully dry/fired.'),
                validator: numValidator(c, min: 0, max: 50)),
            _f(tr(c, 'Usahihi wa mizani (hiari)', 'Scale resolution (optional)'), _scaleResolution,
                suffix: 'g', numeric: true, validator: numValidator(c, required: false, min: 0)),
            _h('Purity'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _method,
                decoration: InputDecoration(labelText: tr(c, 'Njia ya kupima purity', 'Purity measurement method')),
                items: [
                  for (final m in DorePurityMethods.all)
                    DropdownMenuItem(value: m, child: Text(DorePurityMethods.label(m, sw: isSw(c)))),
                ],
                onChanged: (v) => setState(() {
                  _method = v ?? DorePurityMethods.visual;
                  _caution.text = _fmtNum(DorePurityMethods.defaultCautionPoints(_method));
                  _ackIndicative = false;
                }),
              ),
            ),
            _f(tr(c, 'Purity iliyopimwa', 'Measured purity'), _purity,
                suffix: '%', numeric: true, hint: '90', validator: numValidator(c, positive: true, max: 100)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _f(tr(c, 'Karat (hiari)', 'Karat (optional)'), _karat,
                      suffix: 'k', numeric: true, hint: '22',
                      validator: numValidator(c, required: false, positive: true, max: 24)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton(onPressed: _useKarat, child: Text(tr(c, 'Weka purity', 'Set purity'))),
                ),
              ],
            ),
            _f(
              verified
                  ? tr(c, 'Rejea ya ripoti ya fire assay (inahitajika)', 'Fire assay report reference (required)')
                  : tr(c, 'Rejea (jina la fundi/kifaa cha XRF) - hiari', 'Reference (technician/XRF device) - optional'),
              _purityRef,
              validator: verified ? _req : null,
            ),
            _f(tr(c, 'Tahadhari ya purity (pointi zinazopunguzwa)', 'Purity caution (points deducted)'), _caution,
                suffix: tr(c, 'pointi', 'points'), numeric: true,
                helper: tr(c,
                    'Pendekezo la awali: fire assay 0, XRF 2, macho 5. Mhasibu/mnunuzi mzoefu athibitishe viwango hivi.',
                    'Starting suggestion: fire assay 0, XRF 2, visual 5. Have an accountant/experienced buyer confirm these.'),
                validator: numValidator(c, min: 0, max: 50)),
            if (!verified)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _ackIndicative,
                onChanged: (v) => setState(() => _ackIndicative = v ?? false),
                title: Text(tr(c, 'Naelewa bei hii ni ya kukadiria tu (purity haijathibitishwa kwa fire assay)',
                    'I understand this bid is indicative only (purity not backed by a fire assay)')),
              ),
            OutlinedButton.icon(
              onPressed: _pickCertificate,
              icon: const Icon(Icons.attach_file),
              label: Text(_certificateFile == null
                  ? tr(c, 'Ambatisha ripoti ya purity (PDF/JPG/PNG)', 'Attach purity report (PDF/JPG/PNG)')
                  : '${tr(c, 'Faili', 'File')}: ${_certificateFile!.name}'),
            ),
            _h(tr(c, 'Malipo na bei', 'Payability and price')),
            _f('Payability', _payability,
                suffix: '%', numeric: true, hint: '98',
                helper: tr(c, 'Asilimia ya dhahabu safi ambayo refinery/mnunuzi wa mwisho analipa.',
                    'Share of fine gold the refinery/final buyer pays for.'),
                validator: numValidator(c, min: 0, max: 100)),
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
              _f(tr(c, 'Bei', 'Price'), _price, suffix: 'TZS/g', numeric: true, validator: numValidator(c, positive: true))
            else ...[
              _f(tr(c, 'Bei ya dunia', 'World price'), _usdOz, suffix: 'USD/oz', numeric: true, validator: numValidator(c, positive: true)),
              _f(tr(c, 'Kiwango cha ubadilishaji', 'Exchange rate'), _fx, suffix: 'TZS/USD', numeric: true, validator: numValidator(c, positive: true)),
            ],
            _f(tr(c, 'Chanzo cha bei', 'Price source'), _priceSource, validator: _req),
            OutlinedButton.icon(
              onPressed: _pickPriceDate,
              icon: const Icon(Icons.event),
              label: Text(_priceQuotedAt == null
                  ? tr(c, 'Chagua tarehe ya bei (inahitajika)', 'Choose price date (required)')
                  : '${tr(c, 'Bei ya tarehe', 'Price quoted on')}: ${dateOnly(_priceQuotedAt!)}'),
            ),
            _h(tr(c, 'Gharama (TZS)', 'Costs (TZS)')),
            _f('Refining / assay', _refining, suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
            _f(tr(c, 'Usafirishaji', 'Transport'), _transport, suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
            _f(tr(c, 'Nyinginezo', 'Other'), _other, suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0)),
            _h(tr(c, 'Makato ya kisheria (% ya mapato)', 'Statutory deductions (% of revenue)')),
            Text(
              tr(c,
                  'Hakuna viwango vya awali: ingiza viwango rasmi vya sasa (0 kama hakuna). Programu haithibitishi sheria; thibitisha na Tume ya Madini/mtaalamu.',
                  'There are no default rates: enter the current official rates (0 if none). The app does not verify the law; confirm with the Mining Commission/an expert.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _f('Royalty', _royalty, suffix: '%', numeric: true, validator: numValidator(c, min: 0, max: 100)),
            _f('Inspection fee', _inspection, suffix: '%', numeric: true, validator: numValidator(c, min: 0, max: 100)),
            _f(tr(c, 'Makato mengine', 'Other'), _otherStatutory, suffix: '%', numeric: true, validator: numValidator(c, min: 0, max: 100)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _royalty.text = '4';
                  _inspection.text = '0';
                  _otherStatutory.text = '0';
                }),
                child: Text(tr(c, 'Jaza mfano wa BoT (4% / 0%) — thibitisha', 'Fill BoT example (4% / 0%) — verify')),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _statutoryVerified,
              onChanged: (v) => setState(() => _statutoryVerified = v ?? false),
              title: Text(tr(c, 'Nimethibitisha viwango hivi na mamlaka/mtaalamu', 'I confirmed these rates with the authority/an expert')),
            ),
            if (_statutoryVerified)
              _f(tr(c, 'Rejea ya uthibitisho', 'Confirmation reference'), _statutoryRef, validator: _req),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _ackZeroStatutory,
              onChanged: (v) => setState(() => _ackZeroStatutory = v ?? false),
              title: Text(tr(c, 'Makato 0% ni kwa makusudi', 'A 0% deduction is intentional')),
            ),
            _f(tr(c, 'MTF 23 / control number (hiari)', 'MTF 23 / control number (optional)'), _mtf23),
            _h(tr(c, 'Bei ya ununuzi na lengo la faida', 'Purchase price and target profit')),
            _f(tr(c, 'Bei halisi ya ununuzi (hiari)', 'Actual purchase price (optional)'), _purchase,
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
              _f(tr(c, 'Faida lengwa', 'Target profit'), _targetProfit,
                  suffix: 'TZS', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0))
            else
              _f(tr(c, 'Margin lengwa', 'Target margin'), _targetMargin,
                  suffix: '%', numeric: true, hint: '0', validator: numValidator(c, required: false, min: 0, max: 100)),
            _h(tr(c, 'Scenarios', 'Scenarios')),
            _f(tr(c, 'Mshtuko wa purity (± pointi)', 'Purity stress (± points)'), _stressPurity,
                suffix: tr(c, 'pointi', 'points'), numeric: true, validator: numValidator(c, min: 0, max: 20)),
            _f(tr(c, 'Mshtuko wa bei (± %)', 'Price stress (± %)'), _stressPrice,
                suffix: '%', numeric: true, validator: numValidator(c, min: 0, max: 90)),
            _f(tr(c, 'Maelezo', 'Notes'), _notes, maxLines: 3),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _calculateAndSave,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate),
              label: Text(tr(c, 'Kokotoa na hifadhi', 'Calculate and save')),
            ),
          ],
        ),
      ),
    );
  }
}
