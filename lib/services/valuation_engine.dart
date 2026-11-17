import 'dart:math' as math;

import '../domain/valuation_models.dart';

class ValuationEngine {
  static const String formulaVersion = 'MADINI v1.0';

  static double dryWeight(double wetWeight, double moistureFraction) {
    if (wetWeight < 0) throw ArgumentError('Wet weight cannot be negative.');
    if (moistureFraction < 0 || moistureFraction >= 1) {
      throw ArgumentError('Moisture fraction must be between 0 and 1.');
    }
    return wetWeight * (1 - moistureFraction);
  }

  static double dryTonnes(double wetWeightKg, double moistureFraction) {
    return (dryWeight(wetWeightKg, moistureFraction) / 1000.0);
  }

  static double containedGoldGrams(double dryTonnesValue, double gradeGramsPerTonne) {
    if (gradeGramsPerTonne < 0) {
      throw ArgumentError('Grade cannot be negative.');
    }
    return dryTonnesValue * gradeGramsPerTonne;
  }

  static double recoveredGold(double containedGold, double recoveryFraction) {
    if (recoveryFraction < 0 || recoveryFraction > 1) {
      throw ArgumentError('Recovery fraction must be between 0 and 1.');
    }
    return containedGold * recoveryFraction;
  }

  static double payableGold(double recoveredGoldValue, double payabilityFraction) {
    if (payabilityFraction < 0 || payabilityFraction > 1) {
      throw ArgumentError('Payability fraction must be between 0 and 1.');
    }
    return recoveredGoldValue * payabilityFraction;
  }

  static double estimatedRevenue(double payableGoldValue, double fineGoldPricePerGram) {
    if (fineGoldPricePerGram < 0) {
      throw ArgumentError('Gold price cannot be negative.');
    }
    return payableGoldValue * fineGoldPricePerGram;
  }

  static double maximumBid(
    double revenue,
    double processingCosts,
    double transportCosts,
    double otherCosts,
    double targetProfit,
  ) {
    if (revenue < 0) throw ArgumentError('Revenue cannot be negative.');
    if (processingCosts < 0 || transportCosts < 0 || otherCosts < 0 || targetProfit < 0) {
      throw ArgumentError('Costs and profit cannot be negative.');
    }
    return revenue - processingCosts - transportCosts - otherCosts - targetProfit;
  }

  static ValuationResult calculate(ValuationInput input, {String scenario = 'expected'}) {
    final dryWeightValue = dryWeight(input.wetWeight, input.moistureFraction);
    final dryTonnesValue = dryTonnes(input.wetWeight, input.moistureFraction);
    final containedGoldValue = containedGoldGrams(dryTonnesValue, input.gradeGramsPerTonne);
    final recoveredGoldValue = recoveredGold(containedGoldValue, input.recoveryFraction);
    final payableGoldValue = payableGold(recoveredGoldValue, input.payabilityFraction);
    final revenueValue = estimatedRevenue(payableGoldValue, input.goldPricePerGram);
    final maxBidValue = maximumBid(
      revenueValue,
      input.processingCosts,
      input.transportCosts,
      input.otherCosts,
      input.targetProfit,
    );

    final margin = input.targetMarginPercent.clamp(0, 100);
    final marginAdjusted = revenueValue > 0 ? revenueValue * (margin / 100) : 0;
    final marginBid = revenueValue - input.processingCosts - input.transportCosts - input.otherCosts - marginAdjusted;

    final bool isPositive = maxBidValue > 0 || marginBid > 0;

    return ValuationResult(
      dryWeight: dryWeightValue,
      containedGold: containedGoldValue,
      recoveredGold: recoveredGoldValue,
      payableGold: payableGoldValue,
      revenue: revenueValue,
      maximumBid: math.max(maxBidValue, marginBid),
      isPositive: isPositive,
      scenario: scenario,
      confidence: input.mode == 'field' ? 'Low to moderate confidence' : 'Assay-supported estimate',
    );
  }
}
