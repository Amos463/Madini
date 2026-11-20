import '../core/format.dart';
import 'dore_models.dart';
import 'gold_assessment.dart';
import 'recovery_models.dart';

class SummaryRow {
  const SummaryRow(this.sw, this.en, this.value);
  final String sw;
  final String en;
  final String value;
}

class SummarySection {
  const SummarySection(this.sw, this.en, this.rows, {this.notes = const []});
  final String sw;
  final String en;
  final List<SummaryRow> rows;
  final List<String> notes;
}

/// Mtazamo MMOJA wa tathmini unaotumiwa na ukurasa wa historia na ripoti ya
/// PDF. Haikokotoi chochote: inasoma tu namba zilizokokotolewa na
/// `ValuationEngine` na kuhifadhiwa kwenye rekodi.
class AssessmentSummary {
  static const String disclaimerSw =
      'Makadirio tu. Thibitisha assay, recovery (jaribio la metallurgical au historia ya uzalishaji), payability, chanzo na tarehe ya bei, na wajibu wa kisheria/kodi kabla ya ununuzi. Makato ya kisheria ni makadirio ya mtumiaji, si thibitisho la programu.';
  static const String disclaimerEn =
      'Estimate only. Verify assay, recovery (metallurgical test or production history), payability, price source/date and statutory obligations before any purchase. Statutory deductions are user estimates, not verified by the app. Not a certified offer, assay certificate or legal advice.';

  static String _t(Object? v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  static String _m(Object? v) => v is num ? formatMoney(v) : '-';
  static String _g(Object? v) => v is num ? formatGrams(v) : '-';
  static String _p(Object? v) => v is num ? formatFractionAsPercent(v) : '-';
  static String _pp(Object? v) => v is num ? formatPercentValue(v) : '-';
  static String _signed(Object? v, String Function(Object?) f) {
    if (v is! num) return '-';
    return '${v > 0 ? '+' : ''}${f(v)}';
  }

  static String _sealText(Object? seal) {
    if (seal is! Map) return 'Haipo (rekodi ya zamani) / None (older record)';
    final sha = seal['sha256'];
    if (sha is! String || sha.length < 16) return 'Haieleweki / Unreadable';
    return '${sha.substring(0, 16)}... (${_t(seal['version'])})';
  }

  static String _bi(String sw, String en) => sw == en ? sw : '$sw / $en';

  static List<SummarySection> build(GoldAssessment a) {
    final v = a.values;
    final r = a.result;
    final out = <SummarySection>[];

    out.add(SummarySection('Utambulisho', 'Identification', [
      SummaryRow('Kichwa', 'Title', _t(a.title)),
      SummaryRow('Aina', 'Mode', a.isField ? 'Field screening' : 'Laboratory'),
      SummaryRow('Imeundwa', 'Created', a.createdAt.toLocal().toString().split('.').first),
      SummaryRow('Assessment ID', 'Assessment ID', a.id),
      SummaryRow('Sample ID', 'Sample ID', _t(v['sampleId'])),
      SummaryRow('Lot ID', 'Lot ID', _t(v['lotId'])),
      SummaryRow('Eneo', 'Source location', _t(v['sourceLocation'])),
      SummaryRow('Muuzaji', 'Seller', _t(v['sellerName'])),
      SummaryRow('Leseni/ID ya muuzaji', 'Seller licence/ID', _t(v['sellerLicence'])),
      SummaryRow('MTF 23 / control number', 'MTF 23 / control number', _t(v['mtf23Reference'])),
      SummaryRow('Toleo la formula', 'Formula version', _t(a.formulaVersion)),
      SummaryRow('Muhuri wa uadilifu', 'Integrity seal', _sealText(r['integritySeal'])),
    ]));

    if (a.isField) {
      out.add(SummarySection('Field screening - si grade wala bei ya ununuzi',
          'Field screening - not a grade or purchase price', [
        SummaryRow('Sehemu za sampuli', 'Sampling points', _t(v['samplingPoints'])),
        SummaryRow('Uwakilishi (kauli ya mtumiaji)', 'Representativeness (user claim)', _t(v['representativeClaimed'])),
        SummaryRow('Uchunguzi', 'Observations', _t(v['observations'])),
        SummaryRow('Pendekezo', 'Recommendation', _t(r['recommendation'])),
      ]));
      return out;
    }

    if (a.mode == 'dore') return _buildDore(a, out);

    final scen = r['scenarios'] is Map ? r['scenarios'] as Map : const {};
    final exp = scen['expected'] is Map ? scen['expected'] as Map : r;
    final oreType = _t(v['oreType'] ?? OreTypes.other);
    final evidence = _t(v['recoveryEvidence'] ?? RecoveryEvidenceTypes.assumption);
    final verified = exp['recoveryVerified'] == true;

    out.add(SummarySection('Ore na ushahidi wa recovery', 'Ore and recovery evidence', [
      SummaryRow('Aina ya ore', 'Ore type',
          _bi(OreTypes.label(oreType, sw: true), OreTypes.label(oreType, sw: false))),
      SummaryRow('Sulfide', 'Sulfide',
          v['sulfidePercent'] is num ? _pp(v['sulfidePercent']) : '-'),
      SummaryRow('Ushahidi wa recovery', 'Recovery evidence',
          _bi(RecoveryEvidenceTypes.label(evidence, sw: true), RecoveryEvidenceTypes.label(evidence, sw: false))),
      SummaryRow('Rejea ya ushahidi', 'Evidence reference', _t(v['recoveryEvidenceRef'])),
      SummaryRow('Daraja la tathmini', 'Valuation grade',
          verified
              ? 'Ushahidi wa recovery umetajwa; MADINI haijathibitisha ripoti/uzalishaji / Recovery evidence declared by user; MADINI has not independently verified it'
              : 'KUKADIRIA TU (recovery ni dhana) / INDICATIVE ONLY (assumed recovery)'),
    ]));

    final grades = v['assayGradesGpt'] is List ? (v['assayGradesGpt'] as List).join('; ') : '-';
    out.add(SummarySection('Uzito, unyevu na grade', 'Mass, moisture and grade', [
      SummaryRow('Uzito mbichi (kg)', 'Wet mass (kg)', _g(v['wetWeight'])),
      SummaryRow('Unyevu', 'Moisture', _p(v['moistureFraction'])),
      SummaryRow('Uzito mkavu (kg)', 'Dry mass (kg)', _g(exp['dryWeight'])),
      SummaryRow('Uzito mkavu (tani)', 'Dry mass (tonnes)', _g(exp['dryTonnes'])),
      SummaryRow('Matokeo ya assay (g/t)', 'Assay results (g/t)', grades),
      SummaryRow('Msingi wa grade', 'Grade basis', _t(v['gradeBasis'])),
      SummaryRow('Grade iliyotumika (g/t)', 'Grade used (g/t)', _g(v['gradeGramsPerTonne'])),
      SummaryRow('Maabara / cheti', 'Laboratory / certificate',
          '${_t(v['laboratoryName'])} / ${_t(v['certificateNumber'])}'),
    ]));

    out.add(SummarySection('Mizani ya dhahabu (makadirio)', 'Gold balance (estimate)', [
      SummaryRow('Dhahabu iliyomo = tani kavu × grade', 'Contained gold = dry tonnes × grade', '${_g(exp['containedGold'])} g'),
      SummaryRow('Recovery', 'Recovery', _p(v['recoveryFraction'])),
      SummaryRow('Dhahabu safi inayokadiriwa = iliyomo × recovery', 'Estimated fine gold = contained × recovery', '${_g(exp['recoveredGold'])} g'),
      SummaryRow('Payability', 'Payability', _p(v['payabilityFraction'])),
      SummaryRow('Dhahabu safi inayolipiwa = safi × payability', 'Payable fine gold = fine × payability', '${_g(exp['payableGold'])} g'),
    ], notes: [
      'Recovery ya makadirio inatoa dhahabu safi moja kwa moja; purity haitumiki tena hapa. / Estimated recovery gives fine gold directly; purity is not applied again here.',
    ]));

    out.add(SummarySection('Bei ya dhahabu', 'Gold price', [
      SummaryRow('Bei (TZS/g)', 'Price (TZS/g)', _m(v['goldPricePerGram'])),
      SummaryRow('Chanzo', 'Source', _t(v['goldPriceSource'])),
      SummaryRow('Bei ya tarehe', 'Price quoted on', _t(v['goldPriceQuotedAt'])),
      SummaryRow('Imehifadhiwa', 'Saved at', _t(v['goldPriceSavedAt'])),
    ]));

    out.add(SummarySection('Mapato, gharama na faida', 'Revenue, costs and profit', [
      SummaryRow('Mapato = dhahabu inayolipiwa × bei', 'Revenue = payable gold × price', _m(exp['revenue'])),
      SummaryRow('Gharama za kemikali', 'Chemical costs', _m(exp['chemicalCosts'] ?? v['chemicalCosts'])),
      SummaryRow('Gharama za usindikaji', 'Processing costs', _m(v['processingCosts'])),
      SummaryRow('Usafirishaji', 'Transport', _m(v['transportCosts'])),
      SummaryRow('Nyinginezo', 'Other costs', _m(v['otherCosts'])),
      SummaryRow('Gharama zote', 'Total costs', _m(exp['totalCosts'])),
      SummaryRow('Makato % (royalty / inspection / mengine)', 'Deductions % (royalty / inspection / other)',
          '${_t(v['royaltyPercent'])} / ${_t(v['inspectionFeePercent'])} / ${_t(v['otherStatutoryPercent'])}'),
      SummaryRow('Makato (TZS)', 'Statutory deductions (TZS)', _m(exp['statutoryDeductions'])),
      SummaryRow('Hali ya makato', 'Deduction status',
          v['statutoryVerified'] == true
              ? 'Imethibitishwa na mtumiaji: ${_t(v['statutoryReference'])} / User-confirmed: ${_t(v['statutoryReference'])}'
              : 'Makadirio ya mtumiaji (hayajathibitishwa) / User estimate (not verified)'),
      SummaryRow('Mapato baada ya makato na gharama', 'Net = revenue − deductions − costs', _m(exp['netBeforePurchase'])),
      SummaryRow('Bei ya ununuzi', 'Purchase price', exp['purchasePrice'] is num && (exp['purchasePrice'] as num) > 0 ? _m(exp['purchasePrice']) : 'Haijawekwa / Not entered'),
      SummaryRow('Faida = mapato − makato − gharama − ununuzi', 'Profit = revenue − deductions − costs − purchase', _m(exp['profit'])),
      SummaryRow('Faida lengwa', 'Target profit',
          v['targetMode'] == 'percentage' ? '${_t(v['targetMarginPercent'])}% ya mapato / of revenue' : _m(v['targetProfit'])),
      SummaryRow('Bei ya juu ya kununua', 'Maximum bid', _m(exp['maximumBid'])),
    ]));

    final scenRows = <SummaryRow>[];
    for (final name in ['conservative', 'expected', 'optimistic']) {
      final s = scen[name];
      if (s is! Map) continue;
      scenRows.add(SummaryRow(name, name,
          'grade ${_g(s['gradeUsed'])} g/t • ${_m(s['priceUsed'])} TZS/g • recovery ${_p(s['recoveryUsed'])} • fine gold ${_g(s['recoveredGold'])} g • mapato/revenue ${_m(s['revenue'])} • bid ${_m(s['maximumBid'])}'));
    }
    if (scenRows.isNotEmpty) {
      out.add(SummarySection('Scenarios', 'Scenarios', scenRows));
    }

    final cmp = r['assayComparison'] is Map ? r['assayComparison'] as Map : const {};
    if (cmp.isNotEmpty) {
      out.add(SummarySection('Ulinganisho wa assay', 'Assay comparison', [
        SummaryRow('Idadi', 'Samples', _t(cmp['count'])),
        SummaryRow('Wastani (g/t)', 'Mean (g/t)', _g(cmp['meanGramsPerTonne'])),
        SummaryRow('Median (g/t)', 'Median (g/t)', _g(cmp['medianGramsPerTonne'])),
        SummaryRow('CV', 'CV', cmp['coefficientOfVariationPercent'] == null ? 'N/A' : _pp(cmp['coefficientOfVariationPercent'])),
        SummaryRow('max/min', 'max/min', cmp['rangeRatio'] is num ? _g(cmp['rangeRatio']) : 'N/A'),
      ], notes: [
        for (final w in (cmp['warnings'] is List ? cmp['warnings'] as List : const [])) '$w',
      ]));
    }

    final actual = r['actualComparison'];
    final outcome = v['actualOutcome'];
    if (actual is Map && outcome is Map) {
      final a2 = actual;
      out.add(SummarySection('Makadirio dhidi ya matokeo halisi', 'Estimate vs actual outcome', [
        SummaryRow('Toleo la matokeo', 'Outcome version', _t(outcome['version'] ?? 1)),
        SummaryRow('Rejea / tarehe', 'Reference / date', '${_t(outcome['reference'])} / ${_t(outcome['recordedAt'])}'),
        SummaryRow('Uzito wa bidhaa (g)', 'Product mass (g)', _g(a2['productMassGrams'])),
        SummaryRow('Purity', 'Purity', _p(a2['purityFraction'])),
        SummaryRow('Dhahabu safi halisi = bidhaa × purity', 'Actual fine gold = product × purity', '${_g(a2['actualFineGold'])} g'),
        SummaryRow('Dhahabu safi iliyokadiriwa', 'Estimated fine gold', '${_g(a2['estimatedFineGold'])} g'),
        SummaryRow('Tofauti (halisi − makadirio)', 'Variance (actual − estimate)',
            '${_signed(a2['fineGoldVarianceGrams'], _g)} g (${a2['fineGoldVariancePercent'] == null ? 'N/A' : _signed(a2['fineGoldVariancePercent'], _pp)})'),
        SummaryRow('Recovery: makadirio / halisi', 'Recovery: estimate / actual',
            '${_p(a2['estimatedRecoveryFraction'])} / ${a2['actualRecoveryFraction'] == null ? 'N/A' : _p(a2['actualRecoveryFraction'])}'),
        SummaryRow('Tofauti ya recovery (pointi)', 'Recovery variance (points)',
            a2['recoveryVariancePoints'] == null ? 'N/A' : _signed(a2['recoveryVariancePoints'], _g)),
        SummaryRow('Bei ya kuuzia iliyotumika (TZS/g)', 'Sale price used (TZS/g)', _m(a2['salePriceUsed'])),
        SummaryRow('Mapato: makadirio / halisi', 'Revenue: estimate / actual',
            '${_m(a2['estimatedRevenue'])} / ${_m(a2['actualRevenue'])}'),
        SummaryRow('Gharama halisi / makato halisi', 'Actual costs / deductions',
            '${_m(a2['actualTotalCosts'])} / ${_m(a2['actualStatutoryDeductions'])}'),
        SummaryRow('Faida: makadirio / halisi', 'Profit: estimate / actual',
            '${_m(a2['estimatedProfit'])} / ${_m(a2['actualProfit'])}'),
        SummaryRow('Tofauti ya faida', 'Profit variance', _signed(a2['profitVariance'], _m)),
      ], notes: [
        if (outcome['needsReview'] == true)
          'INAHITAJI UKAGUZI: matokeo yalihifadhiwa licha ya maonyo. / NEEDS REVIEW: saved despite warnings.',
        if (outcome['correctionReason'] is String)
          'Sababu ya marekebisho / Correction reason: ${outcome['correctionReason']}',
        for (final w in (a2['warnings'] is List ? a2['warnings'] as List : const [])) '$w',
      ]));
    } else {
      out.add(const SummarySection('Matokeo halisi', 'Actual outcome', [
        SummaryRow('Hali', 'Status', 'Bado hayajarekodiwa / Not recorded yet'),
      ]));
    }

    final hist = _historySection(v);
    if (hist != null) out.add(hist);

    final warnings = r['warnings'] is List ? r['warnings'] as List : const [];
    if (warnings.isNotEmpty) {
      out.add(SummarySection('Maonyo', 'Warnings', const [], notes: [for (final w in warnings) '$w']));
    }
    return out;
  }

  /// Matoleo ya zamani ya matokeo halisi (append-only); hayafutwi kamwe.
  static SummarySection? _historySection(Map v) {
    final h = v['actualOutcomeHistory'];
    if (h is! List || h.isEmpty) return null;
    final rows = <SummaryRow>[];
    for (final e in h) {
      if (e is! Map) continue;
      final o = e['outcome'] is Map ? e['outcome'] as Map : const {};
      final c = e['comparison'] is Map ? e['comparison'] as Map : const {};
      final fine = c['actualFineGold'];
      rows.add(SummaryRow(
        'Toleo ${_t(e['version'])} (limebadilishwa)',
        'Version ${_t(e['version'])} (superseded)',
        'rejea/reference ${_t(o['reference'])} • iliyorekodiwa/recorded ${_t(o['recordedAt'])} • dhahabu safi/fine gold ${fine is num ? _g(fine) : '-'} g • ilibadilishwa/superseded ${_t(e['supersededAt'])} • sababu/reason: ${_t(e['correctionReason'])}',
      ));
    }
    return SummarySection('Historia ya matoleo ya matokeo halisi', 'Actual outcome version history', rows);
  }

  static List<SummarySection> _buildDore(GoldAssessment a, List<SummarySection> out) {
    final v = a.values;
    final r = a.result;
    final scen = r['scenarios'] is Map ? r['scenarios'] as Map : const {};
    final exp = scen['expected'] is Map ? scen['expected'] as Map : r;
    final method = _t(v['purityMethod'] ?? DorePurityMethods.visual);
    final verified = exp['purityVerified'] == true;

    out.add(SummarySection('Doré na purity', 'Dore and purity', [
      SummaryRow('Uzito wa doré (g)', 'Dore mass (g)', _g(v['grossMassGrams'])),
      SummaryRow('Punguzo la uzito (unyevu/zebaki/slag)', 'Weight deduction (moisture/mercury/slag)', _p(v['weightLossFraction'])),
      SummaryRow('Uzito halisi (g) = doré × (1 − punguzo)', 'Net mass (g) = dore × (1 − deduction)', _g(exp['netMassGrams'])),
      SummaryRow('Usahihi wa mizani (g)', 'Scale resolution (g)', v['scaleResolutionGrams'] is num ? _g(v['scaleResolutionGrams']) : '-'),
      SummaryRow('Njia ya kupima purity', 'Purity method',
          _bi(DorePurityMethods.label(method, sw: true), DorePurityMethods.label(method, sw: false))),
      SummaryRow('Rejea ya purity', 'Purity reference', _t(v['purityReference'])),
      SummaryRow('Purity iliyopimwa', 'Measured purity', _p(v['measuredPurityFraction'])),
      SummaryRow('Tahadhari ya purity (pointi)', 'Purity caution (points)', _t(v['purityCautionPoints'])),
      SummaryRow('Purity iliyotumika = iliyopimwa − tahadhari', 'Purity used = measured − caution', _p(exp['purityUsed'])),
      SummaryRow('Daraja la tathmini', 'Valuation grade',
          verified
              ? 'Fire assay imeripotiwa na rejea imewekwa; MADINI haijathibitisha uhalisi wa ripoti / Fire assay declared with a reference; MADINI has not authenticated the report'
              : 'KUKADIRIA TU (purity haijathibitishwa) / INDICATIVE ONLY (purity unverified)'),
    ]));

    out.add(SummarySection('Mizani ya dhahabu (doré)', 'Gold balance (dore)', [
      SummaryRow('Dhahabu safi = uzito halisi × purity iliyotumika', 'Fine gold = net mass × purity used', '${_g(exp['fineGold'])} g'),
      SummaryRow('Payability', 'Payability', _p(v['payabilityFraction'])),
      SummaryRow('Dhahabu safi inayolipiwa = safi × payability', 'Payable fine gold = fine × payability', '${_g(exp['payableGold'])} g'),
    ], notes: [
      'Purity inatumika mara moja tu (uzito halisi × purity). / Purity is applied once only (net mass × purity).',
    ]));

    out.add(SummarySection('Bei ya dhahabu', 'Gold price', [
      SummaryRow('Bei (TZS/g)', 'Price (TZS/g)', _m(v['goldPricePerGram'])),
      SummaryRow('Chanzo', 'Source', _t(v['goldPriceSource'])),
      SummaryRow('Bei ya tarehe', 'Price quoted on', _t(v['goldPriceQuotedAt'])),
      SummaryRow('Imehifadhiwa', 'Saved at', _t(v['goldPriceSavedAt'])),
    ]));

    out.add(SummarySection('Mapato, gharama na faida', 'Revenue, costs and profit', [
      SummaryRow('Mapato = dhahabu inayolipiwa × bei', 'Revenue = payable gold × price', _m(exp['revenue'])),
      SummaryRow('Refining / assay', 'Refining / assay', _m(v['refiningCosts'])),
      SummaryRow('Usafirishaji', 'Transport', _m(v['transportCosts'])),
      SummaryRow('Nyinginezo', 'Other costs', _m(v['otherCosts'])),
      SummaryRow('Gharama zote', 'Total costs', _m(exp['totalCosts'])),
      SummaryRow('Makato % (royalty / inspection / mengine)', 'Deductions % (royalty / inspection / other)',
          '${_t(v['royaltyPercent'])} / ${_t(v['inspectionFeePercent'])} / ${_t(v['otherStatutoryPercent'])}'),
      SummaryRow('Makato (TZS)', 'Statutory deductions (TZS)', _m(exp['statutoryDeductions'])),
      SummaryRow('Hali ya makato', 'Deduction status',
          v['statutoryVerified'] == true
              ? 'Imethibitishwa na mtumiaji: ${_t(v['statutoryReference'])} / User-confirmed: ${_t(v['statutoryReference'])}'
              : 'Makadirio ya mtumiaji (hayajathibitishwa) / User estimate (not verified)'),
      SummaryRow('Mapato baada ya makato na gharama', 'Net = revenue − deductions − costs', _m(exp['netBeforePurchase'])),
      SummaryRow('Bei ya ununuzi', 'Purchase price',
          exp['purchasePrice'] is num && (exp['purchasePrice'] as num) > 0 ? _m(exp['purchasePrice']) : 'Haijawekwa / Not entered'),
      SummaryRow('Faida = mapato − makato − gharama − ununuzi', 'Profit = revenue − deductions − costs − purchase', _m(exp['profit'])),
      SummaryRow('Faida lengwa', 'Target profit',
          v['targetMode'] == 'percentage' ? '${_t(v['targetMarginPercent'])}% ya mapato / of revenue' : _m(v['targetProfit'])),
      SummaryRow('Bei ya juu ya kununua', 'Maximum bid', _m(exp['maximumBid'])),
    ]));

    final scenRows = <SummaryRow>[];
    for (final name in ['conservative', 'expected', 'optimistic']) {
      final s = scen[name];
      if (s is! Map) continue;
      scenRows.add(SummaryRow(name, name,
          'purity ${_p(s['purityUsed'])} • ${_m(s['priceUsed'])} TZS/g • fine gold ${_g(s['fineGold'])} g • mapato/revenue ${_m(s['revenue'])} • bid ${_m(s['maximumBid'])}'));
    }
    if (scenRows.isNotEmpty) out.add(SummarySection('Scenarios', 'Scenarios', scenRows));

    final actual = r['actualComparison'];
    final outcome = v['actualOutcome'];
    if (actual is Map && outcome is Map) {
      out.add(SummarySection('Makadirio dhidi ya matokeo halisi ya refinery', 'Estimate vs actual refinery outcome', [
        SummaryRow('Toleo la matokeo', 'Outcome version', _t(outcome['version'] ?? 1)),
        SummaryRow('Rejea / tarehe', 'Reference / date', '${_t(outcome['reference'])} / ${_t(outcome['recordedAt'])}'),
        SummaryRow('Uzito wa refinery (g)', 'Refinery mass (g)', _g(actual['refineryMassGrams'])),
        SummaryRow('Purity ya refinery', 'Refinery purity', _p(actual['refineryPurityFraction'])),
        SummaryRow('Dhahabu safi halisi = uzito × purity', 'Actual fine gold = mass × purity', '${_g(actual['actualFineGold'])} g'),
        SummaryRow('Dhahabu safi iliyokadiriwa', 'Estimated fine gold', '${_g(actual['estimatedFineGold'])} g'),
        SummaryRow('Tofauti (halisi − makadirio)', 'Variance (actual − estimate)',
            '${_signed(actual['fineGoldVarianceGrams'], _g)} g (${actual['fineGoldVariancePercent'] == null ? 'N/A' : _signed(actual['fineGoldVariancePercent'], _pp)})'),
        SummaryRow('Purity: makadirio / halisi', 'Purity: estimate / actual',
            '${_p(actual['purityUsedEstimate'])} / ${_p(actual['refineryPurityFraction'])}'),
        SummaryRow('Tofauti ya purity (pointi)', 'Purity variance (points)', _signed(actual['purityVariancePoints'], _g)),
        SummaryRow('Bei ya kuuzia iliyotumika (TZS/g)', 'Sale price used (TZS/g)', _m(actual['salePriceUsed'])),
        SummaryRow('Mapato: makadirio / halisi', 'Revenue: estimate / actual',
            '${_m(actual['estimatedRevenue'])} / ${_m(actual['actualRevenue'])}'),
        SummaryRow('Gharama halisi / makato halisi', 'Actual costs / deductions',
            '${_m(actual['actualTotalCosts'])} / ${_m(actual['actualStatutoryDeductions'])}'),
        SummaryRow('Faida: makadirio / halisi', 'Profit: estimate / actual',
            '${_m(actual['estimatedProfit'])} / ${_m(actual['actualProfit'])}'),
        SummaryRow('Tofauti ya faida', 'Profit variance', _signed(actual['profitVariance'], _m)),
      ], notes: [
        if (outcome['needsReview'] == true)
          'INAHITAJI UKAGUZI: matokeo yalihifadhiwa licha ya maonyo. / NEEDS REVIEW: saved despite warnings.',
        if (outcome['correctionReason'] is String)
          'Sababu ya marekebisho / Correction reason: ${outcome['correctionReason']}',
        for (final w in (actual['warnings'] is List ? actual['warnings'] as List : const [])) '$w',
      ]));
    } else {
      out.add(const SummarySection('Matokeo halisi', 'Actual outcome', [
        SummaryRow('Hali', 'Status', 'Bado hayajarekodiwa / Not recorded yet'),
      ]));
    }

    final hist = _historySection(v);
    if (hist != null) out.add(hist);

    final warnings = r['warnings'] is List ? r['warnings'] as List : const [];
    if (warnings.isNotEmpty) {
      out.add(SummarySection('Maonyo', 'Warnings', const [], notes: [for (final w in warnings) '$w']));
    }
    return out;
  }
}
