import 'dart:math' as math;

class AssayAnalysis {
  const AssayAnalysis({
    required this.count,
    required this.meanGramsPerTonne,
    required this.medianGramsPerTonne,
    required this.standardDeviation,
    required this.coefficientOfVariationPercent,
    required this.rangeRatio,
    required this.outlierIndexes,
    required this.requiresAcknowledgement,
    required this.warnings,
  });

  final int count;
  final double meanGramsPerTonne;
  final double medianGramsPerTonne;
  final double standardDeviation;
  final double? coefficientOfVariationPercent;

  /// max / min (null kama sampuli moja au min = 0).
  final double? rangeRatio;
  final List<int> outlierIndexes;

  /// Kweli pale utofauti ni mkubwa kiasi cha kuhitaji mtumiaji akiri kabla
  /// ya kuhifadhi (angalau sampuli 2).
  final bool requiresAcknowledgement;
  final List<String> warnings;

  Map<String, dynamic> toMap() => {
        'count': count,
        'meanGramsPerTonne': meanGramsPerTonne,
        'medianGramsPerTonne': medianGramsPerTonne,
        'standardDeviation': standardDeviation,
        'coefficientOfVariationPercent': coefficientOfVariationPercent,
        'rangeRatio': rangeRatio,
        'outlierIndexes': outlierIndexes,
        'requiresAcknowledgement': requiresAcknowledgement,
        'warnings': warnings,
      };
}

/// Descriptive comparison only. It does not prove that samples represent a lot.
///
/// Thresholds (heuristic za awali, zinahitaji kuidhinishwa na mtaalamu):
/// * CV >= 20% au max/min >= 2 kwa sampuli 2 au zaidi -> inahitaji kukiri.
/// * Outlier: sampuli 3+ zinalinganishwa na MEDIAN (si wastani/SD, kwani
///   z-score ya juu kabisa kwa n ndogo ni (n-1)/sqrt(n) < 2 hadi n=5, hivyo
///   kigezo cha 2 SD hakiwezi kuwaka kamwe kwa sampuli 3-5). Thamani ni outlier
///   ikitofautiana na median kwa zaidi ya 50%; kwa n >= 5 pia robust z (MAD)
///   > 3.5.
class AssayAnalysisEngine {
  static const double cvAcknowledgePercent = 20;
  static const double rangeRatioAcknowledge = 2;
  static const double outlierRelativeLimit = 0.5;

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static AssayAnalysis analyse(List<double> grades) {
    if (grades.isEmpty) throw ArgumentError('At least one assay grade is required.');
    if (grades.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Assay grades must be finite and non-negative.');
    }
    final n = grades.length;
    final mean = grades.reduce((a, b) => a + b) / n;
    final variance = n < 2
        ? 0.0
        : grades.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / (n - 1);
    final sd = math.sqrt(variance);
    final cv = (n < 2 || mean == 0) ? null : sd / mean * 100;
    final median = _median(grades);
    final minV = grades.reduce(math.min);
    final maxV = grades.reduce(math.max);
    final ratio = n >= 2 && minV > 0 ? maxV / minV : null;

    final outliers = <int>[];
    if (n >= 3 && median > 0) {
      final deviations = grades.map((v) => (v - median).abs()).toList();
      final mad = _median(deviations);
      for (var i = 0; i < n; i++) {
        final relative = deviations[i] / median > outlierRelativeLimit;
        final robustZ = n >= 5 && mad > 0 ? 0.6745 * deviations[i] / mad > 3.5 : false;
        if (relative || robustZ) outliers.add(i);
      }
    }

    final highCv = n >= 2 && cv != null && cv >= cvAcknowledgePercent;
    final highRange = n >= 2 &&
        ((ratio != null && ratio >= rangeRatioAcknowledge) || (minV == 0 && maxV > 0));
    final requiresAck = highCv || highRange;

    final warnings = <String>[];
    if (n == 1) warnings.add('Sample moja pekee: haiwezi kupima utofauti wa sampuli.');
    if (n == 2) warnings.add('Sampuli mbili pekee: ongeza duplicate/independent samples kabla ya hitimisho.');
    if (requiresAck) {
      warnings.add('Utofauti wa assay ni mkubwa (CV >= 20% au max/min >= 2); chunguza sampling, preparation na assay.');
    }
    if (outliers.isNotEmpty) warnings.add('Kuna matokeo yanayoweza kuwa outlier (kulinganisha na median); hakiki original certificates na repeat assay.');
    warnings.add('Takwimu hizi ni za kulinganisha tu; hazithibitishi representativeness ya loti.');
    return AssayAnalysis(
      count: n,
      meanGramsPerTonne: mean,
      medianGramsPerTonne: median,
      standardDeviation: sd,
      coefficientOfVariationPercent: cv,
      rangeRatio: ratio,
      outlierIndexes: outliers,
      requiresAcknowledgement: requiresAck,
      warnings: warnings,
    );
  }
}
