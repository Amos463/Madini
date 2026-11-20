import 'package:shared_preferences/shared_preferences.dart';

/// Kikumbusho cha backup: data ikipotea (simu kubadilishwa/kuibiwa/Keystore
/// kufutwa) hakuna njia ya kuirudisha bila backup ya .mdbak.
class BackupReminder {
  static const _key = 'madini_last_backup_at_v1';
  static const interval = Duration(days: 14);

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> last() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    return text == null ? null : DateTime.tryParse(text);
  }

  /// Kweli kama kuna rekodi na backup haijafanywa ndani ya [interval].
  static Future<bool> isDue(int recordCount) async {
    if (recordCount <= 0) return false;
    final at = await last();
    return at == null || DateTime.now().difference(at) > interval;
  }
}
