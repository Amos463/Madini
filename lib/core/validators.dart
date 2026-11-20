import 'package:flutter/widgets.dart';

import 'format.dart';

String? Function(String?) numValidator(BuildContext c,
    {bool required = true, double? min, double? max, bool positive = false}) {
  return (String? v) {
    final raw = v?.trim() ?? '';
    if (raw.isEmpty) return required ? tr(c, 'Inahitajika', 'Required') : null;
    final n = parseNum(raw);
    if (n == null) {
      return isAmbiguousNumber(raw)
          ? tr(c, 'Koma ina utata (1,250?). Andika 1250 au 1.25; maelfu: 1,250,000.',
              'Ambiguous comma (1,250?). Type 1250 or 1.25; thousands: 1,250,000.')
          : tr(c, 'Weka namba sahihi', 'Enter a valid number');
    }
    if (positive && n <= 0) return tr(c, 'Lazima iwe zaidi ya 0', 'Must be greater than 0');
    if (min != null && n < min) return tr(c, 'Chini ya $min hairuhusiwi', 'Must be at least $min');
    if (max != null && n > max) return tr(c, 'Zaidi ya $max hairuhusiwi', 'Must be at most $max');
    return null;
  };
}
