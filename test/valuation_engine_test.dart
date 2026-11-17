import 'package:flutter_test/flutter_test.dart';

import 'package:madini/domain/valuation_models.dart';
import 'package:madini/services/valuation_engine.dart';

void main() {
  test('dry weight formula is applied correctly', () {
    expect(ValuationEngine.dryWeight(1000, 0.12), closeTo(880, 0.0001));
  });

  test('valuation engine computes a valid purchase decision', () {
    final result = ValuationEngine.calculate(
      const ValuationInput(
        title: 'Ore Lot A',
        mode: 'laboratory',
        wetWeight: 1000,
        moistureFraction: 0.08,
        gradeGramsPerTonne: 4.5,
        recoveryFraction: 0.75,
        payabilityFraction: 0.9,
        processingCosts: 2500,
        transportCosts: 1000,
        otherCosts: 500,
        goldPricePerGram: 120,
        targetProfit: 2000,
        targetMarginPercent: 15,
        notes: 'Test scenario',
        sampleId: 'SAMPLE-1',
      ),
    );

    expect(result.dryWeight, closeTo(920, 0.001));
    expect(result.containedGold, closeTo(4.14, 0.01));
    expect(result.recoveredGold, closeTo(3.105, 0.01));
    expect(result.payableGold, closeTo(2.7945, 0.01));
    expect(result.maximumBid, lessThan(0));
  });

  test('validation rejects impossible moisture ranges', () {
    expect(() => ValuationEngine.dryWeight(100, 1.2), throwsArgumentError);
  });
}
