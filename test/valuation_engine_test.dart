import 'package:flutter_test/flutter_test.dart';

import 'package:madini/core/format.dart';
import 'package:madini/domain/assay_analysis.dart';
import 'package:madini/domain/gold_assessment.dart';
import 'package:madini/domain/valuation_models.dart';
import 'package:madini/services/report_service.dart';
import 'package:madini/services/secure_backup.dart';
import 'package:madini/services/valuation_engine.dart';

ValuationInput _input({
  double wet = 1000,
  double moisture = 0,
  double grade = 10,
  double recovery = 1,
  double payability = 1,
  double processing = 100,
  double transport = 50,
  double other = 25,
  double price = 100,
  double targetProfit = 200,
  double margin = 0,
  String targetMode = 'fixed',
  String mode = 'laboratory',
  double royalty = 0,
  double inspection = 0,
  double otherStatutory = 0,
}) =>
    ValuationInput(
      title: 'Lot',
      mode: mode,
      wetWeight: wet,
      moistureFraction: moisture,
      gradeGramsPerTonne: grade,
      recoveryFraction: recovery,
      payabilityFraction: payability,
      processingCosts: processing,
      transportCosts: transport,
      otherCosts: other,
      goldPricePerGram: price,
      targetProfit: targetProfit,
      targetMarginPercent: margin,
      targetMode: targetMode,
      notes: '',
      sampleId: 'S1',
      royaltyPercent: royalty,
      inspectionFeePercent: inspection,
      otherStatutoryPercent: otherStatutory,
    );

void main() {
  test('dry weight formula is applied correctly', () {
    expect(ValuationEngine.dryWeight(1000, 0.12), closeTo(880, 0.0001));
    expect(ValuationEngine.dryTonnes(1000, 0.12), closeTo(0.88, 0.0000001));
  });

  test('realistic Tanzanian lot with royalty and inspection fee', () {
    // 1 t wet, 8% moisture -> 0.92 t dry; 10 g/t -> 9.2 g; 80% recovery -> 7.36 g;
    // 90% payability -> 6.624 g; at 230,000 TZS/g -> revenue 1,523,520.
    final r = ValuationEngine.calculate(_input(
      moisture: 0.08, grade: 10, recovery: 0.8, payability: 0.9,
      price: 230000, processing: 100000, transport: 50000, other: 25000,
      targetProfit: 200000, royalty: 6, inspection: 1,
    ));
    expect(r.dryWeight, closeTo(920, 1e-9));
    expect(r.containedGold, closeTo(9.2, 1e-9));
    expect(r.payableGold, closeTo(6.624, 1e-9));
    expect(r.revenue, closeTo(1523520, 1e-6));
    expect(r.statutoryDeductions, closeTo(106646.4, 1e-6)); // 7% of revenue
    expect(r.maximumBid, closeTo(1041873.6, 1e-6));
    expect(r.isPositive, isTrue);
  });

  test('without statutory deductions the bid is higher by exactly that amount', () {
    final r = ValuationEngine.calculate(_input(
      moisture: 0.08, grade: 10, recovery: 0.8, payability: 0.9,
      price: 230000, processing: 100000, transport: 50000, other: 25000,
      targetProfit: 200000,
    ));
    expect(r.maximumBid, closeTo(1148520, 1e-6));
  });

  test('fixed profit target is applied independently from percentage margin', () {
    final r = ValuationEngine.calculate(_input(targetProfit: 200, margin: 80));
    expect(r.maximumBid, closeTo(625, 1e-9)); // 1000 - 175 - 200
  });

  test('percentage margin target is selected explicitly', () {
    final r = ValuationEngine.calculate(
        _input(targetProfit: 900, margin: 20, targetMode: 'percentage'));
    expect(r.maximumBid, closeTo(625, 1e-9)); // 1000 - 175 - 200
  });

  test('tiny values do not break Decimal parsing (no scientific notation)', () {
    final r = ValuationEngine.calculate(_input(grade: 0.0000001));
    expect(r.containedGold.isFinite, isTrue);
  });

  test('decimal precision is preserved until output', () {
    final r = ValuationEngine.calculate(_input(
      wet: 1234.567, moisture: 0.1234, grade: 3.4567, recovery: 0.8765,
      payability: 0.9876, processing: 123.45, transport: 67.89, other: 10.11,
      price: 345678.91, targetProfit: 0, margin: 10, targetMode: 'percentage',
    ));
    expect(r.dryWeight, closeTo(1082.2214322, 1e-7));
    expect(r.maximumBid.isFinite, isTrue);
  });

  test('rejects zero weight, invalid statutory percentages and non-finite values', () {
    expect(() => ValuationEngine.calculate(_input(wet: 0)), throwsArgumentError);
    expect(() => ValuationEngine.calculate(_input(royalty: 60, inspection: 50)), throwsArgumentError);
    expect(() => ValuationEngine.calculate(_input(royalty: -1)), throwsArgumentError);
    expect(() => ValuationEngine.calculate(_input(grade: double.nan)), throwsArgumentError);
    expect(() => ValuationEngine.dryWeight(100, 1.2), throwsArgumentError);
  });

  test('field screening cannot be passed into purchase valuation engine', () {
    expect(() => ValuationEngine.calculate(_input(mode: 'field')), throwsArgumentError);
  });

  test('scenario helper: lower grade gives lower bid', () {
    final base = _input(grade: 5, price: 100000);
    final low = ValuationEngine.calculate(base.copyWithGrade(3), scenario: 'conservative');
    final high = ValuationEngine.calculate(base.copyWithGrade(7), scenario: 'optimistic');
    expect(low.maximumBid, lessThan(high.maximumBid));
    expect(low.gradeUsed, 3);
  });

  test('USD/oz to TZS/g conversion', () {
    expect(PriceConverter.usdPerOunceToTzsPerGram(3000, 2600), closeTo(250775.8232, 0.001));
    expect(() => PriceConverter.usdPerOunceToTzsPerGram(0, 2600), throwsArgumentError);
    expect(() => PriceConverter.usdPerOunceToTzsPerGram(3000, -1), throwsArgumentError);
  });

  test('assay comparison reports CV, outliers and warns that one sample is insufficient', () {
    final single = AssayAnalysisEngine.analyse([4.2]);
    expect(single.coefficientOfVariationPercent, isNull);
    expect(single.warnings, isNotEmpty);
    final multiple = AssayAnalysisEngine.analyse([4.0, 4.2, 4.4]);
    expect(multiple.count, 3);
    expect(multiple.meanGramsPerTonne, closeTo(4.2, 1e-9));
    expect(multiple.coefficientOfVariationPercent, closeTo(4.7619, 0.001));
    final wild = AssayAnalysisEngine.analyse([2, 4, 6]);
    expect(wild.coefficientOfVariationPercent, closeTo(50, 1e-9));
  });

  test('assay comparison rejects negative and non-finite grades', () {
    expect(() => AssayAnalysisEngine.analyse([1, -1]), throwsArgumentError);
    expect(() => AssayAnalysisEngine.analyse([double.nan]), throwsArgumentError);
  });

  test('number parsing: money/weight amounts are never silently misread', () {
    expect(parseNum('3,5'), 3.5);
    expect(parseNum('3.5'), 3.5);
    expect(parseNum('1,234.5'), 1234.5);
    expect(parseNum('1.234,5'), 1234.5);
    expect(parseNum('500,000'), isNull); // utata: si 500
    expect(parseNum('1,250'), isNull); // utata: 1.25 au 1250
    expect(isAmbiguousNumber('500,000'), isTrue);
    expect(isAmbiguousNumber('3,5'), isFalse);
    expect(parseNum('1,500,000'), 1500000);
    expect(parseNum('12,345,678.9'), 12345678.9);
    expect(parseNum('500000'), 500000);
    expect(parseNum('1,2,3'), isNull);
    expect(parseNum('1.2.3'), isNull);
    expect(parseNum('1,50,000'), isNull);
    expect(parseNum('3,5000'), 3.5);
    expect(parseNum(' 120 '), 120);
    expect(parseNum('-5'), -5);
    expect(parseNum('abc'), isNull);
    expect(parseNum('1e5'), isNull);
    expect(parseNum(''), isNull);
    expect(parseGradeList('3.8; 4.1 5'), [3.8, 4.1, 5]);
    expect(parseGradeList('3.8; -1'), isNull);
    expect(parseGradeList(''), isEmpty);
  });

  test('two very different assays require acknowledgement (n=2)', () {
    final r = AssayAnalysisEngine.analyse([5, 25]);
    expect(r.requiresAcknowledgement, isTrue);
    expect(r.rangeRatio, closeTo(5, 1e-9));
    expect(AssayAnalysisEngine.analyse([4.0, 4.2]).requiresAcknowledgement, isFalse);
  });

  test('outlier detection works for small samples (2 SD rule could not)', () {
    final r = AssayAnalysisEngine.analyse([4.0, 4.2, 4.1, 12.0]);
    expect(r.outlierIndexes, [3]);
    expect(r.requiresAcknowledgement, isTrue);
    final tight = AssayAnalysisEngine.analyse([4.0, 4.2, 4.1]);
    expect(tight.outlierIndexes, isEmpty);
  });

  test('stress scenarios change price and recovery, not only grade', () {
    final base = _input(grade: 5, price: 100000, recovery: 0.8);
    final low = ValuationEngine.calculate(
        base.copyWith(grade: 3, price: 90000, recovery: 0.75),
        scenario: 'conservative');
    final high = ValuationEngine.calculate(
        base.copyWith(grade: 7, price: 110000, recovery: 0.85),
        scenario: 'optimistic');
    expect(low.priceUsed, 90000);
    expect(low.recoveryUsed, closeTo(0.75, 1e-12));
    expect(high.priceUsed, 110000);
    expect(low.maximumBid, lessThan(high.maximumBid));
    final gradeOnly = ValuationEngine.calculate(base.copyWithGrade(3), scenario: 'conservative');
    expect(low.maximumBid, lessThan(gradeOnly.maximumBid));
  });

  test('backup passphrase strength rules', () {
    expect(SecureBackup.passphraseProblem('short1A'), isNotNull);
    expect(SecureBackup.passphraseProblem('123456789012'), isNotNull);
    expect(SecureBackup.passphraseProblem('aaaaaaaaaaaaaaaa'), isNotNull);
    expect(SecureBackup.passphraseProblem('abcdefghijklmnop'), isNotNull); // aina 1, <20
    expect(SecureBackup.passphraseProblem('Dhahabu2026Geita'), isNull);
    expect(SecureBackup.passphraseProblem('mimi nanunua dhahabu geita'), isNull); // sentensi 20+
  });

  test('PDF text is made safe for the default Latin-1 font', () {
    expect(ReportService.pdfSafe('CV \u2265 20% \u2014 sawa'), 'CV >= 20% - sawa');
    expect(ReportService.pdfSafe('\u0161'), '?'); // U+0161 > 0xFF -> '?'
  });

  test('GoldAssessment uses values_json for the database and accepts legacy keys', () {
    final a = GoldAssessment(
      id: 'x', title: 't', mode: 'laboratory', assessmentType: 'laboratory',
      createdAt: DateTime.utc(2026, 1, 1), formulaVersion: 'v', values: {'a': 1},
      result: {'maximumBid': 5.0}, notes: '',
    );
    final db = a.toDbMap();
    expect(db.containsKey('values'), isFalse);
    expect(db['values_json'], isA<String>());
    expect(GoldAssessment.fromMap(db).values['a'], 1);
    expect(GoldAssessment.fromMap(a.toMap()).values['a'], 1); // legacy/backup
    expect(a.maximumBid, 5.0);
  });
}
