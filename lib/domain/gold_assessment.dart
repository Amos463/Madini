import 'dart:convert';

class GoldAssessment {
  GoldAssessment({
    required this.id,
    required this.title,
    required this.mode,
    required this.assessmentType,
    required this.createdAt,
    required this.formulaVersion,
    required this.values,
    required this.result,
    required this.notes,
  });

  final String id;
  final String title;
  final String mode;
  final String assessmentType;
  final DateTime createdAt;
  final String formulaVersion;
  final Map<String, dynamic> values;
  final Map<String, dynamic> result;
  final String notes;

  /// Muundo wa kubebeka (backup/legacy): funguo `values` na `result`.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'mode': mode,
        'assessmentType': assessmentType,
        'createdAt': createdAt.toIso8601String(),
        'formulaVersion': formulaVersion,
        'values': jsonEncode(values),
        'result': jsonEncode(result),
        'notes': notes,
      };

  /// Muundo wa database. `values` ni neno lililohifadhiwa la SQL, hivyo safu
  /// inaitwa `values_json`.
  Map<String, Object?> toDbMap() => {
        'id': id,
        'title': title,
        'mode': mode,
        'assessmentType': assessmentType,
        'createdAt': createdAt.toIso8601String(),
        'formulaVersion': formulaVersion,
        'values_json': jsonEncode(values),
        'result': jsonEncode(result),
        'notes': notes,
      };

  /// Inakubali safu `values_json` (database mpya) au `values` (legacy/backup).
  static GoldAssessment fromMap(Map<String, dynamic> map) {
    final rawValues = (map['values_json'] ?? map['values']) as String? ?? '{}';
    return GoldAssessment(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Assessment',
      mode: map['mode'] as String? ?? 'laboratory',
      assessmentType: map['assessmentType'] as String? ?? 'laboratory',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      formulaVersion: map['formulaVersion'] as String? ?? 'v1.0',
      values: jsonDecode(rawValues) as Map<String, dynamic>,
      result: jsonDecode(map['result'] as String? ?? '{}') as Map<String, dynamic>,
      notes: map['notes'] as String? ?? '',
    );
  }

  bool get isField => mode == 'field' || result['valuationAvailable'] == false;

  double? get maximumBid {
    final v = result['maximumBid'];
    return v is num ? v.toDouble() : null;
  }
}
