import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'date_utils.dart';
import 'report_engine.dart';

/// تولید PDF حرفه‌ای و استاندارد گزارش‌های مالی:
/// سربرگ با لوگو و نام فروشگاه، عنوان گزارش، مشخصات دوره، جدول با تکرار سربرگ
/// ستون‌ها در هر صفحه، ردیف‌های جمع، شماره صفحه و بخش امضا.
class ReportPdf {
  static Uint8List? _logoCache;

  static final _green = PdfColor.fromInt(0xFF185C3A);
  static final _gold = PdfColor.fromInt(0xFFD6B65A);
  static final _tint = PdfColor.fromInt(0xFFE3EEE8);
  static final _soft = PdfColor.fromInt(0xFFF2F7F4);
  static final _line = PdfColor.fromInt(0xFFCBD5D0);

  /// لوگو را کوچک‌سازی می‌کند تا حجم فایل PDF زیاد نشود.
  static Future<Uint8List?> _loadLogo() async {
    if (_logoCache != null) return _logoCache;
    try {
      final raw = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
      try {
        final codec = await ui.instantiateImageCodec(raw, targetWidth: 240, targetHeight: 240);
        final frame = await codec.getNextFrame();
        final bd = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (bd != null) {
          _logoCache = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
          return _logoCache;
        }
      } catch (_) {}
      _logoCache = raw;
      return raw;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> build(
    ReportData data, {
    required String storeName,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazir.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazir-Bold.ttf'));
    final logoBytes = await _loadLogo();
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);

    pw.TextStyle st(double size, {bool isBold = false, PdfColor color = PdfColors.black}) =>
        pw.TextStyle(font: isBold ? bold : regular, fontSize: size, color: color);

    pw.Widget txt(String s, double size,
        {bool isBold = false, PdfColor color = PdfColors.black, pw.TextAlign align = pw.TextAlign.right}) {
      return pw.Text(
        s,
        textDirection: pw.TextDirection.rtl,
        textAlign: align,
        style: st(size, isBold: isBold, color: color),
      );
    }

    // ردیف با چیدمان فیزیکی چپ‌به‌راست؛ ستون اول منطقی (راست‌ترین) در انتهای لیست قرار می‌گیرد.
    pw.Widget physicalRow(List<pw.Widget> logicalCells, List<int> flexes) {
      final children = <pw.Widget>[];
      for (var i = logicalCells.length - 1; i >= 0; i--) {
        children.add(pw.Expanded(flex: flexes[i], child: logicalCells[i]));
      }
      return pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Row(children: children),
      );
    }

    final flexes = data.columns.map((c) => c.flex).toList();

    pw.Widget cell(String s, ReportColumn col,
        {bool isBold = false, PdfColor color = PdfColors.black, double size = 9, double indent = 0}) {
      return pw.Container(
        alignment: col.numeric ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        padding: pw.EdgeInsets.fromLTRB(5, 4, 5 + indent, 4),
        child: txt(s, size, isBold: isBold, color: color, align: col.numeric ? pw.TextAlign.left : pw.TextAlign.right),
      );
    }

    pw.Widget tableHeader() {
      return pw.Container(
        color: _green,
        child: physicalRow([
          for (final c in data.columns)
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: txt(c.title, 9, isBold: true, color: PdfColors.white, align: pw.TextAlign.center),
            ),
        ], flexes),
      );
    }

    pw.Widget dataRow(ReportRow r, int index) {
      if (r.kind == RowKind.section) {
        return pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Container(
                color: _tint,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                alignment: pw.Alignment.centerRight,
                child: txt(r.cells.isEmpty ? '' : r.cells.first, 10, isBold: true, color: _green),
              ),
            ),
          ]),
        );
      }
      final isTotal = r.kind == RowKind.total;
      final isGroup = r.kind == RowKind.group;
      final strong = isTotal || isGroup;
      final bg = isTotal ? _tint : (isGroup ? _soft : (index.isOdd ? PdfColor.fromInt(0xFFFAFBFA) : PdfColors.white));
      final body = pw.Container(
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.4)),
        ),
        child: physicalRow([
          for (var i = 0; i < data.columns.length; i++)
            cell(
              i < r.cells.length ? r.cells[i] : '',
              data.columns[i],
              isBold: strong,
              indent: i == data.nameColumn ? r.depth * 12.0 : 0,
            ),
        ], flexes),
      );
      if (!isTotal) return body;
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [pw.Container(height: 1, color: _green), body],
      );
    }

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final printedAt = '${toPersianDigits(todayJalali())}  ${toPersianDigits('${two(now.hour)}:${two(now.minute)}')}';

    pw.Widget brandHeader(pw.Context ctx) {
      final brand = pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              txt(storeName, 12, isBold: true, color: _green),
              pw.SizedBox(height: 2),
              txt('سیستم حسابداری فروشگاه', 8, color: PdfColors.grey700),
            ],
          ),
          if (logo != null) ...[
            pw.SizedBox(width: 8),
            pw.Container(width: 44, height: 44, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          ],
        ],
      );
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      txt('تاریخ چاپ: $printedAt', 8, color: PdfColors.grey700, align: pw.TextAlign.left),
                      pw.SizedBox(height: 2),
                      txt('صفحه ${toPersianDigits('${ctx.pageNumber}')} از ${toPersianDigits('${ctx.pagesCount}')}', 8,
                          color: PdfColors.grey700, align: pw.TextAlign.left),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: pw.Center(child: txt(data.title, 16, isBold: true, align: pw.TextAlign.center)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Align(alignment: pw.Alignment.centerRight, child: brand),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: _green),
          pw.Container(height: 1, margin: const pw.EdgeInsets.only(top: 1.5), color: _gold),
          pw.SizedBox(height: 8),
          if (ctx.pageNumber > 1) tableHeader(),
        ],
      );
    }

    pw.Widget footer(pw.Context ctx) {
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(height: 0.6, color: PdfColors.grey500),
          pw.SizedBox(height: 4),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                txt('${toPersianDigits('${ctx.pageNumber}')} / ${toPersianDigits('${ctx.pagesCount}')}', 8,
                    color: PdfColors.grey700, align: pw.TextAlign.left),
                txt('$storeName — ${data.title}', 8, color: PdfColors.grey700),
              ],
            ),
          ),
        ],
      );
    }

    pw.Widget metaBox() {
      if (data.meta.isEmpty) return pw.SizedBox();
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _soft,
          border: pw.Border.all(color: _line, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (final e in data.meta)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: txt('${e.key}: ${e.value}', 9),
              ),
          ],
        ),
      );
    }

    pw.Widget signatures() {
      pw.Widget box(String label) => pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              txt(label, 9, isBold: true, align: pw.TextAlign.center),
              pw.SizedBox(height: 34),
              pw.Container(height: 0.6, margin: const pw.EdgeInsets.symmetric(horizontal: 14), color: PdfColors.grey600),
              pw.SizedBox(height: 3),
              txt('نام و امضا', 7.5, color: PdfColors.grey600, align: pw.TextAlign.center),
            ],
          );
      return pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Row(
          children: [
            pw.Expanded(child: box('مدیر / مدیرعامل')),
            pw.Expanded(child: box('حسابدار')),
            pw.Expanded(child: box('تهیه‌کننده')),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: brandHeader,
        footer: footer,
        build: (ctx) => [
          metaBox(),
          pw.SizedBox(height: 10),
          tableHeader(),
          for (var i = 0; i < data.rows.length; i++) dataRow(data.rows[i], i),
          if (data.status != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(
                color: data.statusOk ? _soft : PdfColor.fromInt(0xFFFDECEA),
                border: pw.Border.all(color: data.statusOk ? _green : PdfColors.red700, width: 0.8),
              ),
              child: txt(
                data.status!,
                9.5,
                isBold: true,
                color: data.statusOk ? _green : PdfColors.red700,
              ),
            ),
          ],
          pw.SizedBox(height: 30),
          signatures(),
        ],
      ),
    );
    return doc.save();
  }
}
