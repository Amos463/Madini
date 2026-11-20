import 'package:decimal/decimal.dart';

import '../domain/dore_models.dart';
import '../domain/recovery_models.dart';
import '../domain/valuation_models.dart';

/// Matokeo ya kukagua upya rekodi iliyohifadhiwa kwa injini ya sasa.
class RecomputeCheck {
  const RecomputeCheck({
    required this.matches,
    required this.differences,
    this.formulaChanged = false,
    this.storedFormulaVersion,
  });
  final bool matches;
  final List<String> differences;

  /// Kweli kama rekodi ilihifadhiwa kwa toleo tofauti la formula. Tofauti za
  /// hesabu katika hali hii zinatarajiwa na SI ushahidi wa kubadilishwa kwa data
  /// (muhuri wa uadilifu ndio unaothibitisha kutobadilishwa).
  final bool formulaChanged;
  final String? storedFormulaVersion;
}

class ScenarioSet {
  const ScenarioSet(this.conservative, this.expected, this.optimistic);
  final ValuationResult conservative;
  final ValuationResult expected;
  final ValuationResult optimistic;

  Map<String, dynamic> toMap() => {
        'conservative': conservative.toMap(),
        'expected': expected.toMap(),
        'optimistic': optimistic.toMap(),
      };
}

/// INJINI MOJA ya hesabu ya MADINI. Fomu, ripoti, historia na ukaguzi wa upya
/// zote zinaitumia; hakuna formula nyingine popote.
///
/// Mlolongo wa hesabu (kila hatua Decimal; double ni kwa pato tu):
///   dry mass         = wet mass × (1 − moisture)
///   contained gold   = dry tonnes × grade (g/t)
///   recovered gold   = contained × recovery            (tayari ni dhahabu safi)
///   payable gold     = recovered × payability
///   revenue          = payable × gold price
///   statutory        = revenue × (royalty + inspection + other)%
///   costs            = chemicals + processing + transport + other
///   net              = revenue − statutory − costs
///   maximum bid      = net − target profit
///   profit           = net − purchase price
/// Matokeo halisi: fine gold = product mass × purity (mara moja tu).
///
/// Sheria za ushahidi: ore ya sulfide haithaminiwi kwa recovery ya kudhani;
/// asilimia ya sulfide haitabiri recovery; ushahidi (jaribio la metallurgical au
/// historia ya uzalishaji) unahitaji rejea.
/// Hii ni zana ya kusaidia uamuzi, si cheti cha assay wala ofa rasmi.
class ValuationEngine {
  static const String formulaVersion = 'MADINI v1.8-recovery-dore-decimal';

  static final Decimal _milli = Decimal.parse('0.001'); // 1 / 1000
  static final Decimal _centi = Decimal.parse('0.01'); // 1 / 100

  static Decimal _d(double value, String field) {
    if (!value.isFinite) throw ArgumentError('$field must be a finite number.');
    // toStringAsFixed huepuka e-notation (mf. 1e-7) inayovunja Decimal.parse.
    return Decimal.parse(value.toStringAsFixed(12));
  }

  static void _nonNegative(double value, String field) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('$field must be finite and non-negative.');
    }
  }

  static void _fraction(double value, String field, {bool allowOne = true}) {
    if (!value.isFinite || value < 0 || (allowOne ? value > 1 : value >= 1)) {
      throw ArgumentError(
          '$field must be between 0 and 1${allowOne ? ' inclusive' : ' exclusive'}.');
    }
  }

  // ------------------------------------------------------- hatua za hesabu

  static double dryWeight(double wetWeight, double moistureFraction) {
    _nonNegative(wetWeight, 'Wet weight');
    _fraction(moistureFraction, 'Moisture', allowOne: false);
    return (_d(wetWeight, 'Wet weight') *
            (Decimal.one - _d(moistureFraction, 'Moisture')))
        .toDouble();
  }

  static double dryTonnes(double wetWeightKg, double moistureFraction) {
    _nonNegative(wetWeightKg, 'Wet weight');
    _fraction(moistureFraction, 'Moisture', allowOne: false);
    final dryKg = _d(wetWeightKg, 'Wet weight') *
        (Decimal.one - _d(moistureFraction, 'Moisture'));
    return (dryKg * _milli).toDouble();
  }

  static double containedGoldGrams(double dryTonnesValue, double gradeGramsPerTonne) {
    _nonNegative(dryTonnesValue, 'Dry tonnes');
    _nonNegative(gradeGramsPerTonne, 'Grade');
    return (_d(dryTonnesValue, 'Dry tonnes') * _d(gradeGramsPerTonne, 'Grade'))
        .toDouble();
  }

  static double recoveredGold(double containedGold, double recoveryFraction) {
    _nonNegative(containedGold, 'Contained gold');
    _fraction(recoveryFraction, 'Recovery');
    return (_d(containedGold, 'Contained gold') * _d(recoveryFraction, 'Recovery'))
        .toDouble();
  }

  /// Dhahabu safi kutoka uzito wa bidhaa na purity: product mass × purity.
  static double fineGold(double productMassGrams, double purityFraction) {
    _nonNegative(productMassGrams, 'Product mass');
    if (!purityFraction.isFinite || purityFraction <= 0 || purityFraction > 1) {
      throw ArgumentError('Purity must be greater than 0 and at most 1 (100%).');
    }
    return (_d(productMassGrams, 'Product mass') * _d(purityFraction, 'Purity'))
        .toDouble();
  }

  static double payableGold(double recoveredGoldValue, double payabilityFraction) {
    _nonNegative(recoveredGoldValue, 'Recovered gold');
    _fraction(payabilityFraction, 'Payability');
    return (_d(recoveredGoldValue, 'Recovered gold') *
            _d(payabilityFraction, 'Payability'))
        .toDouble();
  }

  static double estimatedRevenue(double payableGoldValue, double pricePerGram) {
    _nonNegative(payableGoldValue, 'Payable gold');
    _nonNegative(pricePerGram, 'Gold price');
    return (_d(payableGoldValue, 'Payable gold') * _d(pricePerGram, 'Gold price'))
        .toDouble();
  }

  static double maximumBid(double revenue, double processingCosts,
      double transportCosts, double otherCosts, double targetProfit,
      {double statutoryDeductions = 0, double chemicalCosts = 0}) {
    for (final entry in <String, double>{
      'Revenue': revenue,
      'Processing costs': processingCosts,
      'Transport costs': transportCosts,
      'Other costs': otherCosts,
      'Chemical costs': chemicalCosts,
      'Target profit': targetProfit,
      'Statutory deductions': statutoryDeductions,
    }.entries) {
      _nonNegative(entry.value, entry.key);
    }
    return (_d(revenue, 'Revenue') -
            _d(processingCosts, 'Processing costs') -
            _d(chemicalCosts, 'Chemical costs') -
            _d(transportCosts, 'Transport costs') -
            _d(otherCosts, 'Other costs') -
            _d(statutoryDeductions, 'Statutory deductions') -
            _d(targetProfit, 'Target profit'))
        .toDouble();
  }

  // ------------------------------------------------------------ ukaguzi

  static void _validate(ValuationInput input) {
    if (input.mode != 'laboratory') {
      throw ArgumentError('Field screening cannot be used to calculate a purchase valuation.');
    }
    if (input.title.trim().isEmpty || input.sampleId.trim().isEmpty) {
      throw ArgumentError('Assessment title and sample ID are required.');
    }
    if (!input.wetWeight.isFinite || input.wetWeight <= 0) {
      throw ArgumentError('Wet weight must be finite and greater than zero.');
    }
    _fraction(input.moistureFraction, 'Moisture', allowOne: false);
    _nonNegative(input.gradeGramsPerTonne, 'Laboratory grade');
    _fraction(input.recoveryFraction, 'Recovery');
    _fraction(input.payabilityFraction, 'Payability');
    _nonNegative(input.processingCosts, 'Processing costs');
    _nonNegative(input.chemicalCosts, 'Chemical costs');
    _nonNegative(input.transportCosts, 'Transport costs');
    _nonNegative(input.otherCosts, 'Other costs');
    _nonNegative(input.purchasePrice, 'Purchase price');
    _nonNegative(input.goldPricePerGram, 'Gold price');
    _nonNegative(input.targetProfit, 'Target profit');
    if (input.goldPricePerGram <= 0) {
      throw ArgumentError('Gold price must be greater than zero.');
    }
    if (input.targetMode != 'fixed' && input.targetMode != 'percentage') {
      throw ArgumentError('Target mode must be fixed or percentage.');
    }
    if (!input.targetMarginPercent.isFinite ||
        input.targetMarginPercent < 0 ||
        input.targetMarginPercent > 100) {
      throw ArgumentError('Target margin must be between 0 and 100 percent.');
    }
    for (final entry in <String, double>{
      'Royalty percent': input.royaltyPercent,
      'Inspection fee percent': input.inspectionFeePercent,
      'Other statutory percent': input.otherStatutoryPercent,
    }.entries) {
      if (!entry.value.isFinite || entry.value < 0 || entry.value > 100) {
        throw ArgumentError('${entry.key} must be between 0 and 100.');
      }
    }
    if (_statutoryPercent(input) > Decimal.fromInt(100)) {
      throw ArgumentError('Total statutory percent cannot exceed 100.');
    }
    if (!OreTypes.all.contains(input.oreType)) {
      throw ArgumentError('Unknown ore type: ${input.oreType}.');
    }
    if (!RecoveryEvidenceTypes.all.contains(input.recoveryEvidence)) {
      throw ArgumentError('Unknown recovery evidence type: ${input.recoveryEvidence}.');
    }
    final sulfide = input.sulfidePercent;
    if (sulfide != null && (!sulfide.isFinite || sulfide < 0 || sulfide > 100)) {
      throw ArgumentError('Sulfide percent must be between 0 and 100.');
    }
    final evidenced = RecoveryEvidenceTypes.isEvidenced(input.recoveryEvidence);
    if (evidenced && input.recoveryEvidenceRef.trim().isEmpty) {
      throw ArgumentError(
          'Recovery evidence needs a reference (test report number or production batch/period).');
    }
    if (OreTypes.requiresEvidence(input.oreType) && !evidenced) {
      throw ArgumentError(
          'Sulfide ore cannot be valued with an assumed recovery. Provide a metallurgical test or production history; sulfide percentage alone does not predict recovery.');
    }
  }

  static Decimal _statutoryPercent(ValuationInput input) =>
      _d(input.royaltyPercent, 'Royalty percent') +
      _d(input.inspectionFeePercent, 'Inspection fee percent') +
      _d(input.otherStatutoryPercent, 'Other statutory percent');

  static Decimal _containedOf(ValuationInput input) {
    final dryKg = _d(input.wetWeight, 'Wet weight') *
        (Decimal.one - _d(input.moistureFraction, 'Moisture'));
    return dryKg * _milli * _d(input.gradeGramsPerTonne, 'Grade');
  }

  /// Maonyo yanayotokana na ingizo (lugha mbili kwa kila ujumbe).
  static List<String> advisories(ValuationInput input) {
    final out = <String>[];
    final evidenced = RecoveryEvidenceTypes.isEvidenced(input.recoveryEvidence);
    if (!evidenced) {
      out.add('Recovery ni dhana tu (haina jaribio wala historia); bei ni ya KUKADIRIA. / Recovery is an assumption without a test or production history; the bid is INDICATIVE only.');
    } else {
      out.add('Rejea ya jaribio/historia imeingizwa na mtumiaji; MADINI haijathibitisha uhalisi wa nyaraka au data za uzalishaji. / The test/history reference is user-entered; MADINI does not authenticate the report or production data.');
    }
    if (input.oreType == OreTypes.transition && !evidenced) {
      out.add('Ore ya transition: recovery inatofautiana sana; pata jaribio la metallurgical. / Transition ore: recovery varies widely; obtain a metallurgical test.');
    }
    final sulfide = input.sulfidePercent;
    if (sulfide != null && sulfide > 0) {
      out.add('Sulfide ${sulfide.toStringAsFixed(1)}% imerekodiwa. Asilimia hii pekee haitabiri recovery; recovery inatokana na ushahidi wa majaribio/uzalishaji. / Sulfide ${sulfide.toStringAsFixed(1)}% recorded. This alone does not predict recovery; recovery comes from test or production evidence.');
    }
    if (!input.statutoryVerified) {
      out.add('Makato ya kisheria ni makadirio ya mtumiaji; programu haithibitishi kuwa ni sheria rasmi. / Statutory deductions are user estimates; the app does not verify them as official law.');
    }
    if (input.purchasePrice <= 0) {
      out.add('Bei ya ununuzi haijawekwa: "faida" ni kabla ya ununuzi. / Purchase price not entered: "profit" is before purchase.');
    }
    return out;
  }

  // -------------------------------------------------------------- hesabu

  static ValuationResult calculate(ValuationInput input, {String scenario = 'expected'}) {
    _validate(input);
    final statutoryPercent = _statutoryPercent(input);
    final wet = _d(input.wetWeight, 'Wet weight');
    final moisture = _d(input.moistureFraction, 'Moisture');
    final dryKg = wet * (Decimal.one - moisture);
    final dryTonnesValue = dryKg * _milli;
    final contained = dryTonnesValue * _d(input.gradeGramsPerTonne, 'Grade');
    final recovered = contained * _d(input.recoveryFraction, 'Recovery');
    final payable = recovered * _d(input.payabilityFraction, 'Payability');
    final revenue = payable * _d(input.goldPricePerGram, 'Gold price');
    final statutory = revenue * statutoryPercent * _centi;
    final chemicals = _d(input.chemicalCosts, 'Chemical costs');
    final costs = chemicals +
        _d(input.processingCosts, 'Processing costs') +
        _d(input.transportCosts, 'Transport costs') +
        _d(input.otherCosts, 'Other costs');
    final target = input.targetMode == 'fixed'
        ? _d(input.targetProfit, 'Target profit')
        : revenue * _d(input.targetMarginPercent, 'Target margin') * _centi;
    final net = revenue - statutory - costs;
    final bid = net - target;
    final profit = net - _d(input.purchasePrice, 'Purchase price');
    final evidenced = RecoveryEvidenceTypes.isEvidenced(input.recoveryEvidence);

    return ValuationResult(
      dryWeight: dryKg.toDouble(),
      dryTonnes: dryTonnesValue.toDouble(),
      containedGold: contained.toDouble(),
      recoveredGold: recovered.toDouble(),
      payableGold: payable.toDouble(),
      revenue: revenue.toDouble(),
      statutoryDeductions: statutory.toDouble(),
      maximumBid: bid.toDouble(),
      isPositive: bid > Decimal.zero,
      scenario: scenario,
      gradeUsed: input.gradeGramsPerTonne,
      priceUsed: input.goldPricePerGram,
      recoveryUsed: input.recoveryFraction,
      chemicalCosts: chemicals.toDouble(),
      totalCosts: costs.toDouble(),
      netBeforePurchase: net.toDouble(),
      purchasePrice: input.purchasePrice,
      profit: profit.toDouble(),
      recoveryEvidence: input.recoveryEvidence,
      recoveryVerified: evidenced,
      oreType: input.oreType,
      confidence: evidenced
          ? 'Estimate: recovery evidence was declared by the user; MADINI has not independently authenticated the report or production data. Assay, price and deductions are user-entered. Not a certified offer.'
          : 'INDICATIVE only: recovery is an unverified assumption. Not a certified offer.',
    );
  }

  /// Scenarios tatu kutoka injini ile ile: grade (chini/juu) pamoja na mshtuko
  /// wa bei na recovery (0 = grade pekee).
  static ScenarioSet scenarios(
    ValuationInput base, {
    required double lowestGrade,
    required double highestGrade,
    double stressPricePercent = 0,
    double stressRecoveryPoints = 0,
  }) {
    if (!stressPricePercent.isFinite || stressPricePercent < 0 || stressPricePercent > 90) {
      throw ArgumentError('Price stress must be between 0 and 90 percent.');
    }
    if (!stressRecoveryPoints.isFinite || stressRecoveryPoints < 0 || stressRecoveryPoints > 50) {
      throw ArgumentError('Recovery stress must be between 0 and 50 points.');
    }
    if (!lowestGrade.isFinite || !highestGrade.isFinite ||
        lowestGrade < 0 || highestGrade < 0 || lowestGrade > highestGrade) {
      throw ArgumentError('Assay grade range must be finite, non-negative and ordered.');
    }
    final price = _d(base.goldPricePerGram, 'Gold price');
    final pct = _d(stressPricePercent, 'Price stress') * _centi;
    final pts = _d(stressRecoveryPoints, 'Recovery stress') * _centi;
    final rec = _d(base.recoveryFraction, 'Recovery');
    var low = rec - pts;
    if (low < Decimal.zero) low = Decimal.zero;
    var high = rec + pts;
    if (high > Decimal.one) high = Decimal.one;
    final conservative = calculate(
        base.copyWith(
          grade: lowestGrade,
          price: (price * (Decimal.one - pct)).toDouble(),
          recovery: low.toDouble(),
        ),
        scenario: 'conservative');
    final expected = calculate(base, scenario: 'expected');
    final optimistic = calculate(
        base.copyWith(
          grade: highestGrade,
          price: (price * (Decimal.one + pct)).toDouble(),
          recovery: high.toDouble(),
        ),
        scenario: 'optimistic');
    return ScenarioSet(conservative, expected, optimistic);
  }

  // ------------------------------------------------- makadirio dhidi ya halisi

  /// Hulinganisha makadirio ([estimate], expected scenario) na matokeo halisi.
  /// Fine gold halisi = product mass × purity (purity mara moja tu).
  static ActualComparison compareActual(
      ValuationInput input, ValuationResult estimate, ActualOutcome actual) {
    _validate(input);
    if (!actual.productMassGrams.isFinite || actual.productMassGrams <= 0) {
      throw ArgumentError('Product mass must be greater than zero.');
    }
    if (!actual.purityFraction.isFinite ||
        actual.purityFraction <= 0 ||
        actual.purityFraction > 1) {
      throw ArgumentError('Purity must be greater than 0 and at most 1 (100%).');
    }
    final salePrice = actual.salePricePerGram ?? input.goldPricePerGram;
    if (!salePrice.isFinite || salePrice <= 0) {
      throw ArgumentError('Sale price must be greater than zero.');
    }
    final overrides = <String, double?>{
      'Chemical costs': actual.chemicalCosts,
      'Processing costs': actual.processingCosts,
      'Transport costs': actual.transportCosts,
      'Other costs': actual.otherCosts,
    };
    for (final e in overrides.entries) {
      if (e.value != null) _nonNegative(e.value!, e.key);
    }

    final fine = _d(actual.productMassGrams, 'Product mass') *
        _d(actual.purityFraction, 'Purity'); // purity mara moja tu
    final contained = _containedOf(input);
    final payable = fine * _d(input.payabilityFraction, 'Payability');
    final revenue = payable * _d(salePrice, 'Sale price');
    final statutory = revenue * _statutoryPercent(input) * _centi;
    final costs = _d(actual.chemicalCosts ?? input.chemicalCosts, 'Chemical costs') +
        _d(actual.processingCosts ?? input.processingCosts, 'Processing costs') +
        _d(actual.transportCosts ?? input.transportCosts, 'Transport costs') +
        _d(actual.otherCosts ?? input.otherCosts, 'Other costs');
    final profit = revenue - statutory - costs - _d(input.purchasePrice, 'Purchase price');

    final estFine = _d(estimate.recoveredGold, 'Estimated fine gold');
    final varianceGrams = fine - estFine;
    final double? variancePct = estFine > Decimal.zero
        ? varianceGrams.toDouble() / estFine.toDouble() * 100
        : null;
    final double? actualRecovery = contained > Decimal.zero
        ? fine.toDouble() / contained.toDouble()
        : null;
    final double? recoveryPoints = actualRecovery == null
        ? null
        : (actualRecovery - estimate.recoveryUsed) * 100;

    final warnings = <String>[];
    if (actualRecovery != null && actualRecovery > 1.0) {
      warnings.add('Recovery halisi ni zaidi ya 100%: kuna uwezekano wa kosa la assay, sampling, uzito au purity. / Actual recovery exceeds 100%: likely an assay, sampling, weighing or purity error.');
    }
    if (actual.purityFraction < 0.5) {
      warnings.add('Purity iko chini ya 50%: hakiki kipimo cha purity. / Purity is below 50%: verify the purity measurement.');
    }
    if (recoveryPoints != null && recoveryPoints.abs() > 10) {
      warnings.add('Tofauti ya recovery ni zaidi ya pointi 10 dhidi ya makadirio; kagua ushahidi wa recovery uliotumika. / Recovery differs by more than 10 points from the estimate; review the recovery evidence used.');
    }

    return ActualComparison(
      productMassGrams: actual.productMassGrams,
      purityFraction: actual.purityFraction,
      actualFineGold: fine.toDouble(),
      actualRecoveryFraction: actualRecovery,
      actualPayableGold: payable.toDouble(),
      salePriceUsed: salePrice,
      actualRevenue: revenue.toDouble(),
      actualStatutoryDeductions: statutory.toDouble(),
      actualTotalCosts: costs.toDouble(),
      actualProfit: profit.toDouble(),
      estimatedFineGold: estimate.recoveredGold,
      estimatedRecoveryFraction: estimate.recoveryUsed,
      estimatedRevenue: estimate.revenue,
      estimatedProfit: estimate.profit,
      fineGoldVarianceGrams: varianceGrams.toDouble(),
      fineGoldVariancePercent: variancePct,
      recoveryVariancePoints: recoveryPoints,
      revenueVariance: (revenue - _d(estimate.revenue, 'Estimated revenue')).toDouble(),
      profitVariance: (profit - _d(estimate.profit, 'Estimated profit')).toDouble(),
      warnings: warnings,
    );
  }

  /// Ulinganisho kwa rekodi iliyohifadhiwa: estimate inakokotolewa tena na
  /// injini ile ile kutoka kwa `values` zilizohifadhiwa.
  static ActualComparison compareActualForStored(
      Map<String, dynamic> values, ActualOutcome actual) {
    final input = ValuationInput.fromMap(values);
    return compareActual(input, calculate(input), actual);
  }

  // ------------------------------------------------ kurudia hesabu ya historia

  static bool _close(Object? a, Object? b, double tolerance) =>
      a is num && b is num && (a.toDouble() - b.toDouble()).abs() <= tolerance;

  static void _compareStoredMap({
    required String name,
    required Map stored,
    required Map<String, dynamic> fresh,
    required List<String> numericFields,
    required List<String> exactFields,
    required List<String> diffs,
  }) {
    for (final key in numericFields) {
      final oldValue = stored[key];
      final newValue = fresh[key];
      final tolerance = <String>{
        'dryWeight', 'dryTonnes', 'containedGold', 'recoveredGold',
        'payableGold', 'netMassGrams', 'fineGold', 'purityUsed',
        'purityMeasured', 'gradeUsed', 'recoveryUsed',
      }.contains(key) ? 1e-6 : 0.01;
      if (!stored.containsKey(key) || oldValue is! num || newValue is! num ||
          !_close(oldValue, newValue, tolerance)) {
        diffs.add('$name.$key: stored value is missing, invalid or differs from recomputation.');
      }
    }
    for (final key in exactFields) {
      if (!stored.containsKey(key) || stored[key] != fresh[key]) {
        diffs.add('$name.$key: stored value is missing or differs from recomputation.');
      }
    }
  }

  /// Hurudia hesabu kutoka kwa `values` zilizohifadhiwa na kulinganisha na
  /// `result` iliyohifadhiwa. Tofauti inamaanisha rekodi imebadilishwa nje ya
  /// app, au formula imebadilika tangu rekodi ilipohifadhiwa.
  static RecomputeCheck recheckStored({
    required Map<String, dynamic> values,
    required Map<String, dynamic> result,
    String? storedFormulaVersion,
  }) {
    final diffs = <String>[];
    try {
      final base = ValuationInput.fromMap(values);
      final rawGrades = values['assayGradesGpt'];
      if (rawGrades != null && rawGrades is! List) {
        throw const FormatException('assayGradesGpt lazima iwe orodha.');
      }
      final grades = <double>[];
      for (final value in (rawGrades as List? ?? const [])) {
        if (value is! num || !value.toDouble().isFinite || value < 0) {
          throw const FormatException('Kuna assay grade isiyo sahihi kwenye rekodi.');
        }
        grades.add(value.toDouble());
      }
      var lowest = base.gradeGramsPerTonne;
      var highest = base.gradeGramsPerTonne;
      for (final g in grades) {
        if (g < lowest) lowest = g;
        if (g > highest) highest = g;
      }
      final set = scenarios(
        base,
        lowestGrade: lowest,
        highestGrade: highest,
        stressPricePercent:
            values['stressPricePercent'] is num ? (values['stressPricePercent'] as num).toDouble() : 0,
        stressRecoveryPoints:
            values['stressRecoveryPoints'] is num ? (values['stressRecoveryPoints'] as num).toDouble() : 0,
      );
      final stored = result['scenarios'] is Map ? result['scenarios'] as Map : const {};
      if (result['scenarios'] is! Map) {
        diffs.add('scenarios: saved scenario set is missing or invalid.');
      }
      final fresh = <String, ValuationResult>{
        'conservative': set.conservative,
        'expected': set.expected,
        'optimistic': set.optimistic,
      };
      for (final entry in fresh.entries) {
        final raw = stored[entry.key];
        final scenarioMap = raw is Map ? raw : (entry.key == 'expected' ? result : null);
        if (scenarioMap == null) {
          diffs.add('${entry.key}: saved scenario is missing.');
          continue;
        }
        _compareStoredMap(
          name: entry.key,
          stored: scenarioMap,
          fresh: entry.value.toMap(),
          numericFields: [
            'dryWeight', 'dryTonnes', 'containedGold', 'recoveredGold',
            'payableGold', 'revenue', 'statutoryDeductions', 'maximumBid',
            'gradeUsed', 'priceUsed', 'recoveryUsed', 'chemicalCosts',
            'totalCosts', 'netBeforePurchase', 'purchasePrice', 'profit',
          ],
          exactFields: [
            'isPositive', 'scenario', 'recoveryEvidence',
            'recoveryVerified', 'oreType',
          ],
          diffs: diffs,
        );
      }
    } catch (e) {
      diffs.add('recompute error: $e');
    }
    return RecomputeCheck(
      matches: diffs.isEmpty,
      differences: diffs,
      formulaChanged: storedFormulaVersion != null && storedFormulaVersion != formulaVersion,
      storedFormulaVersion: storedFormulaVersion,
    );
  }

  // ======================================================================= DORÉ
  //
  // Mlolongo (Decimal; double ni kwa pato tu):
  //   net mass     = gross × (1 − weight loss)
  //   purity used  = measured purity − caution points / 100
  //   fine gold    = net mass × purity used            (purity mara moja tu)
  //   payable gold = fine gold × payability
  //   revenue      = payable × gold price
  //   statutory    = revenue × (royalty + inspection + other)%
  //   costs        = refining/assay + transport + other
  //   net          = revenue − statutory − costs
  //   maximum bid  = net − target profit
  //   profit       = net − purchase price

  static Decimal _pctSum(double royalty, double inspection, double other) =>
      _d(royalty, 'Royalty percent') +
      _d(inspection, 'Inspection fee percent') +
      _d(other, 'Other statutory percent');

  static Decimal _doreUsedPurity(DoreInput i) =>
      _d(i.measuredPurityFraction, 'Purity') -
      _d(i.purityCautionPoints, 'Purity caution') * _centi;

  static void _validateDore(DoreInput i) {
    if (i.title.trim().isEmpty || i.sampleId.trim().isEmpty) {
      throw ArgumentError('Assessment title and sample ID are required.');
    }
    if (!i.grossMassGrams.isFinite || i.grossMassGrams <= 0) {
      throw ArgumentError('Dore mass must be finite and greater than zero.');
    }
    _fraction(i.weightLossFraction, 'Weight loss', allowOne: false);
    if (!i.measuredPurityFraction.isFinite ||
        i.measuredPurityFraction <= 0 ||
        i.measuredPurityFraction > 1) {
      throw ArgumentError('Purity must be greater than 0 and at most 1 (100%).');
    }
    if (!DorePurityMethods.all.contains(i.purityMethod)) {
      throw ArgumentError('Unknown purity method: ${i.purityMethod}.');
    }
    if (!i.purityCautionPoints.isFinite || i.purityCautionPoints < 0 || i.purityCautionPoints > 50) {
      throw ArgumentError('Purity caution must be between 0 and 50 points.');
    }
    if (DorePurityMethods.isVerified(i.purityMethod) && i.purityReference.trim().isEmpty) {
      throw ArgumentError('Fire assay purity needs a report reference.');
    }
    _fraction(i.payabilityFraction, 'Payability');
    _nonNegative(i.refiningCosts, 'Refining costs');
    _nonNegative(i.transportCosts, 'Transport costs');
    _nonNegative(i.otherCosts, 'Other costs');
    _nonNegative(i.purchasePrice, 'Purchase price');
    _nonNegative(i.targetProfit, 'Target profit');
    if (!i.goldPricePerGram.isFinite || i.goldPricePerGram <= 0) {
      throw ArgumentError('Gold price must be greater than zero.');
    }
    if (i.targetMode != 'fixed' && i.targetMode != 'percentage') {
      throw ArgumentError('Target mode must be fixed or percentage.');
    }
    if (!i.targetMarginPercent.isFinite || i.targetMarginPercent < 0 || i.targetMarginPercent > 100) {
      throw ArgumentError('Target margin must be between 0 and 100 percent.');
    }
    for (final e in <String, double>{
      'Royalty percent': i.royaltyPercent,
      'Inspection fee percent': i.inspectionFeePercent,
      'Other statutory percent': i.otherStatutoryPercent,
    }.entries) {
      if (!e.value.isFinite || e.value < 0 || e.value > 100) {
        throw ArgumentError('${e.key} must be between 0 and 100.');
      }
    }
    if (_pctSum(i.royaltyPercent, i.inspectionFeePercent, i.otherStatutoryPercent) >
        Decimal.fromInt(100)) {
      throw ArgumentError('Total statutory percent cannot exceed 100.');
    }
    final scale = i.scaleResolutionGrams;
    if (scale != null) {
      _nonNegative(scale, 'Scale resolution');
      if (scale >= i.grossMassGrams) {
        throw ArgumentError('Scale resolution must be smaller than the measured dore mass.');
      }
    }
    if (_doreUsedPurity(i) <= Decimal.zero) {
      throw ArgumentError('Purity after caution must remain greater than zero.');
    }
  }

  static DoreResult _calcDore(DoreInput i, Decimal purityUsed, double price, String scenario) {
    final net = _d(i.grossMassGrams, 'Dore mass') * (Decimal.one - _d(i.weightLossFraction, 'Weight loss'));
    final fine = net * purityUsed;
    final payable = fine * _d(i.payabilityFraction, 'Payability');
    final revenue = payable * _d(price, 'Gold price');
    final statutory =
        revenue * _pctSum(i.royaltyPercent, i.inspectionFeePercent, i.otherStatutoryPercent) * _centi;
    final costs = _d(i.refiningCosts, 'Refining costs') +
        _d(i.transportCosts, 'Transport costs') +
        _d(i.otherCosts, 'Other costs');
    final target = i.targetMode == 'fixed'
        ? _d(i.targetProfit, 'Target profit')
        : revenue * _d(i.targetMarginPercent, 'Target margin') * _centi;
    final net2 = revenue - statutory - costs;
    final bid = net2 - target;
    final profit = net2 - _d(i.purchasePrice, 'Purchase price');
    final verified = DorePurityMethods.isVerified(i.purityMethod);
    return DoreResult(
      netMassGrams: net.toDouble(),
      purityMeasured: i.measuredPurityFraction,
      purityUsed: purityUsed.toDouble(),
      fineGold: fine.toDouble(),
      payableGold: payable.toDouble(),
      revenue: revenue.toDouble(),
      statutoryDeductions: statutory.toDouble(),
      totalCosts: costs.toDouble(),
      netBeforePurchase: net2.toDouble(),
      purchasePrice: i.purchasePrice,
      profit: profit.toDouble(),
      maximumBid: bid.toDouble(),
      isPositive: bid > Decimal.zero,
      scenario: scenario,
      priceUsed: price,
      purityMethod: i.purityMethod,
      purityVerified: verified,
      confidence: verified
          ? 'Estimate: user declared a fire assay report and entered its reference; MADINI has not authenticated the report or laboratory. Mass, price and deductions are user-entered. Not a certified offer.'
          : 'INDICATIVE only: purity is not backed by a declared fire assay. Not a certified offer.',
    );
  }

  static DoreResult calculateDore(DoreInput input, {String scenario = 'expected'}) {
    _validateDore(input);
    return _calcDore(input, _doreUsedPurity(input), input.goldPricePerGram, scenario);
  }

  /// Scenarios: purity (± pointi) na bei (± %), kutoka injini ile ile.
  static DoreScenarioSet doreScenarios(
    DoreInput base, {
    double stressPurityPoints = 0,
    double stressPricePercent = 0,
  }) {
    _validateDore(base);
    if (!stressPurityPoints.isFinite || stressPurityPoints < 0 || stressPurityPoints > 20) {
      throw ArgumentError('Purity stress must be between 0 and 20 points.');
    }
    if (!stressPricePercent.isFinite || stressPricePercent < 0 || stressPricePercent > 90) {
      throw ArgumentError('Price stress must be between 0 and 90 percent.');
    }
    final used = _doreUsedPurity(base);
    final pts = _d(stressPurityPoints, 'Purity stress') * _centi;
    final pct = _d(stressPricePercent, 'Price stress') * _centi;
    final price = _d(base.goldPricePerGram, 'Gold price');
    var low = used - pts;
    if (low < Decimal.zero) low = Decimal.zero;
    var high = used + pts;
    if (high > Decimal.one) high = Decimal.one;
    return DoreScenarioSet(
      _calcDore(base, low, (price * (Decimal.one - pct)).toDouble(), 'conservative'),
      _calcDore(base, used, base.goldPricePerGram, 'expected'),
      _calcDore(base, high, (price * (Decimal.one + pct)).toDouble(), 'optimistic'),
    );
  }

  /// Maonyo kutokana na ingizo la doré (lugha mbili kwa kila ujumbe).
  static List<String> doreAdvisories(DoreInput i) {
    final out = <String>[];
    final verified = DorePurityMethods.isVerified(i.purityMethod);
    if (!verified) {
      out.add('Purity haijathibitishwa kwa fire assay; bei ni ya KUKADIRIA. / Purity is not backed by a fire assay; the bid is INDICATIVE only.');
    } else {
      out.add('Fire assay na rejea vimetajwa na mtumiaji; MADINI haijathibitisha uhalisi wa ripoti au maabara. / Fire assay and its reference are user-declared; MADINI does not authenticate the report or laboratory.');
    }
    if (i.purityMethod == DorePurityMethods.xrf) {
      out.add('XRF hupima uso tu; kipande kinaweza kuwa na dhahabu juu na chuma ndani. / XRF reads the surface only; a piece can be gold outside and base metal inside.');
    }
    if (i.purityMethod == DorePurityMethods.visual) {
      out.add('Purity ya kuangalia kwa macho haijapimwa. / Visual purity has not been measured.');
    }
    if (!verified && i.purityCautionPoints <= 0) {
      out.add('Tahadhari ya purity ni 0 kwa njia isiyo ya fire assay; hatari ya hasara ni kubwa. / Purity caution is 0 for a non-fire-assay method; the loss risk is high.');
    }
    if (i.weightLossFraction <= 0) {
      out.add('Hakuna punguzo la uzito (unyevu/zebaki/slag): hakikisha doré imekauka/imechomwa. / No weight deduction (moisture/mercury/slag): make sure the dore is dry/fired.');
    }
    final scale = i.scaleResolutionGrams;
    if (scale != null && scale > 0 && i.grossMassGrams > 0) {
      final relative = scale / i.grossMassGrams * 100;
      if (relative > 0.5) {
        out.add('Usahihi wa mizani ni ${relative.toStringAsFixed(2)}% ya uzito; kutokuwa na uhakika wa uzito ni juu. / Scale resolution is ${relative.toStringAsFixed(2)}% of the mass; weight uncertainty is high.');
      }
    }
    if (!i.statutoryVerified) {
      out.add('Makato ya kisheria ni makadirio ya mtumiaji; programu haithibitishi kuwa ni sheria rasmi. / Statutory deductions are user estimates; the app does not verify them as official law.');
    }
    if (i.purchasePrice <= 0) {
      out.add('Bei ya ununuzi haijawekwa: "faida" ni kabla ya ununuzi. / Purchase price not entered: "profit" is before purchase.');
    }
    return out;
  }

  /// Hulinganisha makadirio ya doré na matokeo halisi ya refinery/mnunuzi.
  /// [actual].productMassGrams/purityFraction = uzito na purity ya refinery;
  /// processingCosts = gharama halisi za refining/assay; chemicalCosts haitumiki.
  static DoreActualComparison compareActualDore(
      DoreInput input, DoreResult estimate, ActualOutcome actual) {
    _validateDore(input);
    if (!actual.productMassGrams.isFinite || actual.productMassGrams <= 0) {
      throw ArgumentError('Refinery mass must be greater than zero.');
    }
    if (!actual.purityFraction.isFinite || actual.purityFraction <= 0 || actual.purityFraction > 1) {
      throw ArgumentError('Purity must be greater than 0 and at most 1 (100%).');
    }
    final salePrice = actual.salePricePerGram ?? input.goldPricePerGram;
    if (!salePrice.isFinite || salePrice <= 0) {
      throw ArgumentError('Sale price must be greater than zero.');
    }
    for (final e in <String, double?>{
      'Refining costs': actual.processingCosts,
      'Transport costs': actual.transportCosts,
      'Other costs': actual.otherCosts,
    }.entries) {
      if (e.value != null) _nonNegative(e.value!, e.key);
    }

    final fine = _d(actual.productMassGrams, 'Refinery mass') * _d(actual.purityFraction, 'Purity');
    final payable = fine * _d(input.payabilityFraction, 'Payability');
    final revenue = payable * _d(salePrice, 'Sale price');
    final statutory =
        revenue * _pctSum(input.royaltyPercent, input.inspectionFeePercent, input.otherStatutoryPercent) * _centi;
    final costs = _d(actual.processingCosts ?? input.refiningCosts, 'Refining costs') +
        _d(actual.transportCosts ?? input.transportCosts, 'Transport costs') +
        _d(actual.otherCosts ?? input.otherCosts, 'Other costs');
    final profit = revenue - statutory - costs - _d(input.purchasePrice, 'Purchase price');

    final estFine = _d(estimate.fineGold, 'Estimated fine gold');
    final varianceGrams = fine - estFine;
    final double? variancePct =
        estFine > Decimal.zero ? varianceGrams.toDouble() / estFine.toDouble() * 100 : null;
    final purityPoints =
        ((_d(actual.purityFraction, 'Purity') - _d(estimate.purityUsed, 'Purity used')) * Decimal.fromInt(100))
            .toDouble();

    final warnings = <String>[];
    if (actual.purityFraction < 0.5) {
      warnings.add('Purity ya refinery iko chini ya 50%: hakiki kipimo. / Refinery purity is below 50%: verify the measurement.');
    }
    if (purityPoints < -3) {
      warnings.add('Purity halisi iko chini ya makadirio kwa zaidi ya pointi 3 (njia: ${input.purityMethod}). / Actual purity is more than 3 points below the estimate (method: ${input.purityMethod}).');
    }
    if (variancePct != null && variancePct.abs() > 5) {
      warnings.add('Tofauti ya dhahabu safi ni zaidi ya 5% dhidi ya makadirio. / Fine gold differs by more than 5% from the estimate.');
    }
    final estNet = estimate.netMassGrams;
    if (estNet > 0 && ((actual.productMassGrams - estNet) / estNet).abs() > 0.02) {
      warnings.add('Uzito wa refinery unatofautiana na uzito wa makadirio kwa zaidi ya 2% (mizani, unyevu au upotevu). / Refinery mass differs from the estimated net mass by more than 2% (scale, moisture or loss).');
    }

    return DoreActualComparison(
      refineryMassGrams: actual.productMassGrams,
      refineryPurityFraction: actual.purityFraction,
      actualFineGold: fine.toDouble(),
      estimatedFineGold: estimate.fineGold,
      fineGoldVarianceGrams: varianceGrams.toDouble(),
      fineGoldVariancePercent: variancePct,
      purityUsedEstimate: estimate.purityUsed,
      purityVariancePoints: purityPoints,
      actualPayableGold: payable.toDouble(),
      salePriceUsed: salePrice,
      actualRevenue: revenue.toDouble(),
      actualStatutoryDeductions: statutory.toDouble(),
      actualTotalCosts: costs.toDouble(),
      actualProfit: profit.toDouble(),
      estimatedRevenue: estimate.revenue,
      estimatedProfit: estimate.profit,
      revenueVariance: (revenue - _d(estimate.revenue, 'Estimated revenue')).toDouble(),
      profitVariance: (profit - _d(estimate.profit, 'Estimated profit')).toDouble(),
      warnings: warnings,
    );
  }

  static DoreActualComparison compareActualDoreForStored(
      Map<String, dynamic> values, ActualOutcome actual) {
    final input = DoreInput.fromMap(values);
    return compareActualDore(input, calculateDore(input), actual);
  }

  /// Hurudia hesabu ya doré kutoka kwa rekodi iliyohifadhiwa na kulinganisha.
  static RecomputeCheck recheckStoredDore({
    required Map<String, dynamic> values,
    required Map<String, dynamic> result,
    String? storedFormulaVersion,
  }) {
    final diffs = <String>[];
    try {
      final base = DoreInput.fromMap(values);
      final set = doreScenarios(
        base,
        stressPurityPoints:
            values['stressPurityPoints'] is num ? (values['stressPurityPoints'] as num).toDouble() : 0,
        stressPricePercent:
            values['stressPricePercent'] is num ? (values['stressPricePercent'] as num).toDouble() : 0,
      );
      final stored = result['scenarios'] is Map ? result['scenarios'] as Map : const {};
      if (result['scenarios'] is! Map) {
        diffs.add('scenarios: saved scenario set is missing or invalid.');
      }
      final fresh = <String, DoreResult>{
        'conservative': set.conservative,
        'expected': set.expected,
        'optimistic': set.optimistic,
      };
      for (final entry in fresh.entries) {
        final raw = stored[entry.key];
        final scenarioMap = raw is Map ? raw : (entry.key == 'expected' ? result : null);
        if (scenarioMap == null) {
          diffs.add('${entry.key}: saved scenario is missing.');
          continue;
        }
        _compareStoredMap(
          name: entry.key,
          stored: scenarioMap,
          fresh: entry.value.toMap(),
          numericFields: [
            'netMassGrams', 'purityMeasured', 'purityUsed', 'fineGold',
            'payableGold', 'revenue', 'statutoryDeductions', 'totalCosts',
            'netBeforePurchase', 'purchasePrice', 'profit', 'maximumBid',
            'priceUsed',
          ],
          exactFields: [
            'kind', 'isPositive', 'scenario', 'purityMethod',
            'purityVerified',
          ],
          diffs: diffs,
        );
      }
    } catch (e) {
      diffs.add('recompute error: $e');
    }
    return RecomputeCheck(
      matches: diffs.isEmpty,
      differences: diffs,
      formulaChanged: storedFormulaVersion != null && storedFormulaVersion != formulaVersion,
      storedFormulaVersion: storedFormulaVersion,
    );
  }
}

/// Ubadilishaji wa bei ya dhahabu kutoka USD/ounce (troy) kwenda TZS/gram.
class PriceConverter {
  /// 1 troy ounce = 31.1034768 g, hivyo 1 / 31.1034768 = 0.03215074656862798.
  static final Decimal _gramsPerOunceInverse = Decimal.parse('0.03215074656862798');

  static double usdPerOunceToTzsPerGram(double usdPerOunce, double tzsPerUsd) {
    if (!usdPerOunce.isFinite || usdPerOunce <= 0) {
      throw ArgumentError('USD per ounce must be greater than zero.');
    }
    if (!tzsPerUsd.isFinite || tzsPerUsd <= 0) {
      throw ArgumentError('TZS per USD must be greater than zero.');
    }
    return (Decimal.parse(usdPerOunce.toStringAsFixed(12)) *
            Decimal.parse(tzsPerUsd.toStringAsFixed(12)) *
            _gramsPerOunceInverse)
        .toDouble();
  }
}

/// Ubadilishaji wa karat kwenda purity (sehemu). 24k = 1.0, 22k = 22/24.
/// Hesabu ni ya double (kwa kuwa 22/24 ni desimali isiyoisha); inapoingia
/// kwenye injini inabadilishwa kuwa Decimal yenye tarakimu 12.
class PurityConverter {
  static double karatToFraction(double karat) {
    if (!karat.isFinite || karat <= 0 || karat > 24) {
      throw ArgumentError('Karat must be greater than 0 and at most 24.');
    }
    return karat / 24;
  }
}
