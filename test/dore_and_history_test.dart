import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:madini/domain/actual_history.dart';
import 'package:madini/domain/assessment_summary.dart';
import 'package:madini/domain/dore_models.dart';
import 'package:madini/domain/gold_assessment.dart';
import 'package:madini/domain/integrity_seal.dart';
import 'package:madini/domain/recovery_models.dart';
import 'package:madini/domain/valuation_models.dart';
import 'package:madini/services/orphan_sweep.dart';
import 'package:madini/services/report_service.dart';
import 'package:madini/services/valuation_engine.dart';

/// Loti ya doré (namba zimehakikiwa kwa Python Decimal):
/// 100 g, punguzo 2% -> 98 g; purity 90% (fire assay) -> fine 88.2 g;
/// payability 98% -> 86.436 g; bei 230,000 -> mapato 19,880,280;
/// makato 7% = 1,391,619.6; gharama 220,000; net 18,268,660.4;
/// bid (target 1,000,000) 17,268,660.4; faida (ununuzi 17,000,000) 1,268,660.4.
DoreInput dore({
  String method = DorePurityMethods.fireAssay,
  String ref = 'FA-001',
  double gross = 100,
  double loss = 0.02,
  double purity = 0.90,
  double caution = 0,
  double payability = 0.98,
  double price = 230000,
  double refining = 150000,
  double transport = 50000,
  double other = 20000,
  double royalty = 6,
  double inspection = 1,
  double otherStatutory = 0,
  double targetProfit = 1000000,
  double purchase = 17000000,
  double? scale,
  String title = 'Dore A',
  String sampleId = 'D-1',
  String targetMode = 'fixed',
  double margin = 0,
}) =>
    DoreInput(
      title: title,
      sampleId: sampleId,
      grossMassGrams: gross,
      weightLossFraction: loss,
      measuredPurityFraction: purity,
      purityMethod: method,
      purityReference: ref,
      purityCautionPoints: caution,
      payabilityFraction: payability,
      goldPricePerGram: price,
      refiningCosts: refining,
      transportCosts: transport,
      otherCosts: other,
      royaltyPercent: royalty,
      inspectionFeePercent: inspection,
      otherStatutoryPercent: otherStatutory,
      targetProfit: targetProfit,
      targetMode: targetMode,
      targetMarginPercent: margin,
      purchasePrice: purchase,
      scaleResolutionGrams: scale,
    );

Future<GoldAssessment> assessDore(DoreInput base,
    {double pts = 2, double pct = 5}) async {
  final set = ValuationEngine.doreScenarios(base, stressPurityPoints: pts, stressPricePercent: pct);
  final values = <String, dynamic>{
    ...base.toMap(),
    'goldPriceSource': 'Buyer quote',
    'goldPriceQuotedAt': '2026-11-17',
    'stressPurityPoints': pts,
    'stressPricePercent': pct,
  };
  final result = <String, dynamic>{
    ...set.expected.toMap(),
    'scenarios': set.toMap(),
    'warnings': ValuationEngine.doreAdvisories(base),
  };
  final sealed = await IntegritySeal.seal(values, result, ValuationEngine.formulaVersion);
  return GoldAssessment(
    id: 'd1',
    title: base.title,
    mode: 'dore',
    assessmentType: 'dore',
    createdAt: DateTime.utc(2026, 1, 2),
    formulaVersion: ValuationEngine.formulaVersion,
    values: values,
    result: sealed,
    notes: '',
  );
}

GoldAssessment roundTrip(GoldAssessment a) =>
    GoldAssessment.fromMap(jsonDecode(jsonEncode(a.toDbMap())) as Map<String, dynamic>);

String rowValue(List<SummarySection> sections, bool Function(SummaryRow) test) =>
    sections.expand((s) => s.rows).firstWhere(test).value;

ValuationInput oreInput() => const ValuationInput(
      title: 'Ore A',
      mode: 'laboratory',
      wetWeight: 1000,
      moistureFraction: 0.08,
      gradeGramsPerTonne: 10,
      recoveryFraction: 0.8,
      payabilityFraction: 0.9,
      processingCosts: 60000,
      transportCosts: 50000,
      otherCosts: 25000,
      chemicalCosts: 40000,
      goldPricePerGram: 230000,
      targetProfit: 200000,
      targetMarginPercent: 0,
      notes: '',
      sampleId: 'S-1',
      royaltyPercent: 6,
      inspectionFeePercent: 1,
      oreType: OreTypes.oxide,
      recoveryEvidence: RecoveryEvidenceTypes.metallurgicalTest,
      recoveryEvidenceRef: 'MET-001',
      purchasePrice: 900000,
    );

void main() {
  group('doré: formula ya kila hatua', () {
    final r = ValuationEngine.calculateDore(dore());
    test('uzito halisi = doré × (1 − punguzo)', () => expect(r.netMassGrams, closeTo(98, 1e-9)));
    test('purity iliyotumika = iliyopimwa (tahadhari 0)', () => expect(r.purityUsed, closeTo(0.90, 1e-12)));
    test('dhahabu safi = uzito halisi × purity (mara moja)', () {
      expect(r.fineGold, closeTo(88.2, 1e-9));
      expect(r.fineGold, isNot(closeTo(88.2 * 0.9, 1e-3)));
    });
    test('inayolipiwa = safi × payability', () => expect(r.payableGold, closeTo(86.436, 1e-9)));
    test('mapato', () => expect(r.revenue, closeTo(19880280, 1e-6)));
    test('makato, gharama, net, bid, faida', () {
      expect(r.statutoryDeductions, closeTo(1391619.6, 1e-6));
      expect(r.totalCosts, closeTo(220000, 1e-9));
      expect(r.netBeforePurchase, closeTo(18268660.4, 1e-6));
      expect(r.maximumBid, closeTo(17268660.4, 1e-6));
      expect(r.profit, closeTo(1268660.4, 1e-6));
      expect(r.isPositive, isTrue);
    });
    test('fire assay reference ni user-declared, si uthibitisho huru wa app', () {
      expect(r.purityVerified, isTrue);
      expect(r.toMap()['valuationGrade'], 'fire_assay_declared');
      expect(r.toMap()['purityIndependentlyVerified'], isFalse);
      expect(r.confidence, contains('has not authenticated'));
    });
    test('margin ya asilimia inatumika kama lengo', () {
      final p = ValuationEngine.calculateDore(dore(targetMode: 'percentage', margin: 10, targetProfit: 5));
      // lengo = 10% ya 19,880,280 = 1,988,028 ; bid = 18,268,660.4 - 1,988,028
      expect(p.maximumBid, closeTo(16280632.4, 1e-6));
    });
    test('bila ununuzi faida = net', () {
      final p = ValuationEngine.calculateDore(dore(purchase: 0));
      expect(p.profit, closeTo(p.netBeforePurchase, 1e-9));
    });
  });

  group('doré: njia ya purity na tahadhari', () {
    test('XRF: tahadhari 2 -> purity 88%, fine 86.24, bid 16,857,801.28', () {
      final r = ValuationEngine.calculateDore(dore(method: DorePurityMethods.xrf, ref: '', caution: 2));
      expect(r.purityUsed, closeTo(0.88, 1e-12));
      expect(r.fineGold, closeTo(86.24, 1e-9));
      expect(r.maximumBid, closeTo(16857801.28, 1e-6));
      expect(r.profit, closeTo(857801.28, 1e-6));
      expect(r.purityVerified, isFalse);
      expect(r.toMap()['valuationGrade'], 'indicative');
      expect(r.confidence, contains('INDICATIVE'));
    });
    test('macho: tahadhari 5 -> purity 85%, fine 83.3, bid 16,241,512.6', () {
      final r = ValuationEngine.calculateDore(dore(method: DorePurityMethods.visual, ref: '', caution: 5));
      expect(r.purityUsed, closeTo(0.85, 1e-12));
      expect(r.fineGold, closeTo(83.3, 1e-9));
      expect(r.maximumBid, closeTo(16241512.6, 1e-6));
      expect(r.profit, closeTo(241512.6, 1e-6));
    });
    test('njia dhaifu hazitoi bid ya juu kuliko fire assay kwa purity ile ile', () {
      final fire = ValuationEngine.calculateDore(dore());
      final xrf = ValuationEngine.calculateDore(dore(method: DorePurityMethods.xrf, ref: '', caution: 2));
      final vis = ValuationEngine.calculateDore(dore(method: DorePurityMethods.visual, ref: '', caution: 5));
      expect(xrf.maximumBid, lessThan(fire.maximumBid));
      expect(vis.maximumBid, lessThan(xrf.maximumBid));
    });
    test('viwango vya tahadhari vya awali', () {
      expect(DorePurityMethods.defaultCautionPoints(DorePurityMethods.fireAssay), 0);
      expect(DorePurityMethods.defaultCautionPoints(DorePurityMethods.xrf), 2);
      expect(DorePurityMethods.defaultCautionPoints(DorePurityMethods.visual), 5);
    });
    test('maonyo ya XRF, macho, tahadhari 0, uzito na mizani', () {
      final x = ValuationEngine.doreAdvisories(dore(method: DorePurityMethods.xrf, ref: '', caution: 0, loss: 0, scale: 1)).join(' | ');
      expect(x, contains('surface'));
      expect(x, contains('INDICATIVE'));
      expect(x, contains('caution is 0'));
      expect(x, contains('No weight deduction'));
      expect(x, contains('Scale resolution is 1.00%'));
      final v = ValuationEngine.doreAdvisories(dore(method: DorePurityMethods.visual, ref: '', caution: 5)).join(' | ');
      expect(v, contains('Visual purity'));
      final f = ValuationEngine.doreAdvisories(dore(purchase: 0)).join(' | ');
      expect(f, isNot(contains('INDICATIVE')));
      expect(f, contains('Purchase price not entered'));
    });
  });

  group('karat', () {
    test('22k = 22/24, 24k = 1, 18k = 0.75', () {
      expect(PurityConverter.karatToFraction(22), closeTo(0.9166666666666666, 1e-12));
      expect(PurityConverter.karatToFraction(24), 1.0);
      expect(PurityConverter.karatToFraction(18), 0.75);
    });
    test('karat batili inakataliwa', () {
      expect(() => PurityConverter.karatToFraction(0), throwsArgumentError);
      expect(() => PurityConverter.karatToFraction(25), throwsArgumentError);
      expect(() => PurityConverter.karatToFraction(double.nan), throwsArgumentError);
    });
  });

  group('doré: data zisizokubalika', () {
    final bad = <String, DoreInput Function()>{
      'fire assay bila rejea': () => dore(ref: ' '),
      'uzito 0': () => dore(gross: 0),
      'uzito NaN': () => dore(gross: double.nan),
      'punguzo 100%': () => dore(loss: 1),
      'punguzo hasi': () => dore(loss: -0.01),
      'purity 0': () => dore(purity: 0),
      'purity > 1': () => dore(purity: 1.2),
      'tahadhari > 50': () => dore(method: DorePurityMethods.visual, ref: '', caution: 60),
      'purity baada ya tahadhari <= 0': () => dore(method: DorePurityMethods.visual, ref: '', purity: 0.03, caution: 5),
      'payability > 1': () => dore(payability: 1.1),
      'bei 0': () => dore(price: 0),
      'gharama hasi': () => dore(refining: -1),
      'ununuzi hasi': () => dore(purchase: -1),
      'makato > 100': () => dore(royalty: 60, inspection: 50),
      'njia isiyojulikana': () => dore(method: 'guess'),
      'target mode batili': () => dore(targetMode: 'magic'),
      'mizani hasi': () => dore(scale: -1),
      'resolution kubwa kuliko uzito': () => dore(gross: 1, scale: 1),
    };
    bad.forEach((name, build) {
      test(name, () => expect(() => ValuationEngine.calculateDore(build()), throwsArgumentError));
    });
  });

  group('doré: scenarios', () {
    test('purity ± pointi 2 na bei ± 5%', () {
      final set = ValuationEngine.doreScenarios(dore(), stressPurityPoints: 2, stressPricePercent: 5);
      expect(set.expected.maximumBid, closeTo(17268660.4, 1e-3));
      expect(set.conservative.purityUsed, closeTo(0.88, 1e-12));
      expect(set.conservative.priceUsed, closeTo(218500, 1e-6));
      expect(set.conservative.maximumBid, closeTo(15953911.216, 1e-2));
      expect(set.optimistic.purityUsed, closeTo(0.92, 1e-12));
      expect(set.optimistic.priceUsed, closeTo(241500, 1e-6));
      expect(set.optimistic.maximumBid, closeTo(18624495.496, 1e-2));
    });
    test('purity haizidi 100% wala kushuka chini ya 0%', () {
      final hi = ValuationEngine.doreScenarios(dore(purity: 0.99), stressPurityPoints: 5);
      expect(hi.optimistic.purityUsed, 1.0);
      final lo = ValuationEngine.doreScenarios(
          dore(method: DorePurityMethods.visual, ref: '', purity: 0.06, caution: 5), stressPurityPoints: 5);
      expect(lo.conservative.purityUsed, 0.0);
    });
    test('mshtuko batili unakataliwa', () {
      expect(() => ValuationEngine.doreScenarios(dore(), stressPurityPoints: 25), throwsArgumentError);
      expect(() => ValuationEngine.doreScenarios(dore(), stressPricePercent: 95), throwsArgumentError);
    });
  });

  group('doré: makadirio dhidi ya matokeo halisi ya refinery', () {
    final input = dore();
    final estimate = ValuationEngine.calculateDore(input);

    test('namba zote', () {
      final c = ValuationEngine.compareActualDore(
          input, estimate, const ActualOutcome(productMassGrams: 97.5, purityFraction: 0.9));
      expect(c.actualFineGold, closeTo(87.75, 1e-12));
      expect(c.estimatedFineGold, closeTo(88.2, 1e-9));
      expect(c.fineGoldVarianceGrams, closeTo(-0.45, 1e-9));
      expect(c.fineGoldVariancePercent, closeTo(-0.5102040816, 1e-8));
      expect(c.purityVariancePoints, closeTo(0, 1e-9));
      expect(c.actualPayableGold, closeTo(85.995, 1e-9));
      expect(c.actualRevenue, closeTo(19778850, 1e-6));
      expect(c.actualStatutoryDeductions, closeTo(1384519.5, 1e-6));
      expect(c.actualTotalCosts, closeTo(220000, 1e-9));
      expect(c.actualProfit, closeTo(1174330.5, 1e-6));
      expect(c.revenueVariance, closeTo(-101430, 1e-6));
      expect(c.profitVariance, closeTo(-94329.9, 1e-6));
      expect(c.warnings, isEmpty);
    });
    test('bei na gharama halisi (refining) zinatumika zikiwekwa', () {
      final c = ValuationEngine.compareActualDore(
          input,
          estimate,
          const ActualOutcome(
              productMassGrams: 97.5, purityFraction: 0.9, salePricePerGram: 240000, processingCosts: 180000));
      expect(c.actualRevenue, closeTo(20638800, 1e-6));
      expect(c.actualStatutoryDeductions, closeTo(1444716, 1e-6));
      expect(c.actualTotalCosts, closeTo(250000, 1e-9));
      expect(c.actualProfit, closeTo(1944084, 1e-6));
    });
    test('purity ya refinery ya chini sana inaonywa', () {
      final c = ValuationEngine.compareActualDore(
          input, estimate, const ActualOutcome(productMassGrams: 98, purityFraction: 0.80));
      final text = c.warnings.join(' | ');
      expect(c.purityVariancePoints, closeTo(-10, 1e-9));
      expect(text, contains('more than 3 points below'));
      expect(text, contains('more than 5%'));
    });
    test('uzito wa refinery unaotofautiana > 2% unaonywa', () {
      final c = ValuationEngine.compareActualDore(
          input, estimate, const ActualOutcome(productMassGrams: 90, purityFraction: 0.9));
      expect(c.warnings.join(' | '), contains('Refinery mass differs'));
    });
    test('pembejeo batili zinakataliwa', () {
      for (final o in const [
        ActualOutcome(productMassGrams: 0, purityFraction: 0.9),
        ActualOutcome(productMassGrams: 90, purityFraction: 0),
        ActualOutcome(productMassGrams: 90, purityFraction: 1.2),
        ActualOutcome(productMassGrams: 90, purityFraction: 0.9, salePricePerGram: 0),
        ActualOutcome(productMassGrams: 90, purityFraction: 0.9, processingCosts: -1),
      ]) {
        expect(() => ValuationEngine.compareActualDore(input, estimate, o), throwsArgumentError);
      }
    });
    test('compareActualDoreForStored inatoa matokeo yale yale', () async {
      final a = await assessDore(input);
      final c = ValuationEngine.compareActualDoreForStored(
          a.values, const ActualOutcome(productMassGrams: 97.5, purityFraction: 0.9));
      expect(c.actualFineGold, closeTo(87.75, 1e-12));
    });
  });

  group('doré: kuhifadhi, kufungua, muhuri na kurudia hesabu', () {
    test('values/result vinarudi kamili na muhuri ni halali', () async {
      final saved = await assessDore(dore());
      final reopened = roundTrip(saved);
      expect(reopened.mode, 'dore');
      expect(reopened.values, equals(jsonDecode(jsonEncode(saved.values))));
      expect(reopened.values['purityMethod'], DorePurityMethods.fireAssay);
      expect(await IntegritySeal.verify(reopened.values, reopened.result, reopened.formulaVersion), SealStatus.valid);
    });
    test('hesabu inarudiwa na inalingana', () async {
      final reopened = roundTrip(await assessDore(dore(method: DorePurityMethods.xrf, ref: '', caution: 2)));
      final check = ValuationEngine.recheckStoredDore(
          values: reopened.values, result: reopened.result, storedFormulaVersion: reopened.formulaVersion);
      expect(check.matches, isTrue, reason: check.differences.join('; '));
      expect(check.formulaChanged, isFalse);
    });
    test('scenario ya doré iliyokosekana inagunduliwa', () async {
      final a = await assessDore(dore());
      final result = Map<String, dynamic>.from(a.result);
      final scenarios = Map<String, dynamic>.from(result['scenarios'] as Map)..remove('conservative');
      result['scenarios'] = scenarios;
      final check = ValuationEngine.recheckStoredDore(values: a.values, result: result);
      expect(check.matches, isFalse);
      expect(check.differences.join(' '), contains('conservative'));
    });
    test('mabadiliko ya rekodi yanagunduliwa na muhuri na kurudia hesabu', () async {
      final a = roundTrip(await assessDore(dore()));
      final values = Map<String, dynamic>.from(a.values)..['grossMassGrams'] = 120.0;
      expect(await IntegritySeal.verify(values, a.result, a.formulaVersion), SealStatus.broken);
      final check = ValuationEngine.recheckStoredDore(values: values, result: a.result);
      expect(check.matches, isFalse);
    });
    test('DoreInput.fromMap(toMap()) inatoa matokeo yale yale', () {
      final input = dore(method: DorePurityMethods.visual, ref: '', caution: 5, scale: 0.5);
      final again = DoreInput.fromMap(input.toMap());
      expect(ValuationEngine.calculateDore(again).toMap(), equals(ValuationEngine.calculateDore(input).toMap()));
    });
  });

  group('matokeo halisi: matoleo (append-only)', () {
    Map<String, dynamic> outcome(String ref, double mass) =>
        {'productMassGrams': mass, 'purityFraction': 0.9, 'reference': ref, 'recordedAt': '2026-11-18T10:00:00'};
    Map<String, dynamic> comparison(double fine) => {'actualFineGold': fine};

    test('rekodi ya kwanza: toleo 1, hakuna sababu inayohitajika, historia tupu', () {
      final r = ActualOutcomeVersioning.apply(
        values: {'a': 1}, result: {'b': 2},
        newOutcome: outcome('R1', 97.5), newComparison: comparison(87.75), nowIso: 't1',
      );
      expect(r.version, 1);
      expect((r.values['actualOutcome'] as Map)['version'], 1);
      expect(ActualOutcomeVersioning.history(r.values), isEmpty);
      expect(r.values['a'], 1);
      expect(r.result['b'], 2);
    });

    test('marekebisho bila sababu yanakataliwa', () {
      final first = ActualOutcomeVersioning.apply(
        values: {}, result: {}, newOutcome: outcome('R1', 97.5), newComparison: comparison(87.75), nowIso: 't1');
      for (final reason in [null, '', '   ']) {
        expect(
            () => ActualOutcomeVersioning.apply(
                values: first.values, result: first.result,
                newOutcome: outcome('R2', 96), newComparison: comparison(86.4), nowIso: 't2',
                correctionReason: reason),
            throwsArgumentError);
      }
    });

    test('marekebisho yanahifadhi toleo la zamani na sababu; historia haifutwi', () {
      final v1 = ActualOutcomeVersioning.apply(
        values: {}, result: {}, newOutcome: outcome('R1', 97.5), newComparison: comparison(87.75), nowIso: 't1');
      final v2 = ActualOutcomeVersioning.apply(
        values: v1.values, result: v1.result,
        newOutcome: outcome('R2', 96), newComparison: comparison(86.4), nowIso: 't2',
        correctionReason: 'Mizani ilikosewa', needsReview: true);
      final v3 = ActualOutcomeVersioning.apply(
        values: v2.values, result: v2.result,
        newOutcome: outcome('R3', 95), newComparison: comparison(85.5), nowIso: 't3',
        correctionReason: 'Risiti mpya');
      expect(v2.version, 2);
      expect(v3.version, 3);
      final hist = ActualOutcomeVersioning.history(v3.values);
      expect(hist.length, 2);
      expect(hist.map((e) => e['version']).toList(), [1, 2]);
      expect((hist[0]['outcome'] as Map)['reference'], 'R1');
      expect((hist[0]['comparison'] as Map)['actualFineGold'], 87.75);
      expect(hist[0]['correctionReason'], 'Mizani ilikosewa');
      expect(hist[0]['supersededAt'], 't2');
      expect((hist[1]['outcome'] as Map)['reference'], 'R2');
      expect(hist[1]['correctionReason'], 'Risiti mpya');
      final current = v3.values['actualOutcome'] as Map;
      expect(current['reference'], 'R3');
      expect(current['version'], 3);
      expect(current['correctionReason'], 'Risiti mpya');
      expect(current['needsReview'], isFalse);
      expect((v2.values['actualOutcome'] as Map)['needsReview'], isTrue);
      // Historia ya v2 haikubadilishwa na v3 (append-only):
      expect(ActualOutcomeVersioning.history(v2.values).length, 1);
    });

    test('muhuri unabaki halali baada ya matoleo; historia inaonekana kwenye muhtasari', () async {
      final a = await assessDore(dore());
      final v1 = ActualOutcomeVersioning.apply(
        values: a.values, result: a.result,
        newOutcome: outcome('R1', 97.5), newComparison: comparison(87.75), nowIso: 't1');
      final v2 = ActualOutcomeVersioning.apply(
        values: v1.values, result: v1.result,
        newOutcome: outcome('R2', 96), newComparison: comparison(86.4), nowIso: 't2',
        correctionReason: 'Kosa la uzito');
      expect(await IntegritySeal.verify(v2.values, v2.result, a.formulaVersion), SealStatus.valid);
      final b = GoldAssessment(
        id: a.id, title: a.title, mode: a.mode, assessmentType: a.assessmentType,
        createdAt: a.createdAt, formulaVersion: a.formulaVersion,
        values: v2.values, result: v2.result, notes: '',
      );
      final sections = AssessmentSummary.build(b);
      expect(sections.any((s) => s.en == 'Actual outcome version history'), isTrue);
      expect(rowValue(sections, (r) => r.en.startsWith('Version 1')), contains('Kosa la uzito'));
    });

    test('maandishi ya historia yanahifadhiwa kupitia JSON ya database', () async {
      final a = await assessDore(dore());
      final v1 = ActualOutcomeVersioning.apply(
        values: a.values, result: a.result,
        newOutcome: outcome('R1', 97.5), newComparison: comparison(87.75), nowIso: 't1');
      final v2 = ActualOutcomeVersioning.apply(
        values: v1.values, result: v1.result,
        newOutcome: outcome('R2', 96), newComparison: comparison(86.4), nowIso: 't2',
        correctionReason: 'Sababu');
      final stored = roundTrip(GoldAssessment(
        id: a.id, title: a.title, mode: a.mode, assessmentType: a.assessmentType,
        createdAt: a.createdAt, formulaVersion: a.formulaVersion,
        values: v2.values, result: v2.result, notes: '',
      ));
      expect(ActualOutcomeVersioning.history(stored.values).length, 1);
      expect((stored.values['actualOutcome'] as Map)['version'], 2);
    });

    test('matoleo mapya yanatumia namba kubwa kuliko historia iliyopo', () {
      final legacyValues = {
        'actualOutcome': {'productMassGrams': 10.0, 'purityFraction': 0.9},
        'actualOutcomeHistory': [
          {'version': 1, 'outcome': {'reference': 'old-1'}},
          {'version': 4, 'outcome': {'reference': 'old-4'}},
        ],
      };
      final next = ActualOutcomeVersioning.apply(
        values: legacyValues,
        result: {},
        newOutcome: outcome('R-next', 95),
        newComparison: comparison(85.5),
        nowIso: 't-next',
        correctionReason: 'Marekebisho ya kumbukumbu',
      );
      expect(next.version, 6);
      final history = ActualOutcomeVersioning.history(next.values);
      expect(history.map((e) => e['version']).toList(), [1, 4, 5]);
    });

    test('toleo la sasa lisilo juu ya historia linakataliwa', () {
      expect(
        () => ActualOutcomeVersioning.apply(
          values: {
            'actualOutcome': {'version': 2},
            'actualOutcomeHistory': [
              {'version': 1},
              {'version': 3},
            ],
          },
          result: {},
          newOutcome: outcome('R-next', 95),
          newComparison: comparison(85.5),
          nowIso: 't-next',
          correctionReason: 'Correction',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('historia yenye version inayojirudia inakataliwa', () {
      expect(
        () => ActualOutcomeVersioning.history({
          'actualOutcomeHistory': [
            {'version': 1},
            {'version': 1},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

  });

  group('kifuta cha vyeti yatima (OrphanSweep)', () {
    final now = DateTime.utc(2026, 11, 19, 12);
    final old = now.subtract(const Duration(days: 3));
    final young = now.subtract(const Duration(hours: 2));

    test('jina la faili ndilo linalolinganishwa, si njia nzima', () {
      final plan = OrphanSweep.plan(
        files: {'/data/user/0/app/files/certificates/abc.mcert': old},
        knownPaths: ['/data/data/app/files/certificates/abc.mcert'], // njia tofauti, jina sawa
        now: now,
      );
      expect(plan, isEmpty);
    });
    test('njia za Windows na Unix zote zinashughulikiwa', () {
      expect(OrphanSweep.baseName(r'C:\x\y\z.mcert'), 'z.mcert');
      expect(OrphanSweep.baseName('/x/y/z.mcert'), 'z.mcert');
      expect(OrphanSweep.baseName('z.mcert'), 'z.mcert');
    });
    test('yatima wa zamani wanafutwa; wachanga na wasio .mcert hawafutwi', () {
      final plan = OrphanSweep.plan(
        files: {
          '/c/known.mcert': old,
          '/c/orphan.mcert': old,
          '/c/young.mcert': young,
          '/c/notes.txt': old,
        },
        knownPaths: ['/elsewhere/known.mcert'],
        now: now,
      );
      expect(plan, ['/c/orphan.mcert']);
    });
    test('kinga: zaidi ya nusu kuonekana yatima (mafaili 5+) = hakuna kinachofutwa', () {
      final files = {for (var i = 0; i < 6; i++) '/c/f$i.mcert': old};
      expect(OrphanSweep.plan(files: files, knownPaths: ['/c/f0.mcert', '/c/f1.mcert'], now: now), isEmpty);
    });
    test('chini ya nusu yatima (mafaili 6) = wanafutwa', () {
      final files = {for (var i = 0; i < 6; i++) '/c/f$i.mcert': old};
      final known = ['/c/f0.mcert', '/c/f1.mcert', '/c/f2.mcert', '/c/f3.mcert'];
      expect(OrphanSweep.plan(files: files, knownPaths: known, now: now).length, 2);
    });
    test('mafaili machache (chini ya 5) yote yatima wanafutwa', () {
      final files = {for (var i = 0; i < 3; i++) '/c/f$i.mcert': old};
      expect(OrphanSweep.plan(files: files, knownPaths: const [], now: now).length, 3);
    });
    test('database tupu na mafaili mengi: hakuna kinachofutwa (kinga)', () {
      final files = {for (var i = 0; i < 8; i++) '/c/f$i.mcert': old};
      expect(OrphanSweep.plan(files: files, knownPaths: const [], now: now), isEmpty);
    });
  });

  group('ripoti na historia za doré (muhtasari mmoja)', () {
    test('historia inaonyesha uzito, purity, njia, gharama, faida na bid', () async {
      final a = await assessDore(dore());
      final s = AssessmentSummary.build(a);
      expect(rowValue(s, (r) => r.en == 'Dore mass (g)'), '100.0000');
      expect(rowValue(s, (r) => r.en.startsWith('Net mass (g)')), '98.0000');
      expect(rowValue(s, (r) => r.en == 'Measured purity'), '90%');
      expect(rowValue(s, (r) => r.en.startsWith('Purity used')), '90%');
      expect(rowValue(s, (r) => r.en == 'Purity reference'), 'FA-001');
      expect(rowValue(s, (r) => r.en == 'Purity method'), contains('Fire assay'));
      expect(rowValue(s, (r) => r.en.startsWith('Fine gold =')), '88.2000 g');
      expect(rowValue(s, (r) => r.en.startsWith('Payable fine gold')), '86.4360 g');
      expect(rowValue(s, (r) => r.en == 'Total costs'), '220,000.00');
      expect(rowValue(s, (r) => r.en.startsWith('Profit =')), '1,268,660.40');
      expect(rowValue(s, (r) => r.en == 'Maximum bid'), '17,268,660.40');
      expect(rowValue(s, (r) => r.en == 'Valuation grade'), contains('has not authenticated the report'));
    });
    test('njia dhaifu inaonekana kama KUKADIRIA TU', () async {
      final a = await assessDore(dore(method: DorePurityMethods.visual, ref: '', caution: 5));
      final s = AssessmentSummary.build(a);
      expect(rowValue(s, (r) => r.en == 'Valuation grade'), contains('INDICATIVE ONLY'));
      expect(rowValue(s, (r) => r.en.startsWith('Purity used')), '85%');
    });
    test('baada ya matokeo halisi: purity, fine gold na tofauti vinaonekana', () async {
      final a = await assessDore(dore());
      const o = ActualOutcome(productMassGrams: 97.5, purityFraction: 0.9, reference: 'REF-1');
      final c = ValuationEngine.compareActualDoreForStored(a.values, o);
      final v = ActualOutcomeVersioning.apply(
          values: a.values, result: a.result,
          newOutcome: o.toMap(), newComparison: c.toMap(), nowIso: 't1');
      final b = GoldAssessment(
        id: a.id, title: a.title, mode: a.mode, assessmentType: a.assessmentType,
        createdAt: a.createdAt, formulaVersion: a.formulaVersion, values: v.values, result: v.result, notes: '');
      final s = AssessmentSummary.build(b);
      expect(s.any((x) => x.en == 'Estimate vs actual refinery outcome'), isTrue);
      expect(rowValue(s, (r) => r.en == 'Refinery purity'), '90%');
      expect(rowValue(s, (r) => r.en.startsWith('Actual fine gold')), '87.7500 g');
      expect(rowValue(s, (r) => r.en == 'Estimated fine gold'), '88.2000 g');
      expect(rowValue(s, (r) => r.en == 'Profit variance'), '-94,329.90');
      expect(rowValue(s, (r) => r.en == 'Outcome version'), '1');
    });
    test('PDF ya doré na ya ore yenye matoleo inatengenezwa', () async {
      final a = await assessDore(dore());
      final bytes = await ReportService.build(a);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      final ore = ValuationEngine.scenarios(oreInput(), lowestGrade: 10, highestGrade: 10);
      final oreA = GoldAssessment(
        id: 'o1', title: 'Ore A', mode: 'laboratory', assessmentType: 'laboratory',
        createdAt: DateTime.utc(2026, 1, 2), formulaVersion: ValuationEngine.formulaVersion,
        values: {...oreInput().toMap(), 'assayGradesGpt': [10.0]},
        result: {...ore.expected.toMap(), 'scenarios': ore.toMap()}, notes: '');
      expect((await ReportService.build(oreA)).length, greaterThan(1000));
    });
  });
}
