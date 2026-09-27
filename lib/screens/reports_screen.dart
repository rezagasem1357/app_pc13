import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../date_utils.dart';
import '../models.dart';
import '../report_engine.dart';
import '../report_pdf.dart';
import '../storage.dart';
import '../widgets/desktop_widgets.dart';
import '../widgets/report_grid.dart';
import 'pdf_preview_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _storage = AppStorage();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  List<AccountNode> _accounts = [];
  List<Voucher> _vouchers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await _storage.loadAccounts();
    final vouchers = await _storage.loadVouchers();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _vouchers = vouchers;
      _loading = false;
    });
  }

  ReportEngine get _engine => ReportEngine(
        accounts: _accounts,
        vouchers: _vouchers,
        from: _fromCtrl.text,
        to: _toCtrl.text,
      );

  ReportData _dataFor(int tab) {
    final e = _engine;
    switch (tab) {
      case 0:
        return e.trialBalance();
      case 1:
        return e.balanceSheet();
      default:
        return e.incomeStatement();
    }
  }

  String get _fileBase {
    const names = ['trial_balance', 'balance_sheet', 'income_statement'];
    return '${names[_tabs.index]}_${todayJalali().replaceAll('/', '-')}';
  }

  Future<void> _preview() async {
    final data = _dataFor(_tabs.index);
    final store = await _storage.loadStoreName();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: data.title,
          fileName: _fileBase,
          buildPdf: () => ReportPdf.build(data, storeName: store),
        ),
      ),
    );
  }

  Future<void> _printNow() async {
    final data = _dataFor(_tabs.index);
    final store = await _storage.loadStoreName();
    try {
      final bytes = await ReportPdf.build(data, storeName: store);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileBase);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('چاپ انجام نشد: $e')));
      }
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'گزارش‌های حسابداری',
          icon: Icons.bar_chart_rounded,
          actions: [
            ToolbarButton(label: 'بروزرسانی', icon: Icons.refresh_rounded, onPressed: _load),
            ToolbarButton(label: 'پیش‌نمایش / PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _loading ? null : _preview),
            ToolbarButton(label: 'چاپ', icon: Icons.print_outlined, primary: true, onPressed: _loading ? null : _printNow),
          ],
          bottom: AppTabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'تراز آزمایشی'),
              Tab(text: 'ترازنامه'),
              Tab(text: 'صورت سود و زیان'),
            ],
          ),
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
                        _dateField('از تاریخ', _fromCtrl),
                        const SizedBox(width: 10),
                        _dateField('تا تاریخ', _toCtrl),
                        const SizedBox(width: 6),
                        iconAction(
                          icon: Icons.clear,
                          tooltip: 'پاک کردن فیلتر تاریخ',
                          onPressed: () {
                            _fromCtrl.clear();
                            _toCtrl.clear();
                            setState(() {});
                          },
                        ),
                        const Spacer(),
                        const Text(
                          'فقط اسناد «دائم» در گزارش‌ها محاسبه می‌شوند.',
                          style: TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: ReportGrid(data: _dataFor(_tabs.index))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
