import 'dart:convert';

import 'package:cryptography/cryptography.dart';

enum SealStatus { valid, broken, missing }

/// Muhuri wa uadilifu (SHA-256) wa rekodi ya tathmini. Unagundua mabadiliko
/// yoyote ya `values`/`result`/toleo la formula yaliyofanyika baada ya kuhifadhi
/// (mf. kuhariri database nje ya app). Si ulinzi dhidi ya mtu mwenye ufikiaji
/// kamili wa kifaa (anaweza kuunda muhuri mpya); ni ushahidi wa mabadiliko ya
/// bahati mbaya au ya kawaida. Matokeo halisi (`actualOutcome`/`actualComparison`)
/// yanaongezwa baadaye kwa makusudi (pamoja na historia yao ya matoleo
/// `actualOutcomeHistory`), kwa hiyo hayamo kwenye muhuri. Historia hiyo
/// inalindwa na versioning ya application tu; si tamper-proof cryptographic log.
class IntegritySeal {
  static const String version = 'seal-v1';
  static const String resultKey = 'integritySeal';

  static Object? _canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _canon(v[k])};
    }
    if (v is List) return [for (final e in v) _canon(e)];
    return v;
  }

  static String canonicalText(
      Map<String, dynamic> values, Map<String, dynamic> result, String formulaVersion) {
    final v = Map<String, dynamic>.of(values)
      ..remove('actualOutcome')
      ..remove('actualOutcomeHistory');
    final r = Map<String, dynamic>.of(result)
      ..remove('actualComparison')
      ..remove(resultKey);
    return jsonEncode(_canon({'formulaVersion': formulaVersion, 'values': v, 'result': r}));
  }

  static Future<String> compute(
      Map<String, dynamic> values, Map<String, dynamic> result, String formulaVersion) async {
    final hash = await Sha256().hash(utf8.encode(canonicalText(values, result, formulaVersion)));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hurudisha `result` pamoja na muhuri.
  static Future<Map<String, dynamic>> seal(
      Map<String, dynamic> values, Map<String, dynamic> result, String formulaVersion) async {
    return {
      ...result,
      resultKey: {'version': version, 'sha256': await compute(values, result, formulaVersion)},
    };
  }

  static Future<SealStatus> verify(
      Map<String, dynamic> values, Map<String, dynamic> result, String formulaVersion) async {
    final stored = result[resultKey];
    if (stored is! Map || stored['sha256'] is! String) return SealStatus.missing;
    final fresh = await compute(values, result, formulaVersion);
    return fresh == stored['sha256'] ? SealStatus.valid : SealStatus.broken;
  }
}
