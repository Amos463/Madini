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

  Map<String, dynamic> toMap() {
    return {
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
  }

  static GoldAssessment fromMap(Map<String, dynamic> map) {
    return GoldAssessment(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Assessment',
      mode: map['mode'] as String? ?? 'lab',
      assessmentType: map['assessmentType'] as String? ?? 'lab',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      formulaVersion: map['formulaVersion'] as String? ?? 'v1.0',
      values: jsonDecode(map['values'] as String? ?? '{}') as Map<String, dynamic>,
      result: jsonDecode(map['result'] as String? ?? '{}') as Map<String, dynamic>,
      notes: map['notes'] as String? ?? '',
    );
  }
}
