import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Chagua maandishi ya Kiswahili au Kiingereza kulingana na lugha ya app.
bool isSw(BuildContext context) => Localizations.localeOf(context).languageCode == 'sw';

String tr(BuildContext context, String sw, String en) => isSw(context) ? sw : en;

final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _grams = NumberFormat('#,##0.0000', 'en_US');

String formatMoney(num value) => _money.format(value);
String formatGrams(num value) => _grams.format(value);

/// Husoma namba ya mtumiaji kwa usalama wa fedha.
///
/// Kanuni (ili "500,000" isisomwe kimakosa kama 500):
/// * nukta = desimali (`3.5`); koma nyingi = maelfu (`1,500,000`);
/// * koma moja yenye tarakimu 1-2 au zaidi ya 3 baada yake = desimali (`3,5`);
/// * koma moja yenye tarakimu TATU hasa baada yake (`1,250`) ina utata
///   (1.25 au 1250?) -> inakataliwa (null); tumia `1250` au `1.25`;
/// * mchanganyiko `1,234.5` / `1.234,5` unakubaliwa tu ukiwa na mpangilio sahihi.
/// Hurudisha null kwa chochote kisicho wazi; usibahatishe thamani ya fedha.
double? parseNum(String? raw) {
  if (raw == null) return null;
  final text = raw.trim().replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty) return null;
  if (!RegExp(r'^-?[0-9.,]+$').hasMatch(text)) return null;
  final negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;
  if (body.isEmpty || body == '.' || body == ',') return null;
  final commas = ','.allMatches(body).length;
  final dots = '.'.allMatches(body).length;
  String normalized;
  if (commas == 0 && dots == 0) {
    normalized = body;
  } else if (commas == 0) {
    if (dots > 1) return null;
    normalized = body;
  } else if (dots == 0) {
    if (commas == 1) {
      final parts = body.split(',');
      final before = parts[0];
      final after = parts[1];
      if (before.isEmpty || after.isEmpty) return null;
      if (after.length == 3 && before.length <= 3) return null; // utata: 1,250
      normalized = '$before.$after';
    } else {
      if (!RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(body)) return null;
      normalized = body.replaceAll(',', '');
    }
  } else {
    final lastComma = body.lastIndexOf(',');
    final lastDot = body.lastIndexOf('.');
    if (lastDot > lastComma) {
      // 1,234,567.89
      if (dots != 1) return null;
      final intPart = body.substring(0, lastDot);
      if (!RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(intPart)) return null;
      normalized = '${intPart.replaceAll(',', '')}.${body.substring(lastDot + 1)}';
    } else {
      // 1.234.567,89
      if (commas != 1) return null;
      final intPart = body.substring(0, lastComma);
      if (!RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(intPart)) return null;
      normalized = '${intPart.replaceAll('.', '')}.${body.substring(lastComma + 1)}';
    }
  }
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return negative ? -value : value;
}

/// Kweli kama ingizo lina utata wa koma (mf. "1,250") ambalo [parseNum]
/// linakataa kwa makusudi; hutumika kuonyesha ujumbe unaoeleweka.
bool isAmbiguousNumber(String? raw) {
  if (raw == null) return false;
  final t = raw.trim().replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^-?\d{1,3},\d{3}$').hasMatch(t);
}

/// Hutenganisha grades kwa `;` au nafasi/mstari mpya. Koma haitumiki kama
/// kitenganishi ili isichanganywe na desimali.
List<double>? parseGradeList(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <double>[];
  final parts = raw.split(RegExp(r'[;\s]+')).where((p) => p.isNotEmpty);
  final out = <double>[];
  for (final part in parts) {
    final v = parseNum(part);
    if (v == null || v < 0) return null;
    out.add(v);
  }
  return out;
}

String modeLabel(BuildContext context, String mode) {
  switch (mode) {
    case 'field':
      return tr(context, 'Uga (screening)', 'Field (screening)');
    case 'dore':
      return tr(context, 'Doré / dhahabu', 'Doré / gold');
    default:
      return tr(context, 'Maabara', 'Laboratory');
  }
}

String dateOnly(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

/// Sehemu (0.085) -> "8.5%" bila sufuri zisizo na maana.
String formatFractionAsPercent(num fraction) => formatPercentValue(fraction * 100);

String formatPercentValue(num percent) {
  var s = percent.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return '$s%';
}
