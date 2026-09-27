import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../widgets/desktop_widgets.dart';

/// پیش‌نمایش گزارش (شبیه Print Preview نرم‌افزارهای حسابداری) با دکمه‌های
/// «چاپ روی کاغذ» و «ذخیره PDF».
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildPdf,
  });

  final String title;
  final String fileName;
  final Future<Uint8List> Function() buildPdf;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final b = await widget.buildPdf();
      if (mounted) setState(() => _bytes = b);
    } catch (e) {
      if (mounted) setState(() => _error = 'خطا در ساخت فایل PDF: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: widget.fileName);
    } catch (e) {
      _snack('چاپ انجام نشد: $e');
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'محل ذخیره فایل PDF را انتخاب کنید',
        fileName: '${widget.fileName}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (path == null) return;
      final out = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
      await File(out).writeAsBytes(bytes, flush: true);
      _snack('فایل PDF ذخیره شد.');
    } catch (e) {
      _snack('ذخیره فایل انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;
    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: widget.title,
            subtitle: 'پیش‌نمایش چاپ',
            icon: Icons.picture_as_pdf_outlined,
            actions: [
              ToolbarButton(label: 'چاپ روی کاغذ', icon: Icons.print_outlined, primary: true, onPressed: ready ? _print : null),
              ToolbarButton(label: 'ذخیره PDF', icon: Icons.save_alt_rounded, onPressed: ready ? _save : null),
              ToolbarButton(label: 'بستن', icon: Icons.close_rounded, onPressed: () => Navigator.maybePop(context)),
            ],
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : !ready
                    ? const Center(child: CircularProgressIndicator())
                    : PdfPreview(
                        build: (format) async => _bytes!,
                        allowPrinting: false,
                        allowSharing: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        useActions: false,
                        pdfFileName: '${widget.fileName}.pdf',
                      ),
          ),
        ],
      ),
    );
  }
}
