/// Aina za ore na ushahidi wa recovery. Aina ya ore au asilimia ya sulfide
/// HAIBADILISHI recovery kamwe; zinaamua tu ni ushahidi gani unahitajika.
class OreTypes {
  static const String oxide = 'oxide';
  static const String transition = 'transition';
  static const String sulfide = 'sulfide';
  static const String refractorySulfide = 'refractory_sulfide';
  static const String freeMilling = 'free_milling';
  static const String alluvial = 'alluvial';
  static const String other = 'other';

  static const List<String> all = [
    oxide, transition, sulfide, refractorySulfide, freeMilling, alluvial, other,
  ];

  /// Ore ya sulfide haiwezi kuthaminiwa kwa recovery ya kudhani.
  static bool requiresEvidence(String type) =>
      type == sulfide || type == refractorySulfide;

  static String label(String type, {required bool sw}) {
    switch (type) {
      case oxide:
        return sw ? 'Oxide (iliyoharibika hewani)' : 'Oxide';
      case transition:
        return sw ? 'Transition (mchanganyiko)' : 'Transition';
      case sulfide:
        return 'Sulfide';
      case refractorySulfide:
        return sw ? 'Sulfide refractory (ngumu kuchakata)' : 'Refractory sulfide';
      case freeMilling:
        return 'Free-milling';
      case alluvial:
        return sw ? 'Alluvial (mchanga/changarawe)' : 'Alluvial';
      default:
        return sw ? 'Nyingine / haijulikani' : 'Other / unknown';
    }
  }
}

class RecoveryEvidenceTypes {
  static const String metallurgicalTest = 'metallurgical_test';
  static const String productionHistory = 'production_history';
  static const String assumption = 'assumption';

  static const List<String> all = [metallurgicalTest, productionHistory, assumption];

  static bool isEvidenced(String type) =>
      type == metallurgicalTest || type == productionHistory;

  static String label(String type, {required bool sw}) {
    switch (type) {
      case metallurgicalTest:
        return sw ? 'Jaribio la metallurgical (bottle roll/leach test)' : 'Metallurgical test (bottle roll/leach test)';
      case productionHistory:
        return sw ? 'Historia ya uzalishaji wa ore hii/mgodi huu' : 'Production history of this ore/mine';
      default:
        return sw ? 'Dhana tu (haina ushahidi)' : 'Assumption only (no evidence)';
    }
  }
}

/// Matokeo halisi ya uchakataji (baada ya kuchakata na kupima bidhaa).
/// Dhahabu safi (fine gold) = uzito wa bidhaa × purity. Purity inatumika MARA
/// MOJA tu hapa; "recovered gold" ya makadirio tayari ni dhahabu safi.
class ActualOutcome {
  const ActualOutcome({
    required this.productMassGrams,
    required this.purityFraction,
    this.salePricePerGram,
    this.chemicalCosts,
    this.processingCosts,
    this.transportCosts,
    this.otherCosts,
    this.reference = '',
    this.recordedAt = '',
  });

  /// Uzito wa bidhaa ya dhahabu (doré/gold product) kwa gramu.
  final double productMassGrams;

  /// Purity kama sehemu (0–1], mf. 0.85 = 85% (kutoka assay/refinery/XRF).
  final double purityFraction;

  /// Bei halisi ya kuuzia (TZS/g); tupu = tumia bei ya tathmini.
  final double? salePricePerGram;
  final double? chemicalCosts;
  final double? processingCosts;
  final double? transportCosts;
  final double? otherCosts;

  /// Rejea ya risiti ya refinery/mnunuzi/ripoti ya purity.
  final String reference;
  final String recordedAt;

  Map<String, dynamic> toMap() => {
        'productMassGrams': productMassGrams,
        'purityFraction': purityFraction,
        'salePricePerGram': salePricePerGram,
        'chemicalCosts': chemicalCosts,
        'processingCosts': processingCosts,
        'transportCosts': transportCosts,
        'otherCosts': otherCosts,
        'reference': reference,
        'recordedAt': recordedAt,
      };

  static double? _opt(Object? v) => v is num ? v.toDouble() : null;

  static ActualOutcome fromMap(Map<dynamic, dynamic> m) => ActualOutcome(
        productMassGrams: (m['productMassGrams'] as num).toDouble(),
        purityFraction: (m['purityFraction'] as num).toDouble(),
        salePricePerGram: _opt(m['salePricePerGram']),
        chemicalCosts: _opt(m['chemicalCosts']),
        processingCosts: _opt(m['processingCosts']),
        transportCosts: _opt(m['transportCosts']),
        otherCosts: _opt(m['otherCosts']),
        reference: m['reference'] as String? ?? '',
        recordedAt: m['recordedAt'] as String? ?? '',
      );
}

/// Ulinganisho wa makadirio dhidi ya matokeo halisi (imekokotolewa na engine).
class ActualComparison {
  const ActualComparison({
    required this.productMassGrams,
    required this.purityFraction,
    required this.actualFineGold,
    required this.actualRecoveryFraction,
    required this.actualPayableGold,
    required this.salePriceUsed,
    required this.actualRevenue,
    required this.actualStatutoryDeductions,
    required this.actualTotalCosts,
    required this.actualProfit,
    required this.estimatedFineGold,
    required this.estimatedRecoveryFraction,
    required this.estimatedRevenue,
    required this.estimatedProfit,
    required this.fineGoldVarianceGrams,
    required this.fineGoldVariancePercent,
    required this.recoveryVariancePoints,
    required this.revenueVariance,
    required this.profitVariance,
    required this.warnings,
  });

  final double productMassGrams;
  final double purityFraction;
  final double actualFineGold;
  final double? actualRecoveryFraction;
  final double actualPayableGold;
  final double salePriceUsed;
  final double actualRevenue;
  final double actualStatutoryDeductions;
  final double actualTotalCosts;
  final double actualProfit;
  final double estimatedFineGold;
  final double estimatedRecoveryFraction;
  final double estimatedRevenue;
  final double estimatedProfit;
  final double fineGoldVarianceGrams;
  final double? fineGoldVariancePercent;
  final double? recoveryVariancePoints;
  final double revenueVariance;
  final double profitVariance;
  final List<String> warnings;

  Map<String, dynamic> toMap() => {
        'productMassGrams': productMassGrams,
        'purityFraction': purityFraction,
        'actualFineGold': actualFineGold,
        'actualRecoveryFraction': actualRecoveryFraction,
        'actualPayableGold': actualPayableGold,
        'salePriceUsed': salePriceUsed,
        'actualRevenue': actualRevenue,
        'actualStatutoryDeductions': actualStatutoryDeductions,
        'actualTotalCosts': actualTotalCosts,
        'actualProfit': actualProfit,
        'estimatedFineGold': estimatedFineGold,
        'estimatedRecoveryFraction': estimatedRecoveryFraction,
        'estimatedRevenue': estimatedRevenue,
        'estimatedProfit': estimatedProfit,
        'fineGoldVarianceGrams': fineGoldVarianceGrams,
        'fineGoldVariancePercent': fineGoldVariancePercent,
        'recoveryVariancePoints': recoveryVariancePoints,
        'revenueVariance': revenueVariance,
        'profitVariance': profitVariance,
        'warnings': warnings,
      };
}
