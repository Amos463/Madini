import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../domain/assessment_summary.dart';
import '../domain/gold_assessment.dart';
import 'temp_files.dart';

/// Huunda na kushiriki ripoti ya PDF. Fonti ya default ya PDF haina glyph za
/// Unicode nje ya Latin-1, kwa hiyo maandishi yote yanapitishwa `pdfSafe`.
class ReportService {
  static String pdfSafe(Object? input) {
    var s = (input ?? '').toString();
    const map = {
      '\u2014': '-', '\u2013': '-', '\u2212': '-', '\u2265': '>=', '\u2264': '<=',
      '\u2018': "'", '\u2019': "'", '\u201C': '"', '\u201D': '"', '\u2022': '-',
      '\u2026': '...',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    final out = StringBuffer();
    for (final unit in s.runes) {
      out.writeCharCode(unit <= 0xFF ? unit : 0x3F); // '?'
    }
    return out.toString();
  }

  static pw.Widget _line(String sw, String en, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 210,
                child: pw.Text(pdfSafe(sw == en ? sw : '$sw / $en'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text(pdfSafe(value))),
          ],
        ),
      );

  static pw.Widget _h(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Text(pdfSafe(text), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );

  /// Ripoti inasoma muhtasari ule ule wa ukurasa wa historia
  /// (`AssessmentSummary`); haikokotoi chochote chenyewe.
  static Future<Uint8List> build(GoldAssessment a) async {
    final pdf = pw.Document();
    final widgets = <pw.Widget>[
      pw.Text('MADINI - Ripoti ya Tathmini / Assessment Report',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
    ];
    for (final section in AssessmentSummary.build(a)) {
      widgets.add(_h(section.sw == section.en ? section.sw : '${section.sw} / ${section.en}'));
      for (final row in section.rows) {
        widgets.add(_line(row.sw, row.en, row.value));
      }
      for (final note in section.notes) {
        widgets.add(pw.Bullet(text: pdfSafe(note)));
      }
    }
    widgets.addAll([
      _h('Kanusho / Disclaimer'),
      pw.Text(pdfSafe(AssessmentSummary.disclaimerSw)),
      pw.SizedBox(height: 4),
      pw.Text(pdfSafe(AssessmentSummary.disclaimerEn)),
    ]);

    pdf.addPage(pw.MultiPage(build: (context) => widgets));
    return pdf.save();
  }

  static Future<void> share(GoldAssessment a) async {
    await TempFiles.shareBytes(await build(a), '${a.id}.pdf');
  }
}
