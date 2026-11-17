class ValuationInput {
  const ValuationInput({
    required this.title,
    required this.mode,
    required this.wetWeight,
    required this.moistureFraction,
    required this.gradeGramsPerTonne,
    required this.recoveryFraction,
    required this.payabilityFraction,
    required this.processingCosts,
    required this.transportCosts,
    required this.otherCosts,
    required this.goldPricePerGram,
    required this.targetProfit,
    required this.targetMarginPercent,
    required this.notes,
    required this.sampleId,
  });

  final String title;
  final String mode;
  final double wetWeight;
  final double moistureFraction;
  final double gradeGramsPerTonne;
  final double recoveryFraction;
  final double payabilityFraction;
  final double processingCosts;
  final double transportCosts;
  final double otherCosts;
  final double goldPricePerGram;
  final double targetProfit;
  final double targetMarginPercent;
  final String notes;
  final String sampleId;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'mode': mode,
      'wetWeight': wetWeight,
      'moistureFraction': moistureFraction,
      'gradeGramsPerTonne': gradeGramsPerTonne,
      'recoveryFraction': recoveryFraction,
      'payabilityFraction': payabilityFraction,
      'processingCosts': processingCosts,
      'transportCosts': transportCosts,
      'otherCosts': otherCosts,
      'goldPricePerGram': goldPricePerGram,
      'targetProfit': targetProfit,
      'targetMarginPercent': targetMarginPercent,
      'notes': notes,
      'sampleId': sampleId,
    };
  }
}

class ValuationResult {
  const ValuationResult({
    required this.dryWeight,
    required this.containedGold,
    required this.recoveredGold,
    required this.payableGold,
    required this.revenue,
    required this.maximumBid,
    required this.isPositive,
    required this.scenario,
    required this.confidence,
  });

  final double dryWeight;
  final double containedGold;
  final double recoveredGold;
  final double payableGold;
  final double revenue;
  final double maximumBid;
  final bool isPositive;
  final String scenario;
  final String confidence;

  Map<String, dynamic> toMap() {
    return {
      'dryWeight': dryWeight,
      'containedGold': containedGold,
      'recoveredGold': recoveredGold,
      'payableGold': payableGold,
      'revenue': revenue,
      'maximumBid': maximumBid,
      'isPositive': isPositive,
      'scenario': scenario,
      'confidence': confidence,
    };
  }
}
