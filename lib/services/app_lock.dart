import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinResult {
  const PinResult({required this.ok, this.lockedSeconds = 0, this.storageError = false});
  final bool ok;
  final int lockedSeconds;

  /// Kweli pale hifadhi salama imeshindwa kusomwa/imeharibika. App hubaki
  /// imefungwa (fail-closed); haifunguki kwa kosa la hifadhi.
  final bool storageError;
}

/// PIN ya skrini ya app (si ufunguo wa encryption). Inazuia mtu anayeshika
/// simu iliyofunguliwa kuona rekodi; haibadilishi usalama wa database yenyewe.
/// PIN huhifadhiwa kama PBKDF2 hash; majaribio yakikosewa yanafungia kwa muda.
class AppLock {
  static const _storage = FlutterSecureStorage();
  static const _hashKey = 'madini_pin_hash_v1';
  static const _saltKey = 'madini_pin_salt_v1';
  static const _failKey = 'madini_pin_failures_v1';
  static const _lockKey = 'madini_pin_locked_until_v1';
  static const _markerKey = 'madini_pin_enabled_v1';
  static const _seenKey = 'madini_pin_last_seen_v1';
  static final _pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256);

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// Fail-closed: kosa lolote la kusoma hifadhi salama linamaanisha app
  /// ibaki imefungwa; haizimi PIN kimya kimya. PIN inahesabiwa kuwepo kama
  /// hash AU alama (marker) ipo.
  static Future<bool> refresh() async {
    try {
      final hash = await _storage.read(key: _hashKey);
      final marker = await _storage.read(key: _markerKey);
      enabled.value = hash != null || marker != null;
    } catch (_) {
      enabled.value = true;
    }
    return enabled.value;
  }

  static bool validPinFormat(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  static Future<String> _hash(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final bytes = await key.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<void> setPin(String pin) async {
    if (!validPinFormat(pin)) {
      throw ArgumentError('PIN lazima iwe tarakimu 6.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: await _hash(pin, salt));
    await _storage.write(key: _markerKey, value: '1');
    await _storage.delete(key: _failKey);
    await _storage.delete(key: _lockKey);
    enabled.value = true;
  }

  static Future<PinResult> verify(String pin) async {
    final String? storedHash;
    final String? saltText;
    final int lockedUntil;
    final int lastSeen;
    try {
      storedHash = await _storage.read(key: _hashKey);
      saltText = await _storage.read(key: _saltKey);
      lockedUntil = int.tryParse(await _storage.read(key: _lockKey) ?? '') ?? 0;
      lastSeen = int.tryParse(await _storage.read(key: _seenKey) ?? '') ?? 0;
    } catch (_) {
      return const PinResult(ok: false, storageError: true);
    }
    // Saa isirudishwe nyuma ili kufupisha kufungiwa (kusonga mbele hakuwezi
    // kugunduliwa offline; ni kikomo kinachojulikana).
    final wall = DateTime.now().millisecondsSinceEpoch;
    final now = wall < lastSeen ? lastSeen : wall;
    try {
      await _storage.write(key: _seenKey, value: '$now');
    } catch (_) {}
    if (lockedUntil > now) {
      return PinResult(ok: false, lockedSeconds: ((lockedUntil - now) / 1000).ceil());
    }
    if (storedHash == null || saltText == null) {
      // Hakuna PIN kweli (haikuwahi kuwekwa) -> ruhusu; alama ipo lakini hash
      // haipo -> hifadhi imeharibika -> usifungue.
      try {
        if (await _storage.read(key: _markerKey) != null) {
          return const PinResult(ok: false, storageError: true);
        }
      } catch (_) {
        return const PinResult(ok: false, storageError: true);
      }
      return const PinResult(ok: true);
    }
    final candidate = await _hash(pin, base64Decode(saltText));
    var diff = storedHash.length ^ candidate.length;
    for (var i = 0; i < storedHash.length && i < candidate.length; i++) {
      diff |= storedHash.codeUnitAt(i) ^ candidate.codeUnitAt(i);
    }
    if (diff == 0) {
      await _storage.delete(key: _failKey);
      await _storage.delete(key: _lockKey);
      return const PinResult(ok: true);
    }
    final failures = (int.tryParse(await _storage.read(key: _failKey) ?? '') ?? 0) + 1;
    await _storage.write(key: _failKey, value: '$failures');
    if (failures % 5 == 0) {
      final step = (failures ~/ 5) - 1;
      final seconds = min(3600, 30 * pow(2, step).toInt());
      await _storage.write(key: _lockKey, value: '${now + seconds * 1000}');
      return PinResult(ok: false, lockedSeconds: seconds);
    }
    return const PinResult(ok: false);
  }

  static Future<void> disable() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _failKey);
    await _storage.delete(key: _lockKey);
    await _storage.delete(key: _markerKey);
    await _storage.delete(key: _seenKey);
    enabled.value = false;
  }
}
