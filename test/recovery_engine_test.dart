import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:madini/domain/assay_analysis.dart';
import 'package:madini/domain/assessment_summary.dart';
import 'package:madini/domain/gold_assessment.dart';
import 'package:madini/domain/recovery_models.dart';
import 'package:madini/domain/valuation_models.dart';
import 'package:madini/services/report_service.dart';
import 'package:madini/services/valuation_engine.dart';

/// Loti ya mfano (namba zimehakikiwa kwa Python Decimal):
/// 1000 kg, unyevu 8%, grade 10 g/t, recovery 80%, payability 90%, bei 230,000.
/// dry 920 kg -> contained 9.2 g -> recovered 7.36 g -> payable 6.624 g
/// revenue 1,523,520; statutory 7% = 106,646.4; costs 175,000;
/// net 1,241,873.6; bid (target 200,000) 1,041,873.6; profit (purchase 900,000) 341,873.6
ValuationInput lot({
  String oreType = OreTypes.oxide,
  double? sulfide,
  String evidence = RecoveryEvidenceTypes.metallurgicalTest,
  String ref = 'MET-001',
  double wet = 1000,
  double moisture = 0.08,
  double grade = 10,
  double recovery = 0.8,
  double payability = 0.9,
  double price = 230000,
  double chemical = 40000,
  double processing = 60000,
  double transport = 50000,
  double other = 25000,
  double royalty = 6,
  double inspection = 1,
  double otherStatutory = 0,
  double targetProfit = 200000,
  double purchase = 900000,
  String mode = 'laboratory',
}) =>
    ValuationInput(
      title: 'Lot A',
      mode: mode,
      wetWeight: wet,
      moistureFraction: moisture,
      gradeGramsPerTonne: grade,
      recoveryFraction: recovery,
      payabilityFraction: payability,
      processingCosts: processing,
      transportCosts: transport,
      otherCosts: other,
      chemicalCosts: chemical,
      goldPricePerGram: price,
      targetProfit: targetProfit,
      targetMarginPercent: 0,
      notes: '',
      sampleId: 'S-1',
      royaltyPercent: royalty,
      inspectionFeePercent: inspection,
      otherStatutoryPercent: otherStatutory,
      oreType: oreType,
      sulfidePercent: sulfide,
      recoveryEvidence: evidence,
      recoveryEvidenceRef: ref,
      purchasePrice: purchase,
    );

/// Inaiga kile fomu inahifadhi (values + result kutoka injini).
GoldAssessment assess(ValuationInput base,
    {List<double> grades = const [10], double pricePct = 0, double recPts = 0}) {
  final lowest = grades.reduce((a, b) => a < b ? a : b);
  final highest = grades.reduce((a, b) => a > b ? a : b);
  final set = ValuationEngine.scenarios(base,
      lowestGrade: lowest,
      highestGrade: highest,
      stressPricePercent: pricePct,
      stressRecoveryPoints: recPts);
  return GoldAssessment(
    id: 'a1',
    title: base.title,
    mode: 'laboratory',
    assessmentType: 'laboratory',
    createdAt: DateTime.utc(2026, 1, 2),
    formulaVersion: ValuationEngine.formulaVersion,
    values: {
      ...base.toMap(),
      'assayGradesGpt': grades,
      'gradeBasis': 'mean',
      'stressPricePercent': pricePct,
      'stressRecoveryPoints': recPts,
      'goldPriceSource': 'Buyer quote',
      'goldPriceQuotedAt': '2026-11-17',
    },
    result: {
      ...set.expected.toMap(),
      'scenarios': set.toMap(),
      'assayComparison': AssayAnalysisEngine.analyse(grades).toMap(),
      'warnings': ValuationEngine.advisories(base),
    },
    notes: '',
  );
}

GoldAssessment roundTrip(GoldAssessment a) {
  // Inaiga kuhifadhi kwenye database (values_json/result) na kufungua tena.
  final row = jsonDecode(jsonEncode(a.toDbMap())) as Map<String, dynamic>;
  return GoldAssessment.fromMap(row);
}

String rowValue(List<SummarySection> sections, bool Function(SummaryRow) test) =>
    sections.expand((s) => s.rows).firstWhere(test).value;

void main() {
  group('formula: kila hatua', () {
    final r = ValuationEngine.calculate(lot());

    test('uzito mkavu = wet × (1 − moisture)', () {
      expect(r.dryWeight, closeTo(920, 1e-9));
      expect(r.dryTonnes, closeTo(0.92, 1e-12));
    });
    test('dhahabu iliyomo = dry tonnes × grade', () {
      expect(r.containedGold, closeTo(9.2, 1e-9));
    });
    test('dhahabu iliyopatikana = contained × recovery', () {
      expect(r.recoveredGold, closeTo(7.36, 1e-9));
    });
    test('dhahabu inayolipiwa = recovered × payability', () {
      expect(r.payableGold, closeTo(6.624, 1e-9));
    });
    test('mapato = payable × bei', () {
      expect(r.revenue, closeTo(1523520, 1e-6));
    });
    test('makato, gharama, net, bid na faida', () {
      expect(r.statutoryDeductions, closeTo(106646.4, 1e-6));
      expect(r.totalCosts, closeTo(175000, 1e-9));
      expect(r.chemicalCosts, closeTo(40000, 1e-9));
      expect(r.netBeforePurchase, closeTo(1241873.6, 1e-6));
      expect(r.maximumBid, closeTo(1041873.6, 1e-6));
      expect(r.profit, closeTo(341873.6, 1e-6));
    });
    test('recovery evidence iliyotajwa si uthibitisho huru wa programu', () {
      expect(r.toMap()['recoveryEvidenceIndependentlyVerified'], isFalse);
      expect(r.confidence, contains('has not independently authenticated'));
    });
    test('hatua za static zinalingana na calculate()', () {
      final t = ValuationEngine.dryTonnes(1000, 0.08);
      final c = ValuationEngine.containedGoldGrams(t, 10);
      final rec = ValuationEngine.recoveredGold(c, 0.8);
      final pay = ValuationEngine.payableGold(rec, 0.9);
      expect(ValuationEngine.estimatedRevenue(pay, 230000), closeTo(r.revenue, 1e-6));
    });
  });

  group('moisture', () {
    test('moisture 0 inaacha uzito mkavu = mbichi', () {
      expect(ValuationEngine.calculate(lot(moisture: 0)).dryWeight, closeTo(1000, 1e-9));
    });
    test('unyevu mwingi unapunguza uzito mkavu na bei ya juu', () {
      final low = ValuationEngine.calculate(lot(moisture: 0.05));
      final high = ValuationEngine.calculate(lot(moisture: 0.20));
      expect(high.dryWeight, lessThan(low.dryWeight));
      expect(high.maximumBid, lessThan(low.maximumBid));
    });
    test('moisture 100% au hasi inakataliwa', () {
      expect(() => ValuationEngine.calculate(lot(moisture: 1)), throwsArgumentError);
      expect(() => ValuationEngine.calculate(lot(moisture: -0.01)), throwsArgumentError);
    });
  });

  group('purity (fine gold = product mass × purity, mara moja)', () {
    test('fineGold()', () {
      expect(ValuationEngine.fineGold(8.4, 0.85), closeTo(7.14, 1e-12));
      expect(ValuationEngine.fineGold(8.4, 0.85), isNot(closeTo(6.069, 1e-3)));
    });
    test('purity batili inakataliwa', () {
      expect(() => ValuationEngine.fineGold(8.4, 0), throwsArgumentError);
      expect(() => ValuationEngine.fineGold(8.4, 1.2), throwsArgumentError);
      expect(() => ValuationEngine.fineGold(-1, 0.9), throwsArgumentError);
    });
    test('compareActual haizidishi purity mara ya pili', () {
      final input = lot();
      final c = ValuationEngine.compareActual(input, ValuationEngine.calculate(input),
          const ActualOutcome(productMassGrams: 8.4, purityFraction: 0.85));
      expect(c.actualFineGold, closeTo(7.14, 1e-12));
    });
  });

  group('sulfide na ushahidi wa recovery', () {
    test('asilimia ya sulfide haibadilishi recovery wala matokeo yoyote', () {
      final a = ValuationEngine.calculate(lot()).toMap();
      for (final pct in [0.0, 5.0, 40.0, 100.0]) {
        final b = ValuationEngine.calculate(lot(sulfide: pct)).toMap();
        expect(b, equals(a), reason: 'sulfide $pct% haipaswi kubadilisha hesabu');
      }
    });
    test('ore ya sulfide + recovery ya kudhani inakataliwa', () {
      for (final type in [OreTypes.sulfide, OreTypes.refractorySulfide]) {
        expect(
            () => ValuationEngine.calculate(
                lot(oreType: type, evidence: RecoveryEvidenceTypes.assumption, ref: '')),
            throwsArgumentError);
      }
    });
    test('ore ya sulfide yenye jaribio + rejea inakubaliwa na ina alama ya ushahidi', () {
      final r = ValuationEngine.calculate(lot(oreType: OreTypes.sulfide, sulfide: 35));
      expect(r.recoveryVerified, isTrue);
      expect(r.toMap()['valuationGrade'], 'evidence_declared');
    });
    test('historia ya uzalishaji pia inakubaliwa', () {
      final r = ValuationEngine.calculate(lot(
          oreType: OreTypes.refractorySulfide,
          evidence: RecoveryEvidenceTypes.productionHistory,
          ref: 'Batch 2026-09'));
      expect(r.recoveryVerified, isTrue);
    });
    test('ushahidi bila rejea unakataliwa', () {
      expect(() => ValuationEngine.calculate(lot(ref: '  ')), throwsArgumentError);
    });
    test('ore isiyo ya sulfide yenye dhana tu inaruhusiwa lakini ni INDICATIVE', () {
      final r = ValuationEngine.calculate(
          lot(evidence: RecoveryEvidenceTypes.assumption, ref: ''));
      expect(r.recoveryVerified, isFalse);
      expect(r.toMap()['valuationGrade'], 'indicative');
      expect(r.confidence, contains('INDICATIVE'));
    });
    test('sulfide % batili au aina zisizojulikana zinakataliwa', () {
      expect(() => ValuationEngine.calculate(lot(sulfide: 120)), throwsArgumentError);
      expect(() => ValuationEngine.calculate(lot(sulfide: -1)), throwsArgumentError);
      expect(() => ValuationEngine.calculate(lot(oreType: 'magic')), throwsArgumentError);
      expect(() => ValuationEngine.calculate(lot(evidence: 'rumour')), throwsArgumentError);
    });
    test('maonyo yanataja sulfide, dhana na makato ambayo hayajathibitishwa', () {
      final text = ValuationEngine.advisories(
              lot(sulfide: 20, evidence: RecoveryEvidenceTypes.assumption, ref: '', purchase: 0))
          .join(' | ');
      expect(text, contains('Sulfide 20.0%'));
      expect(text, contains('INDICATIVE'));
      expect(text, contains('not verify'));
      expect(text, contains('Purchase price not entered'));
    });
  });

  group('gharama na faida', () {
    test('gharama za kemikali zinapunguza bid kwa kiasi hicho hasa', () {
      final none = ValuationEngine.calculate(lot(chemical: 0));
      final some = ValuationEngine.calculate(lot(chemical: 40000));
      expect(none.maximumBid - some.maximumBid, closeTo(40000, 1e-6));
      expect(some.totalCosts - none.totalCosts, closeTo(40000, 1e-9));
    });
    test('faida = net − bei ya ununuzi; bila ununuzi faida = net', () {
      final withPurchase = ValuationEngine.calculate(lot(purchase: 900000));
      expect(withPurchase.profit, closeTo(withPurchase.netBeforePurchase - 900000, 1e-6));
      final without = ValuationEngine.calculate(lot(purchase: 0));
      expect(without.profit, closeTo(without.netBeforePurchase, 1e-9));
    });
    test('hasara inaonekana kama faida hasi', () {
      final r = ValuationEngine.calculate(lot(purchase: 5000000));
      expect(r.profit, lessThan(0));
    });
    test('bid inaweza kuwa hasi na isPositive = false', () {
      final r = ValuationEngine.calculate(lot(price: 1000));
      expect(r.maximumBid, lessThan(0));
      expect(r.isPositive, isFalse);
    });
  });

  group('data zisizokubalika', () {
    final bad = <String, ValuationInput Function()>{
      'uzito 0': () => lot(wet: 0),
      'uzito NaN': () => lot(wet: double.nan),
      'grade hasi': () => lot(grade: -1),
      'grade infinity': () => lot(grade: double.infinity),
      'recovery > 1': () => lot(recovery: 1.1),
      'payability hasi': () => lot(payability: -0.1),
      'bei 0': () => lot(price: 0),
      'kemikali hasi': () => lot(chemical: -1),
      'usindikaji hasi': () => lot(processing: -1),
      'usafirishaji NaN': () => lot(transport: double.nan),
      'ununuzi hasi': () => lot(purchase: -1),
      'makato > 100': () => lot(royalty: 60, inspection: 50),
      'royalty hasi': () => lot(royalty: -1),
      'field mode': () => lot(mode: 'field'),
    };
    bad.forEach((name, build) {
      test(name, () => expect(() => ValuationEngine.calculate(build()), throwsArgumentError));
    });
  });

  group('makadirio dhidi ya matokeo halisi', () {
    final input = lot();
    final estimate = ValuationEngine.calculate(input);

    test('namba zote za ulinganisho', () {
      final c = ValuationEngine.compareActual(input, estimate,
          const ActualOutcome(productMassGrams: 8.4, purityFraction: 0.85));
      expect(c.actualFineGold, closeTo(7.14, 1e-12));
      expect(c.actualRecoveryFraction, closeTo(0.7760869565, 1e-9));
      expect(c.estimatedFineGold, closeTo(7.36, 1e-9));
      expect(c.fineGoldVarianceGrams, closeTo(-0.22, 1e-9));
      expect(c.fineGoldVariancePercent, closeTo(-2.98913043, 1e-6));
      expect(c.recoveryVariancePoints, closeTo(-2.39130435, 1e-6));
      expect(c.actualPayableGold, closeTo(6.426, 1e-9));
      expect(c.actualRevenue, closeTo(1477980, 1e-6));
      expect(c.actualStatutoryDeductions, closeTo(103458.6, 1e-6));
      expect(c.actualTotalCosts, closeTo(175000, 1e-9));
      expect(c.actualProfit, closeTo(299521.4, 1e-6));
      expect(c.revenueVariance, closeTo(-45540, 1e-6));
      expect(c.profitVariance, closeTo(-42352.2, 1e-6));
      expect(c.warnings, isEmpty);
    });
    test('bei halisi ya kuuzia na gharama halisi zinatumika zikiwekwa', () {
      final c = ValuationEngine.compareActual(
          input,
          estimate,
          const ActualOutcome(
              productMassGrams: 8.4,
              purityFraction: 0.85,
              salePricePerGram: 240000,
              chemicalCosts: 50000));
      expect(c.actualRevenue, closeTo(1542240, 1e-6));
      expect(c.salePriceUsed, 240000);
      expect(c.actualTotalCosts, closeTo(185000, 1e-9));
    });
    test('recovery halisi > 100% na purity ndogo zinaonywa', () {
      final c = ValuationEngine.compareActual(input, estimate,
          const ActualOutcome(productMassGrams: 12, purityFraction: 0.4));
      // 12 × 0.4 = 4.8 g (< contained) lakini purity < 50%
      expect(c.warnings.join(' '), contains('Purity'));
      final c2 = ValuationEngine.compareActual(input, estimate,
          const ActualOutcome(productMassGrams: 12, purityFraction: 1));
      expect(c2.actualRecoveryFraction, greaterThan(1));
      expect(c2.warnings.join(' '), contains('100%'));
    });
    test('pembejeo batili za matokeo halisi zinakataliwa', () {
      for (final o in const [
        ActualOutcome(productMassGrams: 0, purityFraction: 0.9),
        ActualOutcome(productMassGrams: 5, purityFraction: 0),
        ActualOutcome(productMassGrams: 5, purityFraction: 1.2),
        ActualOutcome(productMassGrams: 5, purityFraction: 0.9, salePricePerGram: 0),
        ActualOutcome(productMassGrams: 5, purityFraction: 0.9, chemicalCosts: -1),
      ]) {
        expect(() => ValuationEngine.compareActual(input, estimate, o), throwsArgumentError);
      }
    });
  });

  group('scenarios kutoka injini moja', () {
    test('grade + mshtuko wa bei na recovery', () {
      final set = ValuationEngine.scenarios(lot(),
          lowestGrade: 8, highestGrade: 12, stressPricePercent: 10, stressRecoveryPoints: 5);
      expect(set.expected.maximumBid, closeTo(1041873.6, 1e-3));
      expect(set.conservative.maximumBid, closeTo(581389.68, 1e-2));
      expect(set.optimistic.maximumBid, closeTo(1612165.224, 1e-2));
      expect(set.conservative.recoveryUsed, closeTo(0.75, 1e-12));
      expect(set.optimistic.recoveryUsed, closeTo(0.85, 1e-12));
      expect(set.conservative.priceUsed, closeTo(207000, 1e-6));
    });
    test('recovery haizidi 100% wala kushuka chini ya 0%', () {
      final hi = ValuationEngine.scenarios(lot(recovery: 0.98),
          lowestGrade: 10, highestGrade: 10, stressRecoveryPoints: 10);
      expect(hi.optimistic.recoveryUsed, 1.0);
      final lo = ValuationEngine.scenarios(lot(recovery: 0.03),
          lowestGrade: 10, highestGrade: 10, stressRecoveryPoints: 10);
      expect(lo.conservative.recoveryUsed, 0.0);
    });
    test('mshtuko batili unakataliwa', () {
      expect(() => ValuationEngine.scenarios(lot(), lowestGrade: 1, highestGrade: 2, stressPricePercent: 95),
          throwsArgumentError);
      expect(() => ValuationEngine.scenarios(lot(), lowestGrade: 1, highestGrade: 2, stressRecoveryPoints: 60),
          throwsArgumentError);
    });
  });

  group('kuhifadhi na kufungua tena assessment', () {
    test('values na result vinarudi kamili baada ya kuhifadhi na kufungua', () {
      final saved = assess(lot(sulfide: 12), grades: [9.5, 10, 10.5], pricePct: 10, recPts: 5);
      final reopened = roundTrip(saved);
      expect(reopened.id, saved.id);
      expect(reopened.values, equals(jsonDecode(jsonEncode(saved.values))));
      expect(reopened.result, equals(jsonDecode(jsonEncode(saved.result))));
      expect(reopened.values['oreType'], OreTypes.oxide);
      expect(reopened.values['sulfidePercent'], 12);
      expect(reopened.values['recoveryEvidenceRef'], 'MET-001');
      expect(reopened.values['chemicalCosts'], 40000);
    });
    test('hesabu inaweza kurudiwa kutoka kwa rekodi iliyofunguliwa', () {
      final reopened = roundTrip(assess(lot(), grades: [9, 10, 11], pricePct: 10, recPts: 5));
      final check = ValuationEngine.recheckStored(values: reopened.values, result: reopened.result);
      expect(check.matches, isTrue, reason: check.differences.join('; '));
    });
    test('ValuationInput.fromMap(toMap()) inatoa matokeo yale yale', () {
      final input = lot(sulfide: 3);
      final again = ValuationInput.fromMap(input.toMap());
      expect(ValuationEngine.calculate(again).toMap(), equals(ValuationEngine.calculate(input).toMap()));
    });
    test('rekodi za zamani (bila sehemu mpya) bado zinahakikiwa', () {
      final a = assess(lot(chemical: 0, purchase: 0, evidence: RecoveryEvidenceTypes.assumption, ref: ''));
      final values = Map<String, dynamic>.from(a.values)
        ..removeWhere((k, _) => const [
              'oreType', 'sulfidePercent', 'recoveryEvidence', 'recoveryEvidenceRef',
              'chemicalCosts', 'purchasePrice', 'statutoryVerified', 'statutoryReference',
            ].contains(k));
      final result = jsonDecode(jsonEncode(a.result)) as Map<String, dynamic>;
      for (final key in ['totalCosts', 'netBeforePurchase', 'profit', 'chemicalCosts', 'purchasePrice']) {
        result.remove(key);
        for (final s in (result['scenarios'] as Map).values) {
          (s as Map).remove(key);
        }
      }
      final check = ValuationEngine.recheckStored(values: values, result: result);
      expect(check.matches, isFalse, reason: 'Rekodi yenye fields muhimu zilizokosekana lazima itambuliwe kuwa incomplete.');
      expect(check.differences.join(' '), contains('totalCosts'));
    });
    test('scenario au field iliyokosekana inagunduliwa', () {
      final a = assess(lot());
      final result = Map<String, dynamic>.from(a.result);
      final scenarios = Map<String, dynamic>.from(result['scenarios'] as Map)..remove('optimistic');
      result['scenarios'] = scenarios;
      final check = ValuationEngine.recheckStored(values: a.values, result: result);
      expect(check.matches, isFalse);
      expect(check.differences.join(' '), contains('optimistic'));
    });
    test('grade range iliyopinduliwa inakataliwa', () {
      expect(
        () => ValuationEngine.scenarios(lot(), lowestGrade: 12, highestGrade: 8),
        throwsArgumentError,
      );
    });
    test('rekodi iliyobadilishwa inagunduliwa', () {
      final a = roundTrip(assess(lot()));
      final result = Map<String, dynamic>.from(a.result);
      final scen = Map<String, dynamic>.from(result['scenarios'] as Map);
      final expected = Map<String, dynamic>.from(scen['expected'] as Map)..['maximumBid'] = 9999999.0;
      scen['expected'] = expected;
      result['scenarios'] = scen;
      final check = ValuationEngine.recheckStored(values: a.values, result: result);
      expect(check.matches, isFalse);
      expect(check.differences.join(' '), contains('maximumBid'));
    });
    test('matokeo halisi yanahifadhiwa na kurudi baada ya kufungua', () {
      final base = assess(lot());
      const outcome = ActualOutcome(
          productMassGrams: 8.4, purityFraction: 0.85, reference: 'REF-77', recordedAt: '2026-11-18T10:00:00');
      final cmp = ValuationEngine.compareActualForStored(base.values, outcome);
      final updated = GoldAssessment(
        id: base.id, title: base.title, mode: base.mode, assessmentType: base.assessmentType,
        createdAt: base.createdAt, formulaVersion: base.formulaVersion,
        values: {...base.values, 'actualOutcome': outcome.toMap()},
        result: {...base.result, 'actualComparison': cmp.toMap()},
        notes: base.notes,
      );
      final reopened = roundTrip(updated);
      final restored = ActualOutcome.fromMap(reopened.values['actualOutcome'] as Map);
      expect(restored.productMassGrams, 8.4);
      expect(restored.purityFraction, 0.85);
      expect(restored.reference, 'REF-77');
      expect((reopened.result['actualComparison'] as Map)['actualFineGold'], closeTo(7.14, 1e-12));
      // Hesabu ya makadirio bado inalingana baada ya kuongeza matokeo halisi.
      expect(ValuationEngine.recheckStored(values: reopened.values, result: reopened.result).matches, isTrue);
    });
  });

  group('ripoti na historia (muhtasari mmoja)', () {
    final a = assess(lot(sulfide: 12), grades: [9.5, 10, 10.5], pricePct: 10, recPts: 5);

    test('historia inaonyesha uzito, moisture, grade, recovery, gharama na ushahidi', () {
      final sections = AssessmentSummary.build(a);
      expect(rowValue(sections, (r) => r.en == 'Wet mass (kg)'), '1,000.0000');
      expect(rowValue(sections, (r) => r.en == 'Moisture'), '8%');
      expect(rowValue(sections, (r) => r.en == 'Dry mass (kg)'), '920.0000');
      expect(rowValue(sections, (r) => r.en == 'Recovery'), '80%');
      expect(rowValue(sections, (r) => r.en == 'Payability'), '90%');
      expect(rowValue(sections, (r) => r.en == 'Chemical costs'), '40,000.00');
      expect(rowValue(sections, (r) => r.en == 'Total costs'), '175,000.00');
      expect(rowValue(sections, (r) => r.en == 'Sulfide'), '12%');
      expect(rowValue(sections, (r) => r.en == 'Evidence reference'), 'MET-001');
      expect(rowValue(sections, (r) => r.en.startsWith('Profit =')), '341,873.60');
      expect(rowValue(sections, (r) => r.en == 'Maximum bid'), '1,041,873.60');
    });
    test('kabla ya matokeo halisi: hali ni "bado hayajarekodiwa"', () {
      final sections = AssessmentSummary.build(a);
      expect(sections.any((s) => s.en == 'Estimate vs actual outcome'), isFalse);
      expect(rowValue(sections, (r) => r.en == 'Status'), contains('Not recorded'));
    });
    test('baada ya matokeo halisi: purity, fine gold na tofauti vinaonekana', () {
      const outcome = ActualOutcome(productMassGrams: 8.4, purityFraction: 0.85, reference: 'REF-77');
      final cmp = ValuationEngine.compareActualForStored(a.values, outcome);
      final b = GoldAssessment(
        id: a.id, title: a.title, mode: a.mode, assessmentType: a.assessmentType,
        createdAt: a.createdAt, formulaVersion: a.formulaVersion,
        values: {...a.values, 'actualOutcome': outcome.toMap()},
        result: {...a.result, 'actualComparison': cmp.toMap()},
        notes: '',
      );
      final sections = AssessmentSummary.build(b);
      expect(sections.any((s) => s.en == 'Estimate vs actual outcome'), isTrue);
      expect(rowValue(sections, (r) => r.en == 'Purity'), '85%');
      expect(rowValue(sections, (r) => r.en.startsWith('Actual fine gold')), '7.1400 g');
      expect(rowValue(sections, (r) => r.en == 'Estimated fine gold'), '7.3600 g');
      expect(rowValue(sections, (r) => r.en.startsWith('Variance (actual')), contains('-0.2200 g'));
      expect(rowValue(sections, (r) => r.en == 'Profit variance'), '-42,352.20');
    });
    test('rekodi ya field haina grade wala bei', () {
      final f = GoldAssessment(
        id: 'f1', title: 'Field', mode: 'field', assessmentType: 'field_screening',
        createdAt: DateTime.utc(2026, 1, 1), formulaVersion: 'v',
        values: {'samplingPoints': 2}, result: {'valuationAvailable': false, 'recommendation': 'Get assay'},
        notes: '',
      );
      final sections = AssessmentSummary.build(f);
      expect(sections.any((s) => s.en.contains('Gold balance')), isFalse);
      expect(sections.any((s) => s.en.startsWith('Field screening')), isTrue);
    });
    test('PDF inatengenezwa kwa rekodi kamili na rekodi ya field', () async {
      final bytes = await ReportService.build(a);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      final f = GoldAssessment(
        id: 'f1', title: 'Field', mode: 'field', assessmentType: 'field_screening',
        createdAt: DateTime.utc(2026, 1, 1), formulaVersion: 'v',
        values: {'samplingPoints': 2}, result: {'valuationAvailable': false}, notes: '',
      );
      expect((await ReportService.build(f)).length, greaterThan(500));
    });
  });
}
