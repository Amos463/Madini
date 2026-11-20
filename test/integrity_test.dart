import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:madini/domain/assessment_summary.dart';
import 'package:madini/domain/gold_assessment.dart';
import 'package:madini/domain/integrity_seal.dart';
import 'package:madini/domain/recovery_models.dart';
import 'package:madini/domain/valuation_models.dart';
import 'package:madini/services/report_service.dart';
import 'package:madini/services/valuation_engine.dart';

ValuationInput lot17({double wet = 1000, double price = 230000}) => ValuationInput(
      title: 'Lot Z',
      mode: 'laboratory',
      wetWeight: wet,
      moistureFraction: 0.08,
      gradeGramsPerTonne: 10,
      recoveryFraction: 0.8,
      payabilityFraction: 0.9,
      processingCosts: 60000,
      transportCosts: 50000,
      otherCosts: 25000,
      chemicalCosts: 40000,
      goldPricePerGram: price,
      targetProfit: 200000,
      targetMarginPercent: 0,
      notes: '',
      sampleId: 'Z-1',
      royaltyPercent: 6,
      inspectionFeePercent: 1,
      oreType: OreTypes.oxide,
      recoveryEvidence: RecoveryEvidenceTypes.metallurgicalTest,
      recoveryEvidenceRef: 'MET-9',
      purchasePrice: 900000,
    );

Future<GoldAssessment> sealed(ValuationInput base, {String notes = ''}) async {
  final set = ValuationEngine.scenarios(base, lowestGrade: 10, highestGrade: 10);
  final values = {...base.toMap(), 'assayGradesGpt': [10.0], 'gradeBasis': 'mean'};
  final result = {...set.expected.toMap(), 'scenarios': set.toMap(), 'warnings': <String>[]};
  final withSeal = await IntegritySeal.seal(values, result, ValuationEngine.formulaVersion);
  return GoldAssessment(
    id: 'z1',
    title: base.title,
    mode: 'laboratory',
    assessmentType: 'laboratory',
    createdAt: DateTime.utc(2026, 11, 18),
    formulaVersion: ValuationEngine.formulaVersion,
    values: values,
    result: withSeal,
    notes: notes,
  );
}

GoldAssessment roundTrip(GoldAssessment a) =>
    GoldAssessment.fromMap(jsonDecode(jsonEncode(a.toDbMap())) as Map<String, dynamic>);

void main() {
  group('muhuri wa uadilifu', () {
    test('rekodi mpya ina muhuri sahihi, hata baada ya kuhifadhi na kufungua', () async {
      final a = await sealed(lot17());
      expect(await IntegritySeal.verify(a.values, a.result, a.formulaVersion), SealStatus.valid);
      final r = roundTrip(a);
      expect(await IntegritySeal.verify(r.values, r.result, r.formulaVersion), SealStatus.valid);
    });

    test('mabadiliko yoyote kwenye values au result yanagunduliwa', () async {
      final a = await sealed(lot17());
      final v = Map<String, dynamic>.from(a.values)..['processingCosts'] = 1.0;
      expect(await IntegritySeal.verify(v, a.result, a.formulaVersion), SealStatus.broken);
      final r = Map<String, dynamic>.from(a.result)..['maximumBid'] = 1.0;
      expect(await IntegritySeal.verify(a.values, r, a.formulaVersion), SealStatus.broken);
      final w = Map<String, dynamic>.from(a.result)..['warnings'] = ['mpya'];
      expect(await IntegritySeal.verify(a.values, w, a.formulaVersion), SealStatus.broken);
      expect(await IntegritySeal.verify(a.values, a.result, 'MADINI v0-nyingine'), SealStatus.broken);
    });

    test('kuongeza matokeo halisi hakuvunji muhuri (yametengwa kwa makusudi)', () async {
      final a = await sealed(lot17());
      const outcome = ActualOutcome(productMassGrams: 8.4, purityFraction: 0.85, reference: 'R1');
      final cmp = ValuationEngine.compareActualForStored(a.values, outcome);
      final values = {...a.values, 'actualOutcome': outcome.toMap()};
      final result = {...a.result, 'actualComparison': cmp.toMap()};
      expect(await IntegritySeal.verify(values, result, a.formulaVersion), SealStatus.valid);
    });

    test('rekodi bila muhuri ni "missing"; muhuri ulioharibika hauangushi app', () async {
      final a = await sealed(lot17());
      final noSeal = Map<String, dynamic>.from(a.result)..remove('integritySeal');
      expect(await IntegritySeal.verify(a.values, noSeal, a.formulaVersion), SealStatus.missing);
      final junk = {...noSeal, 'integritySeal': 'takataka'};
      expect(await IntegritySeal.verify(a.values, junk, a.formulaVersion), SealStatus.missing);
      final bad = GoldAssessment(
        id: a.id, title: a.title, mode: a.mode, assessmentType: a.assessmentType,
        createdAt: a.createdAt, formulaVersion: a.formulaVersion, values: a.values,
        result: {...noSeal, 'integritySeal': {'sha256': 'ab'}}, notes: '',
      );
      final sections = AssessmentSummary.build(bad); // haipaswi kutupa
      expect(sections.expand((s) => s.rows).any((r) => r.en == 'Integrity seal'), isTrue);
    });

    test('mpangilio wa funguo hauathiri muhuri', () async {
      final a = await sealed(lot17());
      final reordered = Map<String, dynamic>.fromEntries(a.values.entries.toList().reversed);
      expect(await IntegritySeal.verify(reordered, a.result, a.formulaVersion), SealStatus.valid);
    });
  });

  group('formula versioning na kurudia hesabu', () {
    test('toleo lile lile: hakuna formulaChanged', () async {
      final a = await sealed(lot17());
      final c = ValuationEngine.recheckStored(
          values: a.values, result: a.result, storedFormulaVersion: a.formulaVersion);
      expect(c.matches, isTrue, reason: c.differences.join('; '));
      expect(c.formulaChanged, isFalse);
    });

    test('toleo la zamani linaonyeshwa kama formulaChanged, si kama udanganyifu', () async {
      final a = await sealed(lot17());
      final c = ValuationEngine.recheckStored(
          values: a.values, result: a.result, storedFormulaVersion: 'MADINI v1.3-decimal');
      expect(c.formulaChanged, isTrue);
      expect(c.storedFormulaVersion, 'MADINI v1.3-decimal');
    });

    test('ukaguzi mpana: dryWeight, gradeUsed na netBeforePurchase pia zinagunduliwa', () async {
      final a = roundTrip(await sealed(lot17()));
      for (final key in ['dryWeight', 'netBeforePurchase', 'gradeUsed', 'priceUsed']) {
        final scen = Map<String, dynamic>.from(a.result['scenarios'] as Map);
        final exp = Map<String, dynamic>.from(scen['expected'] as Map)..[key] = 123456.0;
        scen['expected'] = exp;
        final c = ValuationEngine.recheckStored(
            values: a.values, result: {...a.result, 'scenarios': scen});
        expect(c.matches, isFalse, reason: '$key mabadiliko hayakugunduliwa');
        expect(c.differences.join(' '), contains(key));
      }
    });
  });

  group('ripoti za PDF: Kiswahili, namba kubwa na kurasa nyingi', () {
    test('namba kubwa sana na maandishi marefu yanatengeneza PDF halali', () async {
      final a = await sealed(lot17(wet: 5000000, price: 987654321.5),
          notes: List.generate(400, (i) => 'Maelezo ya mstari $i: dhahabu, mchanga, mgodi').join('\n'));
      final bytes = await ReportService.build(a);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('herufi zisizo za Latin-1 haziangushi ripoti', () async {
      final base = lot17();
      final a = await sealed(base);
      final tricky = GoldAssessment(
        id: a.id, title: 'Loti ya Geita — “mfano” ≥ 5 • ✓ 金', mode: a.mode,
        assessmentType: a.assessmentType, createdAt: a.createdAt, formulaVersion: a.formulaVersion,
        values: {...a.values, 'sellerName': 'Mwanahawa Ōmari ✓'}, result: a.result, notes: '',
      );
      expect((await ReportService.build(tricky)).length, greaterThan(1000));
    });
  });
}
