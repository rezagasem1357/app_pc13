import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../amount_format.dart';
import '../date_utils.dart';
import '../models.dart';
import '../report_engine.dart';
import '../report_pdf.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets/desktop_widgets.dart';
import 'pdf_preview_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});
  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonForm {
  _PersonForm(this.person, this.debit, this.credit, this.date);
  final Person person;
  final int debit;
  final int credit;
  final String date;
}

class _PersonsScreenState extends State<PersonsScreen> {
  final _storage = AppStorage();
  List<Person> _persons = [];
  List<AccountNode> _accounts = [];
  List<Voucher> _vouchers = [];
  final _search = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Future.wait([_storage.loadPersons(), _storage.loadAccounts(), _storage.loadVouchers()]);
    if (!mounted) return;
    setState(() {
      _persons = r[0] as List<Person>;
      _accounts = r[1] as List<AccountNode>;
      _vouchers = r[2] as List<Voucher>;
      _loading = false;
    });
  }

  AccountNode? _account(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  int _net(String accountId) {
    var d = 0, c = 0;
    for (final v in _vouchers) {
      if (v.status != VoucherStatus.permanent) continue;
      for (final l in v.lines) {
        if (l.accountId == accountId) {
          d += l.debit;
          c += l.credit;
        }
      }
    }
    return d - c;
  }

  List<Person> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Person>.from(_persons)
        : _persons
            .where((p) => '${p.name} ${p.nationalId} ${p.phone} ${p.code} ${p.typeLabel}'.toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// سند افتتاحیه (مانده اول دوره) شخص را ایجاد، ویرایش یا حذف می‌کند.
  /// مانده بدهکار: شخص بدهکار / سرمایه بستانکار — مانده بستانکار: عکس آن.
  void _syncOpeningVoucher(List<Voucher> vouchers, Person person, int debit, int credit, String date) {
    final amount = debit > 0 ? debit : credit;
    final idx = person.openingVoucherId.isEmpty ? -1 : vouchers.indexWhere((v) => v.id == person.openingVoucherId);
    if (amount <= 0) {
      if (idx >= 0) vouchers.removeAt(idx);
      person.openingVoucherId = '';
      person.openingDebit = 0;
      person.openingCredit = 0;
      person.openingDate = '';
      return;
    }
    final vid = idx >= 0 ? vouchers[idx].id : 'open_${DateTime.now().microsecondsSinceEpoch}';
    const capitalId = 't_capital';
    final desc = 'مانده اول دوره ${person.name}';
    final lines = debit > 0
        ? [
            VoucherLine(id: '${vid}a', accountId: person.accountId, description: 'مانده بدهکار اول دوره', debit: amount),
            VoucherLine(id: '${vid}b', accountId: capitalId, description: desc, credit: amount),
          ]
        : [
            VoucherLine(id: '${vid}a', accountId: capitalId, description: desc, debit: amount),
            VoucherLine(id: '${vid}b', accountId: person.accountId, description: 'مانده بستانکار اول دوره', credit: amount),
          ];
    if (idx >= 0) {
      final v = vouchers[idx];
      v.date = date;
      v.description = desc;
      v.lines = lines;
    } else {
      vouchers.add(Voucher(
        id: vid,
        number: 0,
        date: date,
        description: desc,
        reference: 'opening-${person.id}',
        type: VoucherType.opening,
        status: VoucherStatus.permanent,
        lines: lines,
      ));
    }
    person.openingVoucherId = vid;
    person.openingDebit = debit;
    person.openingCredit = credit;
    person.openingDate = date;
  }

  String _nextCode(List<AccountNode> accounts, String parentId) {
    final used = accounts.where((a) => a.parentId == parentId).map((a) => a.code).toSet();
    var n = used.length + 1;
    while (used.contains('14${n.toString().padLeft(2, '0')}')) {
      n++;
    }
    return '14${n.toString().padLeft(2, '0')}';
  }

  Future<void> _edit([Person? p]) async {
    final form = await showDialog<_PersonForm>(context: context, builder: (_) => _PersonDialog(existing: p));
    if (form == null) return;
    final accounts = List<AccountNode>.from(_accounts);
    final persons = List<Person>.from(_persons);
    final vouchers = await _storage.loadVouchers();
    final person = form.person;

    if (p == null) {
      final parent = accounts.firstWhere((a) => a.id == 'm_persons');
      person.accountId = person.id;
      accounts.add(AccountNode(
        id: person.id,
        code: _nextCode(accounts, parent.id),
        name: person.name,
        level: AccountLevel.tafsili,
        parentId: parent.id,
        nature: AccountNature.debit,
        group: AccountGroup.asset,
      ));
      persons.add(person);
    } else {
      final i = persons.indexWhere((x) => x.id == p.id);
      if (i >= 0) persons[i] = person;
      final ai = accounts.indexWhere((a) => a.id == person.accountId);
      if (ai >= 0) accounts[ai].name = person.name;
    }

    _syncOpeningVoucher(vouchers, person, form.debit, form.credit, form.date);
    await _storage.saveAccounts(accounts);
    await _storage.savePersons(persons);
    await _storage.saveVouchers(renumberVouchersByDate(vouchers));
    await _load();
  }

  Future<void> _delete(Person p) async {
    final hasActivity = _vouchers.any(
      (v) => v.id != p.openingVoucherId && v.lines.any((l) => l.accountId == p.accountId),
    );
    if (hasActivity) {
      _snack('این شخص گردش حساب دارد و حذف آن مجاز نیست.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف شخص'),
        content: Text('آیا «${p.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    final persons = List<Person>.from(_persons)..removeWhere((x) => x.id == p.id);
    final accounts = List<AccountNode>.from(_accounts)..removeWhere((a) => a.id == p.accountId);
    final vouchers = await _storage.loadVouchers();
    vouchers.removeWhere((v) => v.id == p.openingVoucherId && p.openingVoucherId.isNotEmpty);
    await _storage.savePersons(persons);
    await _storage.saveAccounts(accounts);
    await _storage.saveVouchers(renumberVouchersByDate(vouchers));
    await _load();
  }

  Future<ReportData> _reportData() async {
    final accounts = await _storage.loadAccounts();
    final vouchers = await _storage.loadVouchers();
    final persons = await _storage.loadPersons();
    return ReportEngine(accounts: accounts, vouchers: vouchers).personsBalances(persons);
  }

  Future<void> _preview() async {
    final data = await _reportData();
    final store = await _storage.loadStoreName();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: data.title,
          fileName: 'persons_balances_${todayJalali().replaceAll('/', '-')}',
          buildPdf: () => ReportPdf.build(data, storeName: store),
        ),
      ),
    );
  }

  Future<void> _printNow() async {
    try {
      final data = await _reportData();
      final store = await _storage.loadStoreName();
      final bytes = await ReportPdf.build(data, storeName: store);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'persons_balances');
    } catch (e) {
      _snack('چاپ انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _loading ? <Person>[] : _filtered;
    var sumD = 0, sumC = 0;
    final nets = <String, int>{};
    for (final p in filtered) {
      final n = _net(p.accountId);
      nets[p.id] = n;
      if (n > 0) sumD += n;
      if (n < 0) sumC += -n;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'اشخاص و طرف‌حساب‌ها',
          icon: Icons.groups_outlined,
          subtitle: 'اشخاص حقیقی و حقوقی، مانده بدهکار و بستانکار',
          actions: [
            ToolbarButton(label: 'پیش‌نمایش / PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _loading ? null : _preview),
            ToolbarButton(label: 'چاپ', icon: Icons.print_outlined, onPressed: _loading ? null : _printNow),
            ToolbarButton(label: 'شخص جدید', icon: Icons.person_add_alt_1, primary: true, onPressed: _loading ? null : () => _edit()),
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
                        SizedBox(
                          width: 360,
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search, size: 20),
                              hintText: 'جستجو: نام، کد ملی، تلفن',
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text('تعداد: ${toPersianDigits(filtered.length.toString())}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Panel(
                      child: DataGridView(
                        columns: const [
                          GridCol('کد', width: 64),
                          GridCol('نام / عنوان شخص', flex: 4),
                          GridCol('نوع', flex: 2),
                          GridCol('کد ملی / شناسه ملی', flex: 2),
                          GridCol('تلفن', flex: 2),
                          GridCol('مانده بدهکار', flex: 2, numeric: true),
                          GridCol('مانده بستانکار', flex: 2, numeric: true),
                          GridCol('', width: 76),
                        ],
                        rowCount: filtered.length,
                        onRowTap: (i) => _edit(filtered[i]),
                        emptyText: 'شخصی ثبت نشده است. با دکمه «شخص جدید» شروع کنید.',
                        cellBuilder: (i) {
                          final p = filtered[i];
                          final n = nets[p.id] ?? 0;
                          return [
                            gridText(toPersianDigits(_account(p.accountId)?.code ?? '-')),
                            gridText(p.name, bold: true),
                            gridText(p.typeLabel),
                            gridText(p.nationalId.isEmpty ? '-' : toPersianDigits(p.nationalId)),
                            gridText(p.phone.isEmpty ? '-' : toPersianDigits(p.phone)),
                            gridText(n > 0 ? moneyFa(n) : '-', color: n > 0 ? const Color(0xFF137A4B) : Colors.black38, bold: n > 0),
                            gridText(n < 0 ? moneyFa(-n) : '-', color: n < 0 ? const Color(0xFFB42318) : Colors.black38, bold: n < 0),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                iconAction(icon: Icons.edit_outlined, tooltip: 'ویرایش', onPressed: () => _edit(p)),
                                iconAction(icon: Icons.delete_outline, tooltip: 'حذف', color: Colors.red.shade400, onPressed: () => _delete(p)),
                              ],
                            ),
                          ];
                        },
                        footer: [
                          const SizedBox.shrink(),
                          gridText('جمع کل', bold: true, color: AppColors.primaryGreen),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          gridText(moneyFa(sumD), bold: true, color: const Color(0xFF137A4B)),
                          gridText(moneyFa(sumC), bold: true, color: const Color(0xFFB42318)),
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
    );
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({this.existing});
  final Person? existing;
  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _national = TextEditingController(text: widget.existing?.nationalId ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.existing?.address ?? '');
  late final TextEditingController _debit = TextEditingController(text: amountText(widget.existing?.openingDebit ?? 0));
  late final TextEditingController _credit = TextEditingController(text: amountText(widget.existing?.openingCredit ?? 0));
  late final TextEditingController _date = TextEditingController(
    text: (widget.existing?.openingDate ?? '').isEmpty ? todayJalali() : widget.existing!.openingDate,
  );
  bool _legal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _legal = widget.existing?.isLegal ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _national.dispose();
    _phone.dispose();
    _address.dispose();
    _debit.dispose();
    _credit.dispose();
    _date.dispose();
    super.dispose();
  }

  void _submit() {
    final debit = parseMoney(_debit.text);
    final credit = parseMoney(_credit.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام شخص الزامی است.');
      return;
    }
    if (debit > 0 && credit > 0) {
      setState(() => _error = 'مانده اول دوره فقط می‌تواند بدهکار یا بستانکار باشد؛ یکی از دو مبلغ را خالی بگذارید.');
      return;
    }
    final old = widget.existing;
    final person = Person(
      id: old?.id ?? 'person_${DateTime.now().microsecondsSinceEpoch}',
      accountId: old?.accountId ?? '',
      name: _name.text.trim(),
      type: _legal ? PersonType.legal : PersonType.individual,
      nationalId: _national.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      openingDebit: old?.openingDebit ?? 0,
      openingCredit: old?.openingCredit ?? 0,
      openingDate: old?.openingDate ?? '',
      openingVoucherId: old?.openingVoucherId ?? '',
    );
    final date = _date.text.trim().isEmpty ? todayJalali() : _date.text.trim();
    Navigator.pop(context, _PersonForm(person, debit, credit, date));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'ثبت شخص جدید' : 'ویرایش شخص'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('شخص حقیقی'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: true, label: Text('شخص حقوقی'), icon: Icon(Icons.business_outlined)),
                ],
                selected: {_legal},
                onSelectionChanged: (s) => setState(() => _legal = s.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'نام / عنوان شخص *')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _national,
                      decoration: InputDecoration(labelText: _legal ? 'شناسه ملی' : 'کد ملی'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'تلفن'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'نشانی')),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F7F4),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('مانده اول دوره', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                      'مانده بدهکار یعنی شخص به فروشگاه بدهکار است؛ مانده بستانکار یعنی فروشگاه به شخص بدهکار است. '
                      'این مبلغ به‌صورت سند افتتاحیه دائم ثبت می‌شود و در گزارش‌ها لحاظ می‌گردد.',
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AmountTextField(
                            controller: _debit,
                            label: 'مانده بدهکار',
                            icon: Icons.arrow_circle_down_outlined,
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AmountTextField(
                            controller: _credit,
                            label: 'مانده بستانکار',
                            icon: Icons.arrow_circle_up_outlined,
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _date,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(labelText: 'تاریخ مانده'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: _submit, child: const Text('ذخیره')),
      ],
    );
  }
}
