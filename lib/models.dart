/// سطح حساب در درخت حساب‌ها: کل > معین > تفصیلی.
/// فقط حساب‌های «تفصیلی» (برگ درخت) در سند حسابداری قابل استفاده‌اند؛
/// کل و معین صرفاً برای طبقه‌بندی و گزارش‌گیری هستند (مثل اکثر نرم‌افزارهای
/// حسابداری ایرانی از جمله سپیدار).
enum AccountLevel { kol, moin, tafsili }

AccountLevel accountLevelFromString(String s) {
  switch (s) {
    case 'moin':
      return AccountLevel.moin;
    case 'tafsili':
      return AccountLevel.tafsili;
    default:
      return AccountLevel.kol;
  }
}

/// ماهیت حساب: بدهکار (دارایی/هزینه) یا بستانکار (بدهی/سرمایه/درآمد).
/// برای تعیین اینکه در گزارش ترازنامه/سود‌وزیان، مانده حساب در کدام ستون
/// نمایش داده شود.
enum AccountNature { debit, credit }

/// گروه اصلی حساب کل، برای این‌که بشود گزارش ترازنامه/سود‌وزیان به‌صورت
/// خودکار بر اساس نوع حساب تولید شود.
enum AccountGroup { asset, liability, equity, revenue, expense }

AccountGroup accountGroupFromString(String s) {
  switch (s) {
    case 'liability':
      return AccountGroup.liability;
    case 'equity':
      return AccountGroup.equity;
    case 'revenue':
      return AccountGroup.revenue;
    case 'expense':
      return AccountGroup.expense;
    default:
      return AccountGroup.asset;
  }
}

class AccountNode {
  final String id;
  String code;
  String name;
  final AccountLevel level;
  final String? parentId;
  final AccountNature nature;
  final AccountGroup group;
  final bool isDefault; // حساب‌های پیش‌فرض سیستم (قابل ویرایش نام، ولی حذف‌شان هشدار دارد)

  AccountNode({
    required this.id,
    required this.code,
    required this.name,
    required this.level,
    required this.parentId,
    required this.nature,
    required this.group,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'level': level.name,
        'parentId': parentId,
        'nature': nature.name,
        'group': group.name,
        'isDefault': isDefault,
      };

  factory AccountNode.fromJson(Map<String, dynamic> json) => AccountNode(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        level: accountLevelFromString(json['level']?.toString() ?? 'kol'),
        parentId: json['parentId']?.toString(),
        nature: (json['nature']?.toString() ?? 'debit') == 'credit'
            ? AccountNature.credit
            : AccountNature.debit,
        group: accountGroupFromString(json['group']?.toString() ?? 'asset'),
        isDefault: json['isDefault'] == true,
      );
}

enum VoucherStatus { temporary, permanent }

enum VoucherType { journal, receipt, payment, opening, adjustment }

VoucherType voucherTypeFromString(String s) {
  switch (s) {
    case 'receipt': return VoucherType.receipt;
    case 'payment': return VoucherType.payment;
    case 'opening': return VoucherType.opening;
    case 'adjustment': return VoucherType.adjustment;
    default: return VoucherType.journal;
  }
}

String voucherTypeLabel(VoucherType type) {
  switch (type) {
    case VoucherType.receipt: return 'دریافت';
    case VoucherType.payment: return 'پرداخت';
    case VoucherType.opening: return 'افتتاحیه';
    case VoucherType.adjustment: return 'اصلاحی';
    case VoucherType.journal: return 'حواله';
  }
}


class VoucherLine {
  final String id;
  final String accountId; // شناسه حساب تفصیلی
  String description;
  int debit;
  int credit;

  VoucherLine({
    required this.id,
    required this.accountId,
    this.description = '',
    this.debit = 0,
    this.credit = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'description': description,
        'debit': debit,
        'credit': credit,
      };

  factory VoucherLine.fromJson(Map<String, dynamic> json) => VoucherLine(
        id: json['id']?.toString() ?? '',
        accountId: json['accountId']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        debit: (json['debit'] as num?)?.toInt() ?? 0,
        credit: (json['credit'] as num?)?.toInt() ?? 0,
      );
}

class Voucher {
  final String id;
  int number;
  String date;
  String description;
  String reference;
  VoucherType type;
  VoucherStatus status;
  List<VoucherLine> lines;
  final int createdAtMs;

  Voucher({
    required this.id,
    required this.number,
    required this.date,
    this.description = '',
    this.reference = '',
    this.type = VoucherType.journal,
    this.status = VoucherStatus.temporary,
    List<VoucherLine>? lines,
    int? createdAtMs,
  })  : lines = lines ?? [],
        createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  int get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  int get totalCredit => lines.fold(0, (s, l) => s + l.credit);
  bool get isBalanced => totalDebit == totalCredit && totalDebit > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date,
        'description': description,
        'reference': reference,
        'type': type.name,
        'status': status.name,
        'lines': lines.map((l) => l.toJson()).toList(),
        'createdAtMs': createdAtMs,
      };

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['id']?.toString() ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        date: json['date']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        type: voucherTypeFromString(json['type']?.toString() ?? 'journal'),
        status: (json['status']?.toString() ?? 'temporary') == 'permanent'
            ? VoucherStatus.permanent
            : VoucherStatus.temporary,
        lines: ((json['lines'] as List?) ?? [])
            .map((e) => VoucherLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAtMs: (json['createdAtMs'] as num?)?.toInt(),
      );
}




enum PersonType { individual, legal }

class Person {
  final String id;
  String accountId;
  String name;
  PersonType type;
  String nationalId;
  String phone;
  String address;

  /// مانده اول دوره (بدهکار یا بستانکار). هنگام ثبت شخص، یک سند افتتاحیه دائم
  /// خودکار برای آن صادر می‌شود و شناسه آن اینجا نگه داشته می‌شود.
  int openingDebit;
  int openingCredit;
  String openingDate;
  String openingVoucherId;

  Person({
    required this.id,
    required this.accountId,
    required this.name,
    this.type = PersonType.individual,
    this.nationalId = '',
    this.phone = '',
    this.address = '',
    this.openingDebit = 0,
    this.openingCredit = 0,
    this.openingDate = '',
    this.openingVoucherId = '',
  });

  bool get isLegal => type == PersonType.legal;
  String get code => id;
  String get typeLabel => isLegal ? 'شخص حقوقی' : 'شخص حقیقی';

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'name': name,
        'type': type.name,
        'nationalId': nationalId,
        'phone': phone,
        'address': address,
        'openingDebit': openingDebit,
        'openingCredit': openingCredit,
        'openingDate': openingDate,
        'openingVoucherId': openingVoucherId,
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id']?.toString() ?? '',
        accountId: j['accountId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() == 'legal' ? PersonType.legal : PersonType.individual,
        nationalId: j['nationalId']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        address: j['address']?.toString() ?? '',
        openingDebit: (j['openingDebit'] as num?)?.toInt() ?? 0,
        openingCredit: (j['openingCredit'] as num?)?.toInt() ?? 0,
        openingDate: j['openingDate']?.toString() ?? '',
        openingVoucherId: j['openingVoucherId']?.toString() ?? '',
      );
}

/// مرکز هزینه برای تفکیک و گزارش‌گیری هزینه‌های فروشگاه.
class CostCenter {
  final String id;
  String name;
  bool active;

  CostCenter({required this.id, required this.name, this.active = true});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'active': active};

  factory CostCenter.fromJson(Map<String, dynamic> json) => CostCenter(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        active: json['active'] != false,
      );
}

/// ثبت هزینه؛ هر هزینه به یک مرکز هزینه و یک سند حسابداری خودکار متصل است.
class ExpenseRecord {
  final String id;
  String date;
  String title;
  String description;
  int amount;
  String costCenterId;
  String expenseAccountId;
  String settlementAccountId;
  String voucherId;
  int createdAtMs;

  ExpenseRecord({
    required this.id,
    required this.date,
    required this.title,
    this.description = '',
    required this.amount,
    required this.costCenterId,
    required this.expenseAccountId,
    required this.settlementAccountId,
    required this.voucherId,
    int? createdAtMs,
  }) : createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'description': description,
        'amount': amount,
        'costCenterId': costCenterId,
        'expenseAccountId': expenseAccountId,
        'settlementAccountId': settlementAccountId,
        'voucherId': voucherId,
        'createdAtMs': createdAtMs,
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        costCenterId: json['costCenterId']?.toString() ?? '',
        expenseAccountId: json['expenseAccountId']?.toString() ?? '',
        settlementAccountId: json['settlementAccountId']?.toString() ?? '',
        voucherId: json['voucherId']?.toString() ?? '',
        createdAtMs: (json['createdAtMs'] as num?)?.toInt(),
      );
}

/// رویداد مالی دریافت/پرداخت. این رکورد علاوه بر تاریخچه عملیات، شناسه سند
/// حسابداری خودکار را نگه می‌دارد تا هر عملیات مالی قابل ردیابی و پشتیبان‌گیری باشد.
class FinancialTransaction {
  final String id;
  String date;
  String kind; // receipt / payment
  String title;
  String description;
  int amount;
  String settlement; // cash / credit
  String sourceAccountId;
  String counterAccountId;
  String voucherId;
  int createdAtMs;

  FinancialTransaction({
    required this.id,
    required this.date,
    required this.kind,
    required this.title,
    this.description = '',
    required this.amount,
    required this.settlement,
    required this.sourceAccountId,
    required this.counterAccountId,
    required this.voucherId,
    int? createdAtMs,
  }) : createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'kind': kind, 'title': title,
    'description': description, 'amount': amount, 'settlement': settlement,
    'sourceAccountId': sourceAccountId, 'counterAccountId': counterAccountId,
    'voucherId': voucherId, 'createdAtMs': createdAtMs,
  };

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) => FinancialTransaction(
    id: json['id']?.toString() ?? '',
    date: json['date']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'payment',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    settlement: json['settlement']?.toString() ?? 'cash',
    sourceAccountId: json['sourceAccountId']?.toString() ?? '',
    counterAccountId: json['counterAccountId']?.toString() ?? '',
    voucherId: json['voucherId']?.toString() ?? '',
    createdAtMs: (json['createdAtMs'] as num?)?.toInt(),
  );
}
