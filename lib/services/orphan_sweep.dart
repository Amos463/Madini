/// Mpango wa kufuta faili za vyeti yatima. Kazi safi (bila IO) ili ijaribiwe.
///
/// Sheria za usalama (cheti halali kisifutwe kamwe kwa makosa):
///  - Linganisha kwa JINA la faili (si njia nzima): njia ya saraka ikitofautiana
///    kidogo, faili halali halionekani yatima.
///  - Faili ni yatima tu kama jina lake halipo kwenye database, linaishia
///    `.mcert`, na limebadilishwa mara ya mwisho zaidi ya [minAge].
///  - Kinga: kama zaidi ya nusu ya mafaili (na yapo 5+) yangefutwa, mpango
///    unafutwa wote (hali ya kutiliwa shaka: huenda database/njia ina tatizo).
class OrphanSweep {
  static const Duration minAge = Duration(hours: 24);

  static String baseName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  /// [files]: jina/njia ya faili -> wakati wa mwisho wa kubadilishwa.
  /// [knownPaths]: njia (au majina) ya vyeti vilivyomo kwenye database.
  /// Hurudisha orodha ya njia za kufutwa.
  static List<String> plan({
    required Map<String, DateTime> files,
    required Iterable<String> knownPaths,
    required DateTime now,
  }) {
    final known = {for (final p in knownPaths) baseName(p)};
    final cutoff = now.subtract(minAge);
    final candidates = <String>[];
    for (final entry in files.entries) {
      final name = baseName(entry.key);
      if (!name.endsWith('.mcert')) continue;
      if (known.contains(name)) continue;
      if (!entry.value.isBefore(cutoff)) continue;
      candidates.add(entry.key);
    }
    final total = files.keys.where((p) => baseName(p).endsWith('.mcert')).length;
    if (total >= 5 && candidates.length * 2 > total) return <String>[];
    return candidates;
  }
}
