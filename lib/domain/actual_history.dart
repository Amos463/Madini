/// Matokeo halisi yanahifadhiwa kwa MATOLEO: marekebisho hayafuti thamani ya
/// zamani; yanaihamishia kwenye `actualOutcomeHistory` (append-only) pamoja na
/// sababu ya marekebisho na wakati. Hii ni append-only kwa mtiririko wa app,
/// si muhuri wa kriptografia: mtumiaji mwenye uwezo wa kubadilisha database
/// anaweza kuhariri historia. Uadilifu wake unahitaji ukaguzi wa audit huru.
class VersionedActual {
  const VersionedActual(this.values, this.result, this.version);
  final Map<String, dynamic> values;
  final Map<String, dynamic> result;
  final int version;
}

class ActualOutcomeVersioning {
  static const String historyKey = 'actualOutcomeHistory';

  static List<Map<String, dynamic>> history(Map<String, dynamic> values) {
    final raw = values[historyKey];
    if (raw == null) return <Map<String, dynamic>>[];
    if (raw is! List) {
      throw const FormatException('Historia ya matokeo halisi imeharibika.');
    }
    final out = <Map<String, dynamic>>[];
    final seenVersions = <int>{};
    for (final entry in raw) {
      if (entry is! Map) {
        throw const FormatException('Kuna kipengele kisicho sahihi kwenye historia ya matokeo.');
      }
      final item = Map<String, dynamic>.from(entry);
      final version = item['version'];
      if (version is! int || version < 1 || !seenVersions.add(version)) {
        throw const FormatException('Namba za matoleo ya historia si sahihi au zinajirudia.');
      }
      out.add(item);
    }
    return out;
  }

  /// Hutumia matokeo mapya kwenye rekodi. Kama kuna matokeo ya awali,
  /// [correctionReason] inahitajika na toleo la awali linahifadhiwa.
  static VersionedActual apply({
    required Map<String, dynamic> values,
    required Map<String, dynamic> result,
    required Map<String, dynamic> newOutcome,
    required Map<String, dynamic> newComparison,
    required String nowIso,
    String? correctionReason,
    bool needsReview = false,
  }) {
    final prev = values['actualOutcome'];
    final hist = history(values);
    final maxHistoryVersion = hist.fold<int>(
        0, (current, item) => (item['version'] as int) > current ? item['version'] as int : current);
    var maxVersion = maxHistoryVersion;
    if (prev != null && prev is! Map) {
      throw const FormatException('Matokeo halisi yaliyopo yana muundo usiotambulika.');
    }
    if (prev is Map && prev['version'] != null) {
      final previousVersion = prev['version'];
      if (previousVersion is! int || previousVersion < 1) {
        throw const FormatException('Namba ya toleo la matokeo yaliyopo si sahihi.');
      }
      if (previousVersion <= maxHistoryVersion) {
        throw const FormatException('Toleo la sasa lazima liwe kubwa kuliko matoleo yote yaliyohifadhiwa kwenye historia.');
      }
      if (previousVersion > maxVersion) maxVersion = previousVersion;
    }
    String? reason;
    if (prev is Map) {
      reason = correctionReason?.trim();
      if (reason == null || reason.isEmpty) {
        throw ArgumentError('Sababu ya marekebisho inahitajika kabla ya kubadilisha matokeo halisi yaliyopo.');
      }
      final prevVersion = prev['version'] is int ? prev['version'] as int : maxVersion + 1;
      if (hist.any((entry) => entry['version'] == prevVersion)) {
        throw const FormatException('Toleo la matokeo yaliyopo tayari limo kwenye historia.');
      }
      if (prevVersion > maxVersion) maxVersion = prevVersion;
      hist.add({
        'version': prevVersion,
        'outcome': Map<String, dynamic>.from(prev),
        'comparison': result['actualComparison'],
        'supersededAt': nowIso,
        'correctionReason': reason,
      });
    }
    final version = (hist.isEmpty ? maxVersion : hist.fold<int>(
        maxVersion, (current, item) => (item['version'] as int) > current ? item['version'] as int : current)) + 1;
    final newValues = <String, dynamic>{
      ...values,
      'actualOutcome': {
        ...newOutcome,
        'version': version,
        'needsReview': needsReview,
        if (reason != null) 'correctionReason': reason,
      },
      historyKey: hist,
    };
    final newResult = <String, dynamic>{...result, 'actualComparison': newComparison};
    return VersionedActual(newValues, newResult, version);
  }
}
