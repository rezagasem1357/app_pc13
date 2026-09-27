import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../amount_format.dart';
import '../date_utils.dart';
import '../models.dart';
import '../storage.dart';
import '../widgets/desktop_widgets.dart';
import 'voucher_entry_screen.dart';

class VoucherListScreen extends StatefulWidget {
  const VoucherListScreen({super.key});

  @override
  State<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends State<VoucherListScreen> {
  final _storage = AppStorage();
  List<Voucher> _vouchers = [];
  Map<String, int> _dailyNumbers = {};
  bool _loading = true;
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _storage.loadVouchers();
    list.sort((a, b) {
      final byDate = compareJalaliDates(a.date, b.date);
      if (byDate != 0) return byDate;
      return a.number.compareTo(b.number);
    });
    if (!mounted) return;
    setState(() {
      _vouchers = list;
      _dailyNumbers = computeDailyNumbers(list);
      _loading = false;
    });
  }

  List<Voucher> get _filtered {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty && to.isEmpty) return _vouchers;
    return _vouchers.where((v) {
      if (from.isNotEmpty && compareJalaliDates(v.date, from) < 0) return false;
      if (to.isNotEmpty && compareJalaliDates(v.date, to) > 0) return false;
      return true;
    }).toList();
  }

  Future<void> _openVoucher([Voucher? v]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => VoucherEntryScreen(existing: v)),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteVoucher(Voucher v) async {
    if (v.status == VoucherStatus.permanent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سند دائم قابل حذف نیست.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف سند شماره ${toPersianDigits(v.number.toString())}'),
        content: const Text('این سند موقت حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final list = await _storage.loadVouchers();
    list.removeWhere((x) => x.id == v.id);
    await _storage.saveVouchers(renumberVouchersByDate(list));
    _load();
  }

  Future<void> _convertToTemporary(Voucher v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تبدیل سند دائم به موقت'),
        content: Text(
          'سند شماره ${toPersianDigits(v.number.toString())} به وضعیت «موقت» بازمی‌گردد تا بتوانید آن را ویرایش یا حذف کنید. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تبدیل به موقت')),
        ],
      ),
    );
    if (ok != true) return;
    final list = await _storage.loadVouchers();
    final i = list.indexWhere((x) => x.id == v.id);
    if (i >= 0) {
      list[i].status = VoucherStatus.temporary;
      await _storage.saveVouchers(list);
    }
    _load();
  }

  Widget _dateField(String label, TextEditingController c) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: c,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        decoration: InputDecoration(labelText: label, hintText: '1405/01/01'),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _loading ? <Voucher>[] : _filtered;
    var sum = 0;
    for (final v in items) {
      sum += v.totalDebit;
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () => _openVoucher(),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'اسناد حسابداری',
              icon: Icons.receipt_long_rounded,
              actions: [
                ToolbarButton(label: 'سند جدید  (F2)', icon: Icons.add, primary: true, onPressed: () => _openVoucher()),
              ],
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Panel(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt_outlined, size: 18, color: Colors.black45),
                            const SizedBox(width: 8),
                            _dateField('از تاریخ', _fromCtrl),
                            const SizedBox(width: 10),
                            _dateField('تا تاریخ', _toCtrl),
                            const SizedBox(width: 6),
                            iconAction(
                              icon: Icons.clear,
                              tooltip: 'پاک‌کردن فیلتر',
                              onPressed: () {
                                _fromCtrl.clear();
                                _toCtrl.clear();
                                setState(() {});
                              },
                            ),
                            const Spacer(),
                            Text('تعداد اسناد: ${toPersianDigits(items.length.toString())}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Panel(
                          child: DataGridView(
                            columns: const [
                              GridCol('شماره', width: 70),
                              GridCol('شماره روزانه', width: 90),
                              GridCol('تاریخ', width: 100),
                              GridCol('نوع سند', width: 90),
                              GridCol('وضعیت', width: 90),
                              GridCol('مرجع', flex: 2),
                              GridCol('شرح سند', flex: 4),
                              GridCol('مبلغ (ریال)', flex: 2, numeric: true),
                              GridCol('', width: 40),
                            ],
                            rowCount: items.length,
                            onRowTap: (i) => _openVoucher(items[i]),
                            emptyText: 'سندی برای نمایش وجود ندارد.',
                            cellBuilder: (i) {
                              final v = items[i];
                              final permanent = v.status == VoucherStatus.permanent;
                              return [
                                gridText(toPersianDigits(v.number.toString()), bold: true),
                                gridText(toPersianDigits((_dailyNumbers[v.id] ?? 1).toString())),
                                gridText(toPersianDigits(v.date)),
                                gridText(voucherTypeLabel(v.type)),
                                statusChip(permanent ? 'دائم' : 'موقت', permanent ? const Color(0xFF137A4B) : const Color(0xFFC77700)),
                                gridText(v.reference.isEmpty ? '-' : v.reference),
                                gridText(v.description.isEmpty ? '(بدون شرح)' : v.description),
                                gridText(moneyFa(v.totalDebit), bold: true),
                                permanent
                                    ? iconAction(
                                        icon: Icons.lock_open_outlined,
                                        tooltip: 'تبدیل به موقت (برای ویرایش یا حذف)',
                                        onPressed: () => _convertToTemporary(v),
                                      )
                                    : iconAction(
                                        icon: Icons.delete_outline,
                                        tooltip: 'حذف سند موقت',
                                        color: Colors.red.shade400,
                                        onPressed: () => _deleteVoucher(v),
                                      ),
                              ];
                            },
                            footer: [
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              gridText('جمع مبالغ اسناد', bold: true),
                              gridText(moneyFa(sum), bold: true),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
