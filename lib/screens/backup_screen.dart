import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../storage.dart';
import '../date_utils.dart';
import '../widgets/desktop_widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _storage = AppStorage();
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final bundle = await _storage.buildBackupBundle();
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle)));
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'محل ذخیره فایل پشتیبان را انتخاب کنید',
        fileName: 'backup_$stamp.kabackup',
        type: FileType.custom,
        allowedExtensions: ['kabackup'],
        bytes: bytes,
      );
      if (path != null) {
        // در ویندوز ممکن است file_picker خودش محتوا را ننویسد؛ نوشتن مجدد بی‌خطر است.
        try {
          await File(path).writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پشتیبان‌گیری با موفقیت انجام شد.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در پشتیبان‌گیری: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('بازیابی پشتیبان'),
        content: const Text('بازیابی اطلاعات، حساب‌ها و اسناد فعلی را با اطلاعات فایل پشتیبان جایگزین می‌کند. ادامه می‌دهید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('بازیابی')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['kabackup', 'json'], withData: true);
      if (result == null || result.files.single.bytes == null) return;
      final bundle = jsonDecode(utf8.decode(result.files.single.bytes!)) as Map<String, dynamic>;
      await _storage.restoreBackupBundle(bundle);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بازیابی انجام شد؛ برای بارگذاری کامل اطلاعات برنامه را دوباره اجرا کنید.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فایل پشتیبان معتبر نیست: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'پشتیبان‌گیری و بازیابی', icon: Icons.backup_outlined),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD5DEDA))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('پشتیبان کامل اطلاعات حسابداری', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('فایل پشتیبان شامل حساب‌های کل، معین و تفصیلی، همه اسناد حسابداری، دریافت‌ها و پرداخت‌ها و ساختار قابل توسعه برای مدارک مالی آینده است.'),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: _busy ? null : _backup, icon: const Icon(Icons.backup_outlined), label: const Text('ایجاد فایل پشتیبان'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.restore), label: const Text('بازیابی فایل پشتیبان'))),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Card(child: ListTile(leading: const Icon(Icons.security_outlined), title: const Text('فرمت پشتیبان'), subtitle: Text('KABACKUP • نسخه‌دار • تاریخ ایجاد: ${toPersianDigits(DateTime.now().toString().substring(0, 10))}'))),
        ],
      ),
            ),
          ),
        ),
      ],
    );
  }
}
