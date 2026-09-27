import 'package:flutter/material.dart';
import '../amount_format.dart';
import '../models.dart';
import '../storage.dart';
import '../date_utils.dart';
import '../theme.dart';
import '../widgets/desktop_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _storage = AppStorage();
  List<ExpenseRecord> _items = [];
  List<CostCenter> _centers = [];
  List<AccountNode> _accounts = [];
  Map<String, int> _voucherNumbers = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final results = await Future.wait([
      _storage.loadExpenses(),
      _storage.loadCostCenters(),
      _storage.loadAccounts(),
      _storage.loadVouchers(),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<ExpenseRecord>;
      _centers = results[1] as List<CostCenter>;
      _accounts = results[2] as List<AccountNode>;
      _voucherNumbers = {for (final v in results[3] as List<Voucher>) v.id: v.number};
      _items.sort((a,b) => b.createdAtMs.compareTo(a.createdAtMs));
      _loading = false;
    });
  }

  String _centerName(String id) {
    for (final c in _centers) { if (c.id == id) return c.name; }
    return '—';
  }
  String _accountName(String id) {
    for (final a in _accounts) { if (a.id == id) return a.name; }
    return '—';
  }

  Future<void> _addExpense() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _ExpenseDialog(storage: _storage, accounts: _accounts, centers: _centers));
    if (ok == true) _load();
  }

  Future<void> _manageCenters() async {
    await showDialog(context: context, builder: (_) => _CentersDialog(storage: _storage, centers: _centers));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (s, e) => s + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'هزینه‌ها و مراکز هزینه',
          icon: Icons.payments_outlined,
          actions: [
            ToolbarButton(label: 'مدیریت مراکز هزینه', icon: Icons.account_tree_outlined, onPressed: _loading ? null : _manageCenters),
            ToolbarButton(label: 'ثبت هزینه', icon: Icons.add, primary: true, onPressed: _loading ? null : _addExpense),
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      StatBox(label: 'تعداد هزینه‌ها', value: toPersianDigits(_items.length.toString()), color: AppColors.primaryGreen, icon: Icons.receipt_long_outlined),
                      StatBox(label: 'جمع هزینه‌ها (ریال)', value: moneyFa(total), color: const Color(0xFFB42318), icon: Icons.payments_outlined, width: 260),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Panel(
                      child: DataGridView(
                        columns: const [
                          GridCol('تاریخ', width: 100),
                          GridCol('عنوان هزینه', flex: 3),
                          GridCol('مرکز هزینه', flex: 2),
                          GridCol('حساب هزینه', flex: 2),
                          GridCol('شرح', flex: 3),
                          GridCol('شماره سند', width: 90),
                          GridCol('مبلغ (ریال)', flex: 2, numeric: true),
                        ],
                        rowCount: _items.length,
                        emptyText: 'هنوز هزینه‌ای ثبت نشده است.',
                        cellBuilder: (i) {
                          final e = _items[i];
                          final no = _voucherNumbers[e.voucherId];
                          return [
                            gridText(toPersianDigits(e.date)),
                            gridText(e.title, bold: true),
                            gridText(_centerName(e.costCenterId)),
                            gridText(_accountName(e.expenseAccountId)),
                            gridText(e.description.isEmpty ? '-' : e.description),
                            gridText(no == null ? '—' : toPersianDigits(no.toString())),
                            gridText(moneyFa(e.amount), bold: true, color: const Color(0xFFB42318)),
                          ];
                        },
                        footer: [
                          const SizedBox.shrink(),
                          gridText('جمع کل', bold: true),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          gridText(moneyFa(total), bold: true, color: const Color(0xFFB42318)),
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

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.storage, required this.accounts, required this.centers});
  final AppStorage storage; final List<AccountNode> accounts; final List<CostCenter> centers;
  @override State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _date = TextEditingController(text: todayJalali());
  String? _centerId;
  String? _expenseId;
  String? _settlementId;

  List<AccountNode> get expenseAccounts => widget.accounts.where((a) => a.level == AccountLevel.tafsili && a.group == AccountGroup.expense && a.id != 't_cogs').toList()..sort((a,b)=>a.code.compareTo(b.code));
  List<AccountNode> get settlementAccounts => widget.accounts.where((a) => a.level == AccountLevel.tafsili && (a.id == 't_cash' || a.id == 't_bank' || a.group == AccountGroup.liability && a.id == 't_suppliers')).toList()..sort((a,b)=>a.code.compareTo(b.code));
  int get amount => parseMoney(_amount.text);

  @override void initState() {
    super.initState();
    if (widget.centers.where((e)=>e.active).isNotEmpty) _centerId = widget.centers.firstWhere((e)=>e.active).id;
    if (expenseAccounts.isNotEmpty) _expenseId = expenseAccounts.first.id;
    if (settlementAccounts.isNotEmpty) _settlementId = settlementAccounts.first.id;
  }
  @override void dispose(){_amount.dispose();_title.dispose();_desc.dispose();_date.dispose();super.dispose();}

  Future<void> _save() async {
    if (amount <= 0 || _centerId == null || _expenseId == null || _settlementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ، مرکز هزینه، حساب هزینه و روش پرداخت را کامل کنید.'))); return;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final title = _title.text.trim().isEmpty ? 'ثبت هزینه' : _title.text.trim();
    final vouchers = await widget.storage.loadVouchers();
    final voucher = Voucher(
      id: id, number: 0, date: _date.text.trim(), type: VoucherType.payment, status: VoucherStatus.permanent,
      description: _desc.text.trim().isEmpty ? title : _desc.text.trim(), reference: 'expense-${id.substring(id.length-6)}',
      lines: [
        VoucherLine(id:'${id}a', accountId:_expenseId!, description:title, debit:amount),
        VoucherLine(id:'${id}b', accountId:_settlementId!, description:title, credit:amount),
      ],
    );
    vouchers.add(voucher);
    await widget.storage.saveVouchers(renumberVouchersByDate(vouchers));
    final records = await widget.storage.loadExpenses();
    records.add(ExpenseRecord(id:id,date:_date.text.trim(),title:title,description:_desc.text.trim(),amount:amount,costCenterId:_centerId!,expenseAccountId:_expenseId!,settlementAccountId:_settlementId!,voucherId:id));
    await widget.storage.saveExpenses(records);
    if (mounted) Navigator.pop(context, true);
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('ثبت هزینه و ایجاد سند خودکار'),
    content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, children:[
      Row(children:[Expanded(child:TextField(controller:_title,decoration:const InputDecoration(labelText:'عنوان هزینه'))),const SizedBox(width:10),Expanded(child:TextField(controller:_date,decoration:const InputDecoration(labelText:'تاریخ سند')))]),
      const SizedBox(height:10),
      AmountTextField(controller:_amount,label:'مبلغ (ریال)',icon:Icons.payments_outlined,onChanged:(_)=>setState((){})),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:_centerId,decoration:const InputDecoration(labelText:'مرکز هزینه'),items:widget.centers.where((e)=>e.active).map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name))).toList(),onChanged:(v)=>setState(()=>_centerId=v)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:_expenseId,decoration:const InputDecoration(labelText:'حساب هزینه'),items:expenseAccounts.map((a)=>DropdownMenuItem(value:a.id,child:Text('${a.code} — ${a.name}'))).toList(),onChanged:(v)=>setState(()=>_expenseId=v)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:_settlementId,decoration:const InputDecoration(labelText:'روش پرداخت / حساب مقابل'),items:settlementAccounts.map((a)=>DropdownMenuItem(value:a.id,child:Text('${a.code} — ${a.name}'))).toList(),onChanged:(v)=>setState(()=>_settlementId=v)),
      const SizedBox(height:10),
      TextField(controller:_desc,maxLines:2,decoration:const InputDecoration(labelText:'شرح')),
      const SizedBox(height:14),
      Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.grey.shade100,borderRadius:BorderRadius.circular(10)),child:Text('سند خودکار: ${_expenseId == null ? 'حساب هزینه' : expenseAccounts.firstWhere((a)=>a.id==_expenseId, orElse:()=>expenseAccounts.first).name} بدهکار ← ${_settlementId == null ? 'صندوق/بانک' : settlementAccounts.firstWhere((a)=>a.id==_settlementId, orElse:()=>settlementAccounts.first).name} بستانکار')),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('انصراف')),FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save),label:const Text('ثبت هزینه و سند'))],
  );
}

class _CentersDialog extends StatefulWidget {
  const _CentersDialog({required this.storage, required this.centers});
  final AppStorage storage; final List<CostCenter> centers;
  @override State<_CentersDialog> createState()=>_CentersDialogState();
}
class _CentersDialogState extends State<_CentersDialog> {
  final _name = TextEditingController();
  late List<CostCenter> _items = List<CostCenter>.from(widget.centers);
  @override void dispose(){_name.dispose();super.dispose();}
  Future<void> _save() async { final n=_name.text.trim(); if(n.isEmpty)return; _items.add(CostCenter(id:'cc-${DateTime.now().microsecondsSinceEpoch}',name:n)); await widget.storage.saveCostCenters(_items); setState(()=>_name.clear()); }
  Future<void> _toggle(CostCenter c) async { c.active=!c.active; await widget.storage.saveCostCenters(_items); setState((){}); }
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('مدیریت مراکز هزینه'),content:SizedBox(width:520,height:420,child:Column(children:[Row(children:[Expanded(child:TextField(controller:_name,decoration:const InputDecoration(labelText:'مرکز هزینه جدید'))),const SizedBox(width:8),IconButton(onPressed:_save,icon:const Icon(Icons.add_circle),tooltip:'افزودن')]),const Divider(),Expanded(child:ListView.builder(itemCount:_items.length,itemBuilder:(_,i){final c=_items[i];return ListTile(title:Text(c.name),subtitle:Text(c.active?'فعال':'غیرفعال'),trailing:Switch(value:c.active,onChanged:(_)=>_toggle(c)));}))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('بستن'))]);
}
