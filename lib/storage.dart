import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'date_utils.dart';

/// لایه ذخیره‌سازی محلی (مشابه اپ موبایل، با SharedPreferences و JSON).
/// اگر بعداً نیاز به اتصال چند دستگاه/سرور شد، همین لایه محل مناسبی برای
/// اضافه‌کردن sync است.
class AppStorage {
  static const _kAccounts = 'coa_accounts_v1';
  static const _kVouchers = 'vouchers_v1';
  static const _kStoreName = 'store_name_v1';
  static const _kAutoRenumberByDate = 'voucher_auto_renumber_by_date_v1';
  static const _kFinancialTransactions = 'financial_transactions_v1';
  static const _kCostCenters = 'cost_centers_v1';
  static const _kExpenses = 'expenses_v1';
  static const _kPersons = 'persons_v1';

  Future<List<AccountNode>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAccounts);
    if (raw == null || raw.isEmpty) {
      final defaults = buildDefaultChartOfAccounts();
      await saveAccounts(defaults);
      return defaults;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => AccountNode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    // مهاجرت سبک: حساب‌های پیش‌فرض جدید (از جمله اشخاص و حساب‌های هزینه)
    // در نسخه‌های قبلی نیز خودکار اضافه شوند.
    final defaults = buildDefaultChartOfAccounts();
    var changed = false;
    for (final d in defaults) {
      if (!list.any((a) => a.id == d.id)) {
        // فقط حساب‌های سیستمی پیش‌فرض اضافه می‌شوند؛ حساب‌های سفارشی کاربر دست‌نخورده می‌مانند.
        if (d.isDefault) { list.add(d); changed = true; }
      }
    }
    if (changed) await saveAccounts(list);
    return list;
  }

  Future<void> saveAccounts(List<AccountNode> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  Future<List<Voucher>> loadVouchers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kVouchers);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Voucher.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveVouchers(List<Voucher> vouchers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVouchers, jsonEncode(vouchers.map((v) => v.toJson()).toList()));
  }

  Future<List<FinancialTransaction>> loadFinancialTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFinancialTransactions);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FinancialTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFinancialTransactions(List<FinancialTransaction> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFinancialTransactions, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<Person>> loadPersons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPersons);
    if (raw == null || raw.isEmpty) return [];
    try { return (jsonDecode(raw) as List).map((e)=>Person.fromJson(Map<String,dynamic>.from(e as Map))).toList(); } catch (_) { return []; }
  }

  Future<void> savePersons(List<Person> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPersons, jsonEncode(items.map((e)=>e.toJson()).toList()));
  }

  Future<List<CostCenter>> loadCostCenters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCostCenters);
    if (raw == null || raw.isEmpty) {
      final defaults = buildDefaultCostCenters();
      await saveCostCenters(defaults);
      return defaults;
    }
    try {
      return (jsonDecode(raw) as List)
          .map((e) => CostCenter.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return buildDefaultCostCenters();
    }
  }

  Future<void> saveCostCenters(List<CostCenter> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCostCenters, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<ExpenseRecord>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kExpenses);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ExpenseRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveExpenses(List<ExpenseRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExpenses, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  /// فایل پشتیبان نسخه‌دار و قابل توسعه است؛ هر مدرک مالی جدید در آینده
  /// می‌تواند بدون تغییر ساختار اصلی برنامه به بخش financialDocuments اضافه شود.
  Future<Map<String, dynamic>> buildBackupBundle() async {
    final accounts = await loadAccounts();
    final vouchers = await loadVouchers();
    final transactions = await loadFinancialTransactions();
    return {
      'backupVersion': 3,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'application': 'store_accounting_desktop',
      'storeName': await loadStoreName(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'vouchers': vouchers.map((e) => e.toJson()).toList(),
      'financialTransactions': transactions.map((e) => e.toJson()).toList(),
      'costCenters': (await loadCostCenters()).map((e) => e.toJson()).toList(),
      'expenses': (await loadExpenses()).map((e) => e.toJson()).toList(),
      'persons': (await loadPersons()).map((e) => e.toJson()).toList(),
      'financialDocuments': <Map<String, dynamic>>[],
    };
  }

  Future<void> restoreBackupBundle(Map<String, dynamic> bundle) async {
    final accountsRaw = (bundle['accounts'] as List?) ?? [];
    final vouchersRaw = (bundle['vouchers'] as List?) ?? [];
    final transactionsRaw = (bundle['financialTransactions'] as List?) ?? [];
    final centersRaw = (bundle['costCenters'] as List?) ?? [];
    final expensesRaw = (bundle['expenses'] as List?) ?? [];
    final personsRaw = (bundle['persons'] as List?) ?? [];
    final accounts = accountsRaw
        .map((e) => AccountNode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final vouchers = vouchersRaw
        .map((e) => Voucher.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final transactions = transactionsRaw
        .map((e) => FinancialTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final centers = centersRaw
        .map((e) => CostCenter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final expenses = expensesRaw
        .map((e) => ExpenseRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final persons = personsRaw
        .map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (accounts.isEmpty) throw const FormatException('فایل پشتیبان فاقد حساب‌ها است.');
    await saveAccounts(accounts);
    await saveVouchers(vouchers);
    await saveFinancialTransactions(transactions);
    await saveCostCenters(centers.isEmpty ? buildDefaultCostCenters() : centers);
    await saveExpenses(expenses);
    await savePersons(persons);
    final storeName = bundle['storeName']?.toString();
    if (storeName != null && storeName.trim().isNotEmpty) await saveStoreName(storeName.trim());
  }

  Future<String> loadStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStoreName) ?? 'کریم اهل بیت';
  }

  Future<void> saveStoreName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, name);
  }

  /// طبق درخواست: شماره‌گذاری سند از ۱ شروع و همیشه به ترتیب تاریخ صدور است.
  /// این تنظیم فقط برای این‌که در آینده در صورت نیاز غیرفعال شود نگه داشته
  /// می‌شود؛ فعلاً همیشه true است.
  Future<bool> loadAutoRenumberByDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoRenumberByDate) ?? true;
  }

  Future<void> saveAutoRenumberByDate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoRenumberByDate, value);
  }
}

List<CostCenter> buildDefaultCostCenters() => [
      CostCenter(id: 'cc_store', name: 'فروشگاه اصلی'),
      CostCenter(id: 'cc_admin', name: 'اداری'),
      CostCenter(id: 'cc_staff', name: 'حقوق و پرسنل'),
      CostCenter(id: 'cc_rent', name: 'اجاره'),
      CostCenter(id: 'cc_services', name: 'خدمات و قبوض'),
      CostCenter(id: 'cc_supplies', name: 'ملزومات'),
    ];

/// برای هر سند، «چندمین سند همان روز» بودنش را محاسبه می‌کند (کلید: id سند).
/// طبق درخواست: علاوه بر شماره کلی سند (۱،۲،۳...)، شماره روزانه هم لازم است
/// (مثلاً «سومین سند تاریخ ۱۴۰۳/۰۷/۰۱»).
Map<String, int> computeDailyNumbers(List<Voucher> vouchers) {
  final byDate = <String, List<Voucher>>{};
  for (final v in vouchers) {
    byDate.putIfAbsent(v.date, () => []).add(v);
  }
  final result = <String, int>{};
  for (final entry in byDate.entries) {
    final sorted = List<Voucher>.from(entry.value)
      ..sort((a, b) {
        final byNumber = a.number.compareTo(b.number);
        if (byNumber != 0) return byNumber;
        return a.createdAtMs.compareTo(b.createdAtMs);
      });
    for (var i = 0; i < sorted.length; i++) {
      result[sorted[i].id] = i + 1;
    }
  }
  return result;
}

/// همه‌ی اسناد را بر اساس تاریخ صدور (و در تاریخ یکسان، بر اساس ترتیب ثبت)
/// مرتب کرده و شماره ۱ به بعد را به‌ترتیب اختصاص می‌دهد. طبق خواسته کاربر:
/// «شماره‌گذاری خودکار سند حسابداری از یک به بعد اتوماتیک به ترتیب تاریخ».
///
/// نکته: در نرم‌افزارهای حسابداری رایج معمولاً شماره سند دائم دیگر تغییر
/// نمی‌کند (برای حفظ ردیابی)، اما چون در این‌جا صراحتاً «ترتیب تاریخ خودکار»
/// خواسته شده، این تابع شماره همه اسناد (موقت و دائم) را بازچینی می‌کند.
List<Voucher> renumberVouchersByDate(List<Voucher> vouchers) {
  final sorted = List<Voucher>.from(vouchers)
    ..sort((a, b) {
      final byDate = compareJalaliDates(a.date, b.date);
      if (byDate != 0) return byDate;
      return a.createdAtMs.compareTo(b.createdAtMs);
    });
  for (var i = 0; i < sorted.length; i++) {
    sorted[i].number = i + 1;
  }
  return sorted;
}

/// درخت پیش‌فرض حساب‌ها (کل > معین > تفصیلی) برای یک فروشگاه — نقطه شروع
/// حداقلی و قابل ویرایش/گسترش توسط کاربر.
List<AccountNode> buildDefaultChartOfAccounts() {
  final list = <AccountNode>[];

  void kol(String id, String code, String name, AccountNature nature, AccountGroup group) {
    list.add(AccountNode(
      id: id,
      code: code,
      name: name,
      level: AccountLevel.kol,
      parentId: null,
      nature: nature,
      group: group,
      isDefault: true,
    ));
  }

  void moin(String id, String parentId, String code, String name) {
    final parent = list.firstWhere((a) => a.id == parentId);
    list.add(AccountNode(
      id: id,
      code: code,
      name: name,
      level: AccountLevel.moin,
      parentId: parentId,
      nature: parent.nature,
      group: parent.group,
      isDefault: true,
    ));
  }

  void tafsili(String id, String parentId, String code, String name) {
    final parent = list.firstWhere((a) => a.id == parentId);
    list.add(AccountNode(
      id: id,
      code: code,
      name: name,
      level: AccountLevel.tafsili,
      parentId: parentId,
      nature: parent.nature,
      group: parent.group,
      isDefault: true,
    ));
  }

  // ---- دارایی‌ها ----
  kol('k_asset', '1', 'دارایی‌ها', AccountNature.debit, AccountGroup.asset);
  moin('m_cash_bank', 'k_asset', '11', 'موجودی نقد و بانک');
  tafsili('t_cash', 'm_cash_bank', '1101', 'صندوق');
  tafsili('t_bank', 'm_cash_bank', '1102', 'بانک');
  moin('m_receivable', 'k_asset', '12', 'حساب‌های دریافتنی (مشتریان)');
  moin('m_persons', 'k_asset', '14', 'اشخاص و طرف‌حساب‌ها');
  tafsili('t_customers', 'm_receivable', '1201', 'مشتریان متفرقه');
  moin('m_inventory', 'k_asset', '13', 'موجودی کالا');
  tafsili('t_inventory_goods', 'm_inventory', '1301', 'موجودی کالای فروشگاه');

  // ---- بدهی‌ها ----
  kol('k_liability', '2', 'بدهی‌ها', AccountNature.credit, AccountGroup.liability);
  moin('m_payable', 'k_liability', '21', 'حساب‌های پرداختنی (تامین‌کنندگان)');
  tafsili('t_suppliers', 'm_payable', '2101', 'تامین‌کنندگان متفرقه');
  moin('m_notes_payable', 'k_liability', '22', 'اسناد پرداختنی');
  tafsili('t_checks_payable', 'm_notes_payable', '2201', 'چک‌های پرداختنی');

  // ---- حقوق صاحبان سرمایه ----
  kol('k_equity', '3', 'حقوق صاحبان سرمایه', AccountNature.credit, AccountGroup.equity);
  moin('m_capital', 'k_equity', '31', 'سرمایه');
  tafsili('t_capital', 'm_capital', '3101', 'سرمایه مالک');
  moin('m_retained', 'k_equity', '32', 'سود (زیان) انباشته');
  tafsili('t_retained', 'm_retained', '3201', 'سود و زیان انباشته');

  // ---- درآمدها ----
  kol('k_revenue', '4', 'درآمدها', AccountNature.credit, AccountGroup.revenue);
  moin('m_sales', 'k_revenue', '41', 'فروش کالا');
  tafsili('t_sales_goods', 'm_sales', '4101', 'فروش کالای فروشگاه');
  moin('m_other_revenue', 'k_revenue', '42', 'سایر درآمدها');
  tafsili('t_other_revenue', 'm_other_revenue', '4201', 'درآمدهای متفرقه');

  // ---- هزینه‌ها ----
  kol('k_expense', '5', 'هزینه‌ها', AccountNature.debit, AccountGroup.expense);
  moin('m_cogs', 'k_expense', '51', 'بهای تمام‌شده کالای فروش‌رفته');
  tafsili('t_cogs', 'm_cogs', '5101', 'بهای تمام‌شده کالای فروش‌رفته');
  moin('m_opex', 'k_expense', '52', 'هزینه‌های عملیاتی');
  tafsili('t_rent', 'm_opex', '5201', 'اجاره');
  tafsili('t_salary', 'm_opex', '5202', 'حقوق و دستمزد');
  tafsili('t_utilities', 'm_opex', '5203', 'آب، برق و گاز');
  tafsili('t_misc_expense', 'm_opex', '5204', 'هزینه‌های متفرقه');
  tafsili('t_supplies_expense', 'm_opex', '5205', 'ملزومات مصرفی');
  tafsili('t_repairs', 'm_opex', '5206', 'تعمیرات و نگهداری');
  tafsili('t_transport', 'm_opex', '5207', 'حمل و نقل');
  tafsili('t_advertising', 'm_opex', '5208', 'تبلیغات');
  tafsili('t_bank_fees', 'm_opex', '5209', 'کارمزد بانکی');

  return list;
}
