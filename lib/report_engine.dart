import 'amount_format.dart';
import 'date_utils.dart';
import 'models.dart';

/// نوع ردیف در گزارش‌ها (هم برای نمایش روی صفحه و هم برای چاپ/PDF).
enum RowKind { normal, section, group, total }

class ReportColumn {
  const ReportColumn(this.title, {this.flex = 1, this.numeric = false});
  final String title;
  final int flex;
  final bool numeric;
}

class ReportRow {
  const ReportRow(this.cells, {this.kind = RowKind.normal, this.depth = 0});
  final List<String> cells;
  final RowKind kind;
  final int depth;
}

class ReportData {
  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
    this.meta = const [],
    this.status,
    this.statusOk = true,
    this.nameColumn = 1,
  });

  final String title;
  final List<ReportColumn> columns;
  final List<ReportRow> rows;
  final List<MapEntry<String, String>> meta;
  final String? status;
  final bool statusOk;

  /// اندیس ستونی که تورفتگی سطح حساب (کل/معین/تفصیلی) روی آن اعمال می‌شود.
  final int nameColumn;
}

class _Tot {
  int debit = 0;
  int credit = 0;
}

/// موتور تولید گزارش‌ها از روی اسناد «دائم». خروجی به صورت داده ساختاریافته است
/// تا یک منبع واحد برای نمایش روی صفحه، چاپ و PDF باشد.
class ReportEngine {
  ReportEngine({
    required this.accounts,
    required List<Voucher> vouchers,
    this.from = '',
    this.to = '',
  }) {
    final f = from.trim();
    final t = to.trim();
    for (final v in vouchers) {
      if (v.status != VoucherStatus.permanent) continue;
      if (f.isNotEmpty && compareJalaliDates(v.date, f) < 0) continue;
      if (t.isNotEmpty && compareJalaliDates(v.date, t) > 0) continue;
      for (final l in v.lines) {
        final tot = _own.putIfAbsent(l.accountId, () => _Tot());
        tot.debit += l.debit;
        tot.credit += l.credit;
      }
    }
    for (final a in accounts) {
      _children.putIfAbsent(a.parentId, () => <AccountNode>[]).add(a);
    }
    for (final list in _children.values) {
      list.sort((a, b) => a.code.compareTo(b.code));
    }
  }

  final List<AccountNode> accounts;
  final String from;
  final String to;

  final Map<String, _Tot> _own = {};
  final Map<String, _Tot> _sub = {};
  final Map<String?, List<AccountNode>> _children = {};

  List<AccountNode> _kids(String? id) => _children[id] ?? const <AccountNode>[];

  _Tot _subtree(AccountNode n) {
    final cached = _sub[n.id];
    if (cached != null) return cached;
    final t = _Tot();
    final own = _own[n.id];
    if (own != null) {
      t.debit += own.debit;
      t.credit += own.credit;
    }
    for (final c in _kids(n.id)) {
      final s = _subtree(c);
      t.debit += s.debit;
      t.credit += s.credit;
    }
    _sub[n.id] = t;
    return t;
  }

  int _balance(AccountNode n) {
    final t = _subtree(n);
    return n.nature == AccountNature.debit ? t.debit - t.credit : t.credit - t.debit;
  }

  List<AccountNode> _kols([AccountGroup? group]) {
    final list = accounts
        .where((a) => a.level == AccountLevel.kol && (group == null || a.group == group))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  String get periodLabel {
    final f = from.trim();
    final t = to.trim();
    if (f.isEmpty && t.isEmpty) return 'کل دوره (از ابتدا تا انتها)';
    if (f.isNotEmpty && t.isNotEmpty) return 'از تاریخ ${toPersianDigits(f)} تا تاریخ ${toPersianDigits(t)}';
    if (f.isNotEmpty) return 'از تاریخ ${toPersianDigits(f)}';
    return 'تا تاریخ ${toPersianDigits(t)}';
  }

  List<MapEntry<String, String>> get _meta => [
        MapEntry('دوره گزارش', periodLabel),
        const MapEntry('مبنای گزارش', 'اسناد دائم'),
        const MapEntry('واحد پول', 'ریال'),
      ];

  static String _m(int v) => toPersianDigits(formatMoney(v));
  static String _signed(int v) => v < 0 ? '(${_m(-v)})' : _m(v);
  static String _dash(int v) => v == 0 ? '-' : _m(v);

  // ───────────────────────── تراز آزمایشی ─────────────────────────
  ReportData trialBalance() {
    final rows = <ReportRow>[];
    var sumD = 0, sumC = 0, sumBalD = 0, sumBalC = 0;
    for (final kol in _kols()) {
      final t = _subtree(kol);
      final net = t.debit - t.credit;
      if (t.debit != 0 || t.credit != 0) {
        sumD += t.debit;
        sumC += t.credit;
        if (net > 0) sumBalD += net;
        if (net < 0) sumBalC += -net;
      }
      _trialRows(kol, 0, rows);
    }
    rows.add(ReportRow(
      ['', 'جمع کل', _m(sumD), _m(sumC), _m(sumBalD), _m(sumBalC)],
      kind: RowKind.total,
    ));
    final ok = sumD == sumC;
    return ReportData(
      title: 'تراز آزمایشی',
      columns: const [
        ReportColumn('کد', flex: 1),
        ReportColumn('نام حساب', flex: 4),
        ReportColumn('گردش بدهکار', flex: 2, numeric: true),
        ReportColumn('گردش بستانکار', flex: 2, numeric: true),
        ReportColumn('مانده بدهکار', flex: 2, numeric: true),
        ReportColumn('مانده بستانکار', flex: 2, numeric: true),
      ],
      rows: rows,
      meta: _meta,
      status: ok ? 'تراز آزمایشی متوازن است.' : 'مغایرت تراز آزمایشی: ${_m((sumD - sumC).abs())} ریال',
      statusOk: ok,
    );
  }

  void _trialRows(AccountNode n, int depth, List<ReportRow> out) {
    final t = _subtree(n);
    if (t.debit == 0 && t.credit == 0) return;
    final net = t.debit - t.credit;
    out.add(ReportRow(
      [
        toPersianDigits(n.code),
        n.name,
        _dash(t.debit),
        _dash(t.credit),
        net > 0 ? _m(net) : '-',
        net < 0 ? _m(-net) : '-',
      ],
      kind: depth == 0 ? RowKind.group : RowKind.normal,
      depth: depth,
    ));
    for (final c in _kids(n.id)) {
      _trialRows(c, depth + 1, out);
    }
  }

  // ───────────────────────── ترازنامه ─────────────────────────
  int _groupRows(String title, AccountGroup g, List<ReportRow> rows) {
    rows.add(ReportRow([title], kind: RowKind.section));
    var total = 0;
    for (final k in _kols(g)) {
      final b = _balance(k);
      if (b == 0) continue;
      total += b;
      rows.add(ReportRow([toPersianDigits(k.code), k.name, _signed(b)], kind: RowKind.group));
      for (final mo in _kids(k.id)) {
        final mb = _balance(mo);
        if (mb == 0) continue;
        rows.add(ReportRow([toPersianDigits(mo.code), mo.name, _signed(mb)], depth: 1));
      }
    }
    return total;
  }

  int _netIncome() {
    var revenue = 0, expense = 0;
    for (final k in _kols(AccountGroup.revenue)) {
      revenue += _balance(k);
    }
    for (final k in _kols(AccountGroup.expense)) {
      expense += _balance(k);
    }
    return revenue - expense;
  }

  ReportData balanceSheet() {
    final rows = <ReportRow>[];
    final assets = _groupRows('دارایی‌ها', AccountGroup.asset, rows);
    rows.add(ReportRow(['', 'جمع دارایی‌ها', _signed(assets)], kind: RowKind.total));

    final liab = _groupRows('بدهی‌ها', AccountGroup.liability, rows);
    rows.add(ReportRow(['', 'جمع بدهی‌ها', _signed(liab)], kind: RowKind.total));

    final eq = _groupRows('حقوق صاحبان سرمایه', AccountGroup.equity, rows);
    final net = _netIncome();
    if (net != 0) {
      rows.add(ReportRow(['', net >= 0 ? 'سود خالص دوره جاری' : 'زیان خالص دوره جاری', _signed(net)], depth: 1));
    }
    rows.add(ReportRow(['', 'جمع حقوق صاحبان سرمایه', _signed(eq + net)], kind: RowKind.total));
    final right = liab + eq + net;
    rows.add(ReportRow(['', 'جمع بدهی‌ها و حقوق صاحبان سرمایه', _signed(right)], kind: RowKind.total));

    final ok = assets == right;
    return ReportData(
      title: 'ترازنامه',
      columns: const [
        ReportColumn('کد', flex: 1),
        ReportColumn('شرح', flex: 6),
        ReportColumn('مبلغ (ریال)', flex: 2, numeric: true),
      ],
      rows: rows,
      meta: _meta,
      status: ok ? 'ترازنامه متوازن است.' : 'مغایرت ترازنامه: ${_m((assets - right).abs())} ریال',
      statusOk: ok,
    );
  }

  // ───────────────────────── سود و زیان ─────────────────────────
  ReportData incomeStatement() {
    final rows = <ReportRow>[];
    final revenue = _groupRows('درآمدها', AccountGroup.revenue, rows);
    rows.add(ReportRow(['', 'جمع درآمدها', _signed(revenue)], kind: RowKind.total));
    final expense = _groupRows('هزینه‌ها', AccountGroup.expense, rows);
    rows.add(ReportRow(['', 'جمع هزینه‌ها', _signed(expense)], kind: RowKind.total));
    final net = revenue - expense;
    rows.add(ReportRow(['', net >= 0 ? 'سود خالص دوره' : 'زیان خالص دوره', _m(net.abs())], kind: RowKind.total));
    return ReportData(
      title: 'صورت سود و زیان',
      columns: const [
        ReportColumn('کد', flex: 1),
        ReportColumn('شرح', flex: 6),
        ReportColumn('مبلغ (ریال)', flex: 2, numeric: true),
      ],
      rows: rows,
      meta: _meta,
      status: net >= 0 ? 'نتیجه دوره: سود خالص ${_m(net)} ریال' : 'نتیجه دوره: زیان خالص ${_m(-net)} ریال',
      statusOk: net >= 0,
    );
  }

  // ───────────────────────── مانده اشخاص ─────────────────────────
  ReportData personsBalances(List<Person> persons) {
    final byId = {for (final a in accounts) a.id: a};
    final sorted = List<Person>.from(persons)..sort((a, b) => a.name.compareTo(b.name));
    final rows = <ReportRow>[];
    var sumD = 0, sumC = 0;
    for (final p in sorted) {
      final t = _own[p.accountId];
      final net = (t?.debit ?? 0) - (t?.credit ?? 0);
      if (net > 0) sumD += net;
      if (net < 0) sumC += -net;
      rows.add(ReportRow([
        toPersianDigits(byId[p.accountId]?.code ?? '-'),
        p.name,
        p.typeLabel,
        net > 0 ? _m(net) : '-',
        net < 0 ? _m(-net) : '-',
      ]));
    }
    rows.add(ReportRow(['', 'جمع کل', '', _m(sumD), _m(sumC)], kind: RowKind.total));
    return ReportData(
      title: 'گزارش مانده اشخاص و طرف‌حساب‌ها',
      columns: const [
        ReportColumn('کد تفصیلی', flex: 1),
        ReportColumn('نام شخص', flex: 4),
        ReportColumn('نوع', flex: 2),
        ReportColumn('مانده بدهکار', flex: 2, numeric: true),
        ReportColumn('مانده بستانکار', flex: 2, numeric: true),
      ],
      rows: rows,
      meta: _meta,
    );
  }
}
