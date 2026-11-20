/// Njia za kupima purity ya doré. Njia pekee yenye uaminifu wa juu ni fire
/// assay ya maabara. XRF hupima uso tu; kuangalia kwa macho ni makadirio.
/// Viwango vya "tahadhari" ni pendekezo la awali la bidhaa (halijathibitishwa
/// na mtaalamu); mtumiaji anaweza kuvibadilisha na vinaonekana kwenye ripoti.
class DorePurityMethods {
  static const String fireAssay = 'fire_assay';
  static const String xrf = 'xrf';
  static const String visual = 'visual';

  static const List<String> all = [fireAssay, xrf, visual];

  /// Fire assay imechaguliwa na rejea imetolewa; programu haithibitishi
  /// uhalisi wa ripoti wala utambulisho wa maabara.
  static bool isVerified(String method) => method == fireAssay;

  /// Tahadhari ya awali (pointi za purity zinazopunguzwa kabla ya hesabu).
  static double defaultCautionPoints(String method) {
    switch (method) {
      case fireAssay:
        return 0;
      case xrf:
        return 2;
      default:
        return 5;
    }
  }

  static String label(String method, {required bool sw}) {
    switch (method) {
      case fireAssay:
        return sw ? 'Fire assay (maabara) - juu' : 'Fire assay (laboratory) - high';
      case xrf:
        return sw ? 'XRF - wastani (hupima uso tu)' : 'XRF - medium (surface only)';
      default:
        return sw ? 'Kuangalia kwa macho/uzoefu - chini' : 'Visual/experience - low';
    }
  }
}

/// Ingizo la tathmini ya ununuzi wa doré (dhahabu isiyosafishwa kabisa).
class DoreInput {
  const DoreInput({
    required this.title,
    required this.sampleId,
    required this.grossMassGrams,
    this.weightLossFraction = 0,
    required this.measuredPurityFraction,
    this.purityMethod = DorePurityMethods.visual,
    this.purityReference = '',
    this.purityCautionPoints = 0,
    required this.payabilityFraction,
    required this.goldPricePerGram,
    this.refiningCosts = 0,
    this.transportCosts = 0,
    this.otherCosts = 0,
    this.royaltyPercent = 0,
    this.inspectionFeePercent = 0,
    this.otherStatutoryPercent = 0,
    this.statutoryVerified = false,
    this.statutoryReference = '',
    this.targetMode = 'fixed',
    this.targetProfit = 0,
    this.targetMarginPercent = 0,
    this.purchasePrice = 0,
    this.scaleResolutionGrams,
    this.notes = '',
  });

  final String title;
  final String sampleId;

  /// Uzito wa doré kama ulivyopimwa kwenye mizani (g).
  final double grossMassGrams;

  /// Punguzo la uzito kwa unyevu/zebaki/slag (sehemu 0..<1). 0 = hakuna.
  final double weightLossFraction;

  /// Purity iliyopimwa (sehemu (0,1]).
  final double measuredPurityFraction;
  final String purityMethod;

  /// Rejea ya ripoti ya assay / jina la fundi wa XRF. Fire assay inahitaji rejea.
  final String purityReference;

  /// Pointi za purity zinazopunguzwa kwa tahadhari (purity iliyotumika =
  /// iliyopimwa − pointi/100).
  final double purityCautionPoints;
  final double payabilityFraction;
  final double goldPricePerGram;

  /// Gharama za refining/assay (TZS, jumla ya loti).
  final double refiningCosts;
  final double transportCosts;
  final double otherCosts;
  final double royaltyPercent;
  final double inspectionFeePercent;
  final double otherStatutoryPercent;
  final bool statutoryVerified;
  final String statutoryReference;
  final String targetMode;
  final double targetProfit;
  final double targetMarginPercent;
  final double purchasePrice;

  /// Usahihi wa mizani (g), kwa onyo la kutokuwa na uhakika wa uzito.
  final double? scaleResolutionGrams;
  final String notes;

  Map<String, dynamic> toMap() => {
        'kind': 'dore',
        'title': title,
        'sampleId': sampleId,
        'grossMassGrams': grossMassGrams,
        'weightLossFraction': weightLossFraction,
        'measuredPurityFraction': measuredPurityFraction,
        'purityMethod': purityMethod,
        'purityReference': purityReference,
        'purityCautionPoints': purityCautionPoints,
        'payabilityFraction': payabilityFraction,
        'goldPricePerGram': goldPricePerGram,
        'refiningCosts': refiningCosts,
        'transportCosts': transportCosts,
        'otherCosts': otherCosts,
        'royaltyPercent': royaltyPercent,
        'inspectionFeePercent': inspectionFeePercent,
        'otherStatutoryPercent': otherStatutoryPercent,
        'statutoryVerified': statutoryVerified,
        'statutoryReference': statutoryReference,
        'targetMode': targetMode,
        'targetProfit': targetProfit,
        'targetMarginPercent': targetMarginPercent,
        'purchasePrice': purchasePrice,
        'scaleResolutionGrams': scaleResolutionGrams,
        'notes': notes,
      };

  static double _n(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
  static String _s(Object? v, [String d = '']) => v is String ? v : d;

  factory DoreInput.fromMap(Map<String, dynamic> m) => DoreInput(
        title: _s(m['title']),
        sampleId: _s(m['sampleId']),
        grossMassGrams: _n(m['grossMassGrams']),
        weightLossFraction: _n(m['weightLossFraction']),
        measuredPurityFraction: _n(m['measuredPurityFraction']),
        purityMethod: _s(m['purityMethod'], DorePurityMethods.visual),
        purityReference: _s(m['purityReference']),
        purityCautionPoints: _n(m['purityCautionPoints']),
        payabilityFraction: _n(m['payabilityFraction']),
        goldPricePerGram: _n(m['goldPricePerGram']),
        refiningCosts: _n(m['refiningCosts']),
        transportCosts: _n(m['transportCosts']),
        otherCosts: _n(m['otherCosts']),
        royaltyPercent: _n(m['royaltyPercent']),
        inspectionFeePercent: _n(m['inspectionFeePercent']),
        otherStatutoryPercent: _n(m['otherStatutoryPercent']),
        statutoryVerified: m['statutoryVerified'] == true,
        statutoryReference: _s(m['statutoryReference']),
        targetMode: _s(m['targetMode'], 'fixed'),
        targetProfit: _n(m['targetProfit']),
        targetMarginPercent: _n(m['targetMarginPercent']),
        purchasePrice: _n(m['purchasePrice']),
        scaleResolutionGrams:
            m['scaleResolutionGrams'] is num ? (m['scaleResolutionGrams'] as num).toDouble() : null,
        notes: _s(m['notes']),
      );
}

class DoreResult {
  const DoreResult({
    required this.netMassGrams,
    required this.purityMeasured,
    required this.purityUsed,
    required this.fineGold,
    required this.payableGold,
    required this.revenue,
    required this.statutoryDeductions,
    required this.totalCosts,
    required this.netBeforePurchase,
    required this.purchasePrice,
    required this.profit,
    required this.maximumBid,
    required this.isPositive,
    required this.scenario,
    required this.priceUsed,
    required this.purityMethod,
    required this.purityVerified,
    required this.confidence,
  });

  /// Uzito halisi = gross × (1 − weight loss).
  final double netMassGrams;
  final double purityMeasured;

  /// Purity iliyotumika kwenye hesabu (iliyopimwa − tahadhari, ± scenario).
  final double purityUsed;

  /// Dhahabu safi (g) = net mass × purity iliyotumika (purity mara moja tu).
  final double fineGold;

  /// Dhahabu safi inayolipiwa = fine × payability.
  final double payableGold;
  final double revenue;
  final double statutoryDeductions;
  final double totalCosts;
  final double netBeforePurchase;
  final double purchasePrice;
  final double profit;
  final double maximumBid;
  final bool isPositive;
  final String scenario;
  final double priceUsed;
  final String purityMethod;
  final bool purityVerified;
  final String confidence;

  Map<String, dynamic> toMap() => {
        'kind': 'dore',
        'netMassGrams': netMassGrams,
        'purityMeasured': purityMeasured,
        'purityUsed': purityUsed,
        'fineGold': fineGold,
        'payableGold': payableGold,
        'revenue': revenue,
        'statutoryDeductions': statutoryDeductions,
        'totalCosts': totalCosts,
        'netBeforePurchase': netBeforePurchase,
        'purchasePrice': purchasePrice,
        'profit': profit,
        'maximumBid': maximumBid,
        'isPositive': isPositive,
        'scenario': scenario,
        'priceUsed': priceUsed,
        'purityMethod': purityMethod,
        'purityVerified': purityVerified,
        // "Declared" si uthibitisho wa uhalisi wa cheti/maabara.
        'valuationGrade': purityVerified ? 'fire_assay_declared' : 'indicative',
        'purityIndependentlyVerified': false,
        'confidence': confidence,
      };
}

class DoreScenarioSet {
  const DoreScenarioSet(this.conservative, this.expected, this.optimistic);
  final DoreResult conservative;
  final DoreResult expected;
  final DoreResult optimistic;

  Map<String, dynamic> toMap() => {
        'conservative': conservative.toMap(),
        'expected': expected.toMap(),
        'optimistic': optimistic.toMap(),
      };
}

/// Ulinganisho wa makadirio ya doré dhidi ya matokeo halisi ya refinery/mnunuzi.
class DoreActualComparison {
  const DoreActualComparison({
    required this.refineryMassGrams,
    required this.refineryPurityFraction,
    required this.actualFineGold,
    required this.estimatedFineGold,
    required this.fineGoldVarianceGrams,
    required this.fineGoldVariancePercent,
    required this.purityUsedEstimate,
    required this.purityVariancePoints,
    required this.actualPayableGold,
    required this.salePriceUsed,
    required this.actualRevenue,
    required this.actualStatutoryDeductions,
    required this.actualTotalCosts,
    required this.actualProfit,
    required this.estimatedRevenue,
    required this.estimatedProfit,
    required this.revenueVariance,
    required this.profitVariance,
    required this.warnings,
  });

  final double refineryMassGrams;
  final double refineryPurityFraction;
  final double actualFineGold;
  final double estimatedFineGold;
  final double fineGoldVarianceGrams;
  final double? fineGoldVariancePercent;
  final double purityUsedEstimate;

  /// (purity halisi − purity iliyotumika kwenye makadirio) × 100.
  final double purityVariancePoints;
  final double actualPayableGold;
  final double salePriceUsed;
  final double actualRevenue;
  final double actualStatutoryDeductions;
  final double actualTotalCosts;
  final double actualProfit;
  final double estimatedRevenue;
  final double estimatedProfit;
  final double revenueVariance;
  final double profitVariance;
  final List<String> warnings;

  Map<String, dynamic> toMap() => {
        'kind': 'dore',
        'refineryMassGrams': refineryMassGrams,
        'refineryPurityFraction': refineryPurityFraction,
        'actualFineGold': actualFineGold,
        'estimatedFineGold': estimatedFineGold,
        'fineGoldVarianceGrams': fineGoldVarianceGrams,
        'fineGoldVariancePercent': fineGoldVariancePercent,
        'purityUsedEstimate': purityUsedEstimate,
        'purityVariancePoints': purityVariancePoints,
        'actualPayableGold': actualPayableGold,
        'salePriceUsed': salePriceUsed,
        'actualRevenue': actualRevenue,
        'actualStatutoryDeductions': actualStatutoryDeductions,
        'actualTotalCosts': actualTotalCosts,
        'actualProfit': actualProfit,
        'estimatedRevenue': estimatedRevenue,
        'estimatedProfit': estimatedProfit,
        'revenueVariance': revenueVariance,
        'profitVariance': profitVariance,
        'warnings': warnings,
      };
}
