import 'recovery_models.dart';

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
    this.targetMode = 'fixed',
    required this.notes,
    required this.sampleId,
    this.royaltyPercent = 0,
    this.inspectionFeePercent = 0,
    this.otherStatutoryPercent = 0,
    this.oreType = OreTypes.other,
    this.sulfidePercent,
    this.recoveryEvidence = RecoveryEvidenceTypes.assumption,
    this.recoveryEvidenceRef = '',
    this.chemicalCosts = 0,
    this.purchasePrice = 0,
    this.statutoryVerified = false,
    this.statutoryReference = '',
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

  /// 'fixed' deducts targetProfit; 'percentage' deducts revenue * margin%.
  final String targetMode;
  final String notes;
  final String sampleId;

  /// Makato ya asilimia ya mapato ya jumla. Ni MAKADIRIO ya mtumiaji: programu
  /// haithibitishi kuwa ni sheria rasmi (angalia [statutoryVerified]).
  final double royaltyPercent;
  final double inspectionFeePercent;
  final double otherStatutoryPercent;

  /// Aina ya ore (taarifa + kanuni ya ushahidi; haibadilishi recovery).
  final String oreType;

  /// Asilimia ya sulfide (hiari). Haitumiki kutabiri recovery.
  final double? sulfidePercent;

  /// Ushahidi wa recovery: jaribio la metallurgical, historia ya uzalishaji,
  /// au dhana tu. Ukiwa si dhana, [recoveryEvidenceRef] inahitajika.
  final String recoveryEvidence;
  final String recoveryEvidenceRef;

  /// Gharama za kemikali (cyanide, lime, reagents n.k.) kwa TZS, jumla ya loti.
  final double chemicalCosts;

  /// Bei halisi ya kununua ore (TZS). 0 = haijawekwa (faida ni kabla ya ununuzi).
  final double purchasePrice;

  /// Mtumiaji amethibitisha asilimia za makato na chanzo chake (si programu).
  final bool statutoryVerified;
  final String statutoryReference;

  ValuationInput copyWithGrade(double grade) => copyWith(grade: grade);

  /// Nakala yenye grade/bei/recovery zilizobadilishwa (kwa scenarios).
  ValuationInput copyWith({double? grade, double? price, double? recovery}) => ValuationInput(
        title: title,
        mode: mode,
        wetWeight: wetWeight,
        moistureFraction: moistureFraction,
        gradeGramsPerTonne: grade ?? gradeGramsPerTonne,
        recoveryFraction: recovery ?? recoveryFraction,
        payabilityFraction: payabilityFraction,
        processingCosts: processingCosts,
        transportCosts: transportCosts,
        otherCosts: otherCosts,
        goldPricePerGram: price ?? goldPricePerGram,
        targetProfit: targetProfit,
        targetMarginPercent: targetMarginPercent,
        targetMode: targetMode,
        notes: notes,
        sampleId: sampleId,
        royaltyPercent: royaltyPercent,
        inspectionFeePercent: inspectionFeePercent,
        otherStatutoryPercent: otherStatutoryPercent,
        oreType: oreType,
        sulfidePercent: sulfidePercent,
        recoveryEvidence: recoveryEvidence,
        recoveryEvidenceRef: recoveryEvidenceRef,
        chemicalCosts: chemicalCosts,
        purchasePrice: purchasePrice,
        statutoryVerified: statutoryVerified,
        statutoryReference: statutoryReference,
      );

  Map<String, dynamic> toMap() => {
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
        'targetMode': targetMode,
        'notes': notes,
        'sampleId': sampleId,
        'royaltyPercent': royaltyPercent,
        'inspectionFeePercent': inspectionFeePercent,
        'otherStatutoryPercent': otherStatutoryPercent,
        'oreType': oreType,
        'sulfidePercent': sulfidePercent,
        'recoveryEvidence': recoveryEvidence,
        'recoveryEvidenceRef': recoveryEvidenceRef,
        'chemicalCosts': chemicalCosts,
        'purchasePrice': purchasePrice,
        'statutoryVerified': statutoryVerified,
        'statutoryReference': statutoryReference,
      };

  static double _n(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
  static String _s(Object? v, [String d = '']) => v is String ? v : d;

  /// Hurejesha input kutoka rekodi iliyohifadhiwa (inakubali rekodi za V1.3–V1.5
  /// zisizo na sehemu mpya) ili hesabu iweze kurudiwa.
  factory ValuationInput.fromMap(Map<String, dynamic> m) => ValuationInput(
        title: _s(m['title']),
        mode: _s(m['mode'], 'laboratory'),
        wetWeight: _n(m['wetWeight']),
        moistureFraction: _n(m['moistureFraction']),
        gradeGramsPerTonne: _n(m['gradeGramsPerTonne']),
        recoveryFraction: _n(m['recoveryFraction']),
        payabilityFraction: _n(m['payabilityFraction']),
        processingCosts: _n(m['processingCosts']),
        transportCosts: _n(m['transportCosts']),
        otherCosts: _n(m['otherCosts']),
        goldPricePerGram: _n(m['goldPricePerGram']),
        targetProfit: _n(m['targetProfit']),
        targetMarginPercent: _n(m['targetMarginPercent']),
        targetMode: _s(m['targetMode'], 'fixed'),
        notes: _s(m['notes']),
        sampleId: _s(m['sampleId']),
        royaltyPercent: _n(m['royaltyPercent']),
        inspectionFeePercent: _n(m['inspectionFeePercent']),
        otherStatutoryPercent: _n(m['otherStatutoryPercent']),
        oreType: _s(m['oreType'], OreTypes.other),
        sulfidePercent: m['sulfidePercent'] is num ? (m['sulfidePercent'] as num).toDouble() : null,
        recoveryEvidence: _s(m['recoveryEvidence'], RecoveryEvidenceTypes.assumption),
        recoveryEvidenceRef: _s(m['recoveryEvidenceRef']),
        chemicalCosts: _n(m['chemicalCosts']),
        purchasePrice: _n(m['purchasePrice']),
        statutoryVerified: m['statutoryVerified'] == true,
        statutoryReference: _s(m['statutoryReference']),
      );
}

class ValuationResult {
  const ValuationResult({
    required this.dryWeight,
    this.dryTonnes = 0,
    required this.containedGold,
    required this.recoveredGold,
    required this.payableGold,
    required this.revenue,
    required this.statutoryDeductions,
    required this.maximumBid,
    required this.isPositive,
    required this.scenario,
    required this.confidence,
    this.gradeUsed = 0,
    this.priceUsed = 0,
    this.recoveryUsed = 0,
    this.chemicalCosts = 0,
    this.totalCosts = 0,
    this.netBeforePurchase = 0,
    this.purchasePrice = 0,
    this.profit = 0,
    this.recoveryEvidence = RecoveryEvidenceTypes.assumption,
    this.recoveryVerified = false,
    this.oreType = OreTypes.other,
  });

  final double dryWeight;

  /// Uzito mkavu kwa tani = dry kg × 0.001.
  final double dryTonnes;

  /// Dhahabu iliyomo kwenye ore (g) = dry tonnes × grade.
  final double containedGold;

  /// Dhahabu safi (fine gold) inayokadiriwa kupatikana (g) = contained × recovery.
  /// Hii TAYARI ni dhahabu safi; purity haitumiki tena hapa.
  final double recoveredGold;

  /// Dhahabu safi inayolipiwa (g) = recovered × payability.
  final double payableGold;
  final double revenue;
  final double statutoryDeductions;

  /// Bei ya juu ya kununua = mapato − makato − gharama − faida lengwa.
  final double maximumBid;
  final bool isPositive;
  final String scenario;
  final String confidence;
  final double gradeUsed;
  final double priceUsed;
  final double recoveryUsed;
  final double chemicalCosts;

  /// Gharama zote (kemikali + usindikaji + usafirishaji + nyinginezo).
  final double totalCosts;

  /// Mapato − makato − gharama (kabla ya bei ya ununuzi).
  final double netBeforePurchase;
  final double purchasePrice;

  /// Faida = mapato − makato − gharama − bei ya ununuzi (0 ikiwa haijawekwa).
  final double profit;
  final String recoveryEvidence;
  final bool recoveryVerified;
  final String oreType;

  Map<String, dynamic> toMap() => {
        'dryWeight': dryWeight,
        'dryTonnes': dryTonnes,
        'containedGold': containedGold,
        'recoveredGold': recoveredGold,
        'payableGold': payableGold,
        'revenue': revenue,
        'statutoryDeductions': statutoryDeductions,
        'maximumBid': maximumBid,
        'isPositive': isPositive,
        'scenario': scenario,
        'confidence': confidence,
        'gradeUsed': gradeUsed,
        'priceUsed': priceUsed,
        'recoveryUsed': recoveryUsed,
        'chemicalCosts': chemicalCosts,
        'totalCosts': totalCosts,
        'netBeforePurchase': netBeforePurchase,
        'purchasePrice': purchasePrice,
        'profit': profit,
        'recoveryEvidence': recoveryEvidence,
        'recoveryVerified': recoveryVerified,
        'oreType': oreType,
        // Hii inaonyesha ushahidi uliotajwa na mtumiaji, si uthibitisho huru.
        'valuationGrade': recoveryVerified ? 'evidence_declared' : 'indicative',
        'recoveryEvidenceIndependentlyVerified': false,
      };
}
