import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Faili za muda za kushiriki (vyeti vilivyosimbuliwa, PDF, backup) huwekwa
/// kwenye saraka moja maalum na hufutwa: kila app inapoanza, kila app
/// inapojifunga, na kabla ya kushiriki kipya (faili zaidi ya dakika 10).
/// Hazifutwi mara tu baada ya Share kwa sababu app inayopokea inaweza kuwa
/// bado inasoma faili.
class TempFiles {
  static Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/madini_share');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  /// Futa faili za muda zilizo za zamani kuliko [olderThan] (Duration.zero = zote).
  static Future<void> cleanup({Duration olderThan = Duration.zero}) async {
    try {
      final dir = await _dir();
      final cutoff = DateTime.now().subtract(olderThan);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          if (olderThan == Duration.zero || (await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> shareBytes(Uint8List bytes, String fileName, {String? text}) async {
    await cleanup(olderThan: const Duration(minutes: 10));
    final dir = await _dir();
    final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${safeName(fileName)}');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }
}
