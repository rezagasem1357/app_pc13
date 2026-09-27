import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../amount_format.dart';
import '../models.dart';
import '../report_engine.dart';
import '../report_pdf.dart';
import '../storage.dart';
import '../date_utils.dart';
import 'pdf_preview_screen.dart';

class VoucherEntryScreen extends StatefulWidget {
  final Voucher? existing;
  const VoucherEntryScreen({super.key, this.existing});
  @override State<VoucherEntryScreen> createState()=>_VoucherEntryScreenState();
}

class _LineRow {
  AccountNode? kol; AccountNode? moin; AccountNode? tafsili;
  final TextEditingController descCtrl; final TextEditingController debitCtrl; final TextEditingController creditCtrl; final String id;
  _LineRow({this.kol,this.moin,this.tafsili,String description='',int debit=0,int credit=0,String? id})
    : id=id??DateTime.now().microsecondsSinceEpoch.toString(), descCtrl=TextEditingController(text:description), debitCtrl=TextEditingController(text:amountText(debit)), creditCtrl=TextEditingController(text:amountText(credit));
  int get debit=>parseMoney(debitCtrl.text);
  int get credit=>parseMoney(creditCtrl.text);
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  final _storage=AppStorage(); final _dateCtrl=TextEditingController(); final _descCtrl=TextEditingController(); final _refCtrl=TextEditingController();
  List<AccountNode> _accounts=[]; final List<_LineRow> _rows=[]; bool _loading=true; bool _saving=false; VoucherType _type=VoucherType.journal; int _nextNumber=1;
  VoucherStatus _status=VoucherStatus.temporary;
  bool get _isReadOnly=>_status==VoucherStatus.permanent;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    _accounts=await _storage.loadAccounts(); final vouchers=await _storage.loadVouchers(); _nextNumber=(vouchers.map((e)=>e.number).fold<int>(0,(a,b)=>a>b?a:b))+1;
    final e=widget.existing;
    if(e!=null){_dateCtrl.text=e.date;_descCtrl.text=e.description;_refCtrl.text=e.reference;_type=e.type;_status=e.status; for(final l in e.lines){final t=_accounts.where((a)=>a.id==l.accountId).cast<AccountNode?>().firstWhere((a)=>a!=null,orElse:()=>null); AccountNode? m,tK; if(t!=null){m=_accounts.where((a)=>a.id==t.parentId).cast<AccountNode?>().firstWhere((a)=>a!=null,orElse:()=>null); if(m!=null)tK=_accounts.where((a)=>a.id==m!.parentId).cast<AccountNode?>().firstWhere((a)=>a!=null,orElse:()=>null);} _rows.add(_LineRow(kol:tK,moin:m,tafsili:t,description:l.description,debit:l.debit,credit:l.credit,id:l.id));}}
    else{_dateCtrl.text=todayJalali();_rows.add(_LineRow());_rows.add(_LineRow());}
    if(mounted)setState(()=>_loading=false);
  }
  @override void dispose(){_dateCtrl.dispose();_descCtrl.dispose();_refCtrl.dispose();for(final r in _rows){r.descCtrl.dispose();r.debitCtrl.dispose();r.creditCtrl.dispose();}super.dispose();}
  int get _totalDebit=>_rows.fold(0,(s,r)=>s+r.debit); int get _totalCredit=>_rows.fold(0,(s,r)=>s+r.credit); int get _diff=>_totalDebit-_totalCredit;
  List<AccountNode> get _kolOptions=>_accounts.where((a)=>a.level==AccountLevel.kol).toList()..sort((a,b)=>a.code.compareTo(b.code));
  List<AccountNode> _moinOptions(AccountNode? k)=>k==null?[]:(_accounts.where((a)=>a.level==AccountLevel.moin&&a.parentId==k.id).toList()..sort((a,b)=>a.code.compareTo(b.code)));
  List<AccountNode> _tafsiliOptions(AccountNode? m)=>m==null?[]:(_accounts.where((a)=>a.level==AccountLevel.tafsili&&a.parentId==m.id).toList()..sort((a,b)=>a.code.compareTo(b.code)));
  void _show(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  void _addRow()=>setState(()=>_rows.add(_LineRow()));
  void _removeRow(_LineRow r){if(_rows.length<=2){_show('سند حداقل باید دو ردیف داشته باشد.');return;}r.descCtrl.dispose();r.debitCtrl.dispose();r.creditCtrl.dispose();setState(()=>_rows.remove(r));}
  String _money(int n)=>formatMoney(n);

  Future<void> _save({required bool permanent}) async {
    if(_isReadOnly||_saving)return; final active=_rows.where((r)=>r.tafsili!=null&&(r.debit>0||r.credit>0)).toList();
    if(active.length<2){_show('حداقل دو ردیف معتبر وارد کنید.');return;} if(_totalDebit!=_totalCredit||_totalDebit==0){_show('جمع بدهکار و بستانکار باید برابر و بزرگ‌تر از صفر باشد.');return;}
    setState(()=>_saving=true);try{final vs=await _storage.loadVouchers();final lines=active.map((r)=>VoucherLine(id:r.id,accountId:r.tafsili!.id,description:r.descCtrl.text.trim(),debit:r.debit,credit:r.credit)).toList();
      if(widget.existing!=null){final i=vs.indexWhere((v)=>v.id==widget.existing!.id);if(i>=0){vs[i].date=_dateCtrl.text.trim();vs[i].description=_descCtrl.text.trim();vs[i].reference=_refCtrl.text.trim();vs[i].type=_type;vs[i].lines=lines;vs[i].status=permanent?VoucherStatus.permanent:VoucherStatus.temporary;}}
      else{vs.add(Voucher(id:DateTime.now().microsecondsSinceEpoch.toString(),number:_nextNumber,date:_dateCtrl.text.trim(),description:_descCtrl.text.trim(),reference:_refCtrl.text.trim(),type:_type,status:permanent?VoucherStatus.permanent:VoucherStatus.temporary,lines:lines));}
      await _storage.saveVouchers(renumberVouchersByDate(vs));if(mounted){_status=permanent?VoucherStatus.permanent:VoucherStatus.temporary;Navigator.pop(context,true);}
    }finally{if(mounted)setState(()=>_saving=false);}
  }

  Future<void> _convertToTemporary() async {
    final existing=widget.existing;
    if(existing==null)return;
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('تبدیل سند دائم به موقت'),
      content:const Text('این سند از حالت دائم خارج و موقت می‌شود تا بتوانید آن را ویرایش یا حذف کنید. ادامه می‌دهید؟'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('تبدیل به موقت')),
      ],
    ));
    if(ok!=true)return;
    final vs=await _storage.loadVouchers();
    final i=vs.indexWhere((v)=>v.id==existing.id);
    if(i>=0){vs[i].status=VoucherStatus.temporary;await _storage.saveVouchers(vs);}
    if(mounted){setState(()=>_status=VoucherStatus.temporary);_show('سند به وضعیت موقت تبدیل شد؛ اکنون قابل ویرایش و حذف است.');}
  }

  Future<void> _print() async {
    final rows=_rows.where((r)=>r.tafsili!=null&&(r.debit>0||r.credit>0)).toList();
    if(rows.isEmpty){_show('برای چاپ حداقل یک ردیف معتبر لازم است.');return;}
    String name(AccountNode? a)=>a==null?'':'${a.code} — ${a.name}';
    String amt(int v)=>v==0?'-':moneyFa(v);
    final number=widget.existing?.number??_nextNumber;
    final data=ReportData(
      title:'سند حسابداری',
      columns:const [ReportColumn('ردیف',flex:1),ReportColumn('کد و عنوان حساب',flex:5),ReportColumn('شرح ردیف',flex:5),ReportColumn('بدهکار',flex:2,numeric:true),ReportColumn('بستانکار',flex:2,numeric:true)],
      rows:[
        for(var i=0;i<rows.length;i++) ReportRow([toPersianDigits('${i+1}'),name(rows[i].tafsili),rows[i].descCtrl.text.trim(),amt(rows[i].debit),amt(rows[i].credit)]),
        ReportRow(['','جمع کل','',moneyFa(_totalDebit),moneyFa(_totalCredit)],kind:RowKind.total),
      ],
      meta:[
        MapEntry('شماره سند',toPersianDigits('$number')),
        MapEntry('تاریخ سند',toPersianDigits(_dateCtrl.text.trim())),
        MapEntry('نوع سند',voucherTypeLabel(_type)),
        MapEntry('مرجع / شماره پیگیری',_refCtrl.text.trim().isEmpty?'-':_refCtrl.text.trim()),
        MapEntry('شرح سند',_descCtrl.text.trim().isEmpty?'-':_descCtrl.text.trim()),
      ],
      status:_diff==0?'سند متوازن است.':'مغایرت سند: ${moneyFa(_diff.abs())} ریال',
      statusOk:_diff==0,
    );
    final store=await _storage.loadStoreName();
    if(!mounted)return;
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>PdfPreviewScreen(title:'چاپ سند حسابداری',fileName:'voucher_$number',buildPdf:()=>ReportPdf.build(data,storeName:store))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final balanced = _diff == 0 && _totalDebit > 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _save(permanent: false),
        const SingleActivator(LogicalKeyboardKey.f2): () => _save(permanent: true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'ثبت اسناد حسابداری جدید' : 'ویرایش سند ${toPersianDigits(widget.existing!.number.toString())}'),
        actions: [
          IconButton(tooltip: 'چاپ', onPressed: _print, icon: const Icon(Icons.print_outlined)),
          if (_isReadOnly) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Center(child: Chip(label: const Text('دائم')))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _convertToTemporary,
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: const Text('تبدیل به موقت'),
                ),
              ),
            ),
          ],
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isReadOnly,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Expanded(child: _buildTable()),
              const SizedBox(height: 10),
              _buildFooter(balanced),
            ],
          ),
        ),
      ),
    ),
    ),
  );
  }

  Widget _field(String label,TextEditingController c,{bool readOnly=false,IconData? icon})=>TextField(controller:c,readOnly:readOnly,textDirection:TextDirection.rtl,decoration:InputDecoration(labelText:label,prefixIcon: icon == null ? null : Icon(icon),filled:true,fillColor:Colors.white));
  Widget _buildHeader()=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFDDE7E3))),child:Column(children:[
    Row(children:[Expanded(child:_field('شماره سند',TextEditingController(text:toPersianDigits((widget.existing?.number??_nextNumber).toString())),readOnly:true,icon:Icons.numbers)),const SizedBox(width:10),Expanded(child:_field('تاریخ سند',_dateCtrl,icon:Icons.calendar_today_outlined)),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<VoucherType>(value:_type,decoration:const InputDecoration(labelText:'نوع سند',filled:true,fillColor:Colors.white),items:VoucherType.values.map((x)=>DropdownMenuItem(value:x,child:Text(voucherTypeLabel(x)))).toList(),onChanged:(v)=>setState(()=>_type=v!))),const SizedBox(width:10),Expanded(child:_field('مرجع / شماره پیگیری',_refCtrl,icon:Icons.link_outlined))]),
    const SizedBox(height:10), _field('شرح کلی سند',_descCtrl,icon:Icons.notes_outlined)
  ]));
  Widget _buildTable()=>Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFDDE7E3))),child:Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),decoration:const BoxDecoration(color:Color(0xFFDDF4EF),borderRadius:BorderRadius.vertical(top:Radius.circular(14))),child:const Row(children:[SizedBox(width:36,child:Text('ردیف',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('حساب کل',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('حساب معین',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:3,child:Text('حساب تفصیلی',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('شرح ردیف',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('بدهکار',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('بستانکار',style:TextStyle(fontWeight:FontWeight.bold))),SizedBox(width:42)])),
    Expanded(child:ListView.separated(padding:const EdgeInsets.all(8),itemCount:_rows.length,separatorBuilder:(_,__)=>const Divider(height:8),itemBuilder:(c,i)=>_buildRow(i,_rows[i]))),
    Padding(padding:const EdgeInsets.fromLTRB(10,0,10,10),child:Align(alignment:Alignment.centerRight,child:OutlinedButton.icon(onPressed:_addRow,icon:const Icon(Icons.add),label:const Text('افزودن ردیف'))))
  ]));
  Widget _buildRow(int i,_LineRow r){return Row(children:[SizedBox(width:36,child:Text(toPersianDigits('${i+1}'))),Expanded(flex:2,child:_dd(r,_kolOptions,r.kol,(v){setState(() { r.kol=v; r.moin=null; r.tafsili=null; });})),const SizedBox(width:6),Expanded(flex:2,child:_dd(r,_moinOptions(r.kol),r.moin,(v){setState(() { r.moin=v; r.tafsili=null; });})),const SizedBox(width:6),Expanded(flex:3,child:_dd(r,_tafsiliOptions(r.moin),r.tafsili,(v)=>setState(()=>r.tafsili=v))),const SizedBox(width:6),Expanded(flex:2,child:TextField(controller:r.descCtrl,decoration:const InputDecoration(hintText:'شرح ردیف',filled:true,fillColor:Color(0xFFF8FAF9)))),const SizedBox(width:6),Expanded(flex:2,child:TextField(controller:r.debitCtrl,keyboardType:TextInputType.number,inputFormatters:const [ThousandsSeparatorFormatter()],textDirection:TextDirection.ltr,textAlign:TextAlign.right,onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'0',filled:true,fillColor:Color(0xFFF8FAF9)))),const SizedBox(width:6),Expanded(flex:2,child:TextField(controller:r.creditCtrl,keyboardType:TextInputType.number,inputFormatters:const [ThousandsSeparatorFormatter()],textDirection:TextDirection.ltr,textAlign:TextAlign.right,onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'0',filled:true,fillColor:Color(0xFFF8FAF9)))),IconButton(tooltip:'حذف ردیف',onPressed:()=>_removeRow(r),icon:const Icon(Icons.delete_outline,color:Colors.red))]);}
  Widget _dd(_LineRow r,List<AccountNode> options,AccountNode? value,ValueChanged<AccountNode?> onChanged){return DropdownButtonFormField<AccountNode>(value:options.any((x)=>x.id==value?.id)?value:null,isExpanded:true,decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:11),filled:true,fillColor:Color(0xFFF8FAF9),hintText:'انتخاب'),items:options.map((a)=>DropdownMenuItem(value:a,child:Text('${a.code} — ${a.name}',overflow:TextOverflow.ellipsis))).toList(),onChanged:onChanged);}
  Widget _buildFooter(bool balanced)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFDDE7E3))),child:Row(children:[Expanded(child:_sumBox('جمع بدهکار',_totalDebit,Colors.green)),const SizedBox(width:10),Expanded(child:_sumBox('جمع بستانکار',_totalCredit,Colors.blue)),const SizedBox(width:10),Expanded(child:_sumBox('تراز',_diff.abs(),balanced?Colors.green:Colors.red)),const SizedBox(width:16),OutlinedButton.icon(onPressed:_print,icon:const Icon(Icons.print_outlined),label:const Text('چاپ')),const SizedBox(width:8),OutlinedButton(onPressed:_saving?null:()=>_save(permanent:false),child:const Text('ذخیره موقت  (Ctrl+S)')),const SizedBox(width:8),FilledButton.icon(onPressed:_saving?null:()=>_save(permanent:true),icon:const Icon(Icons.save),label:const Text('ذخیره دائم  (F2)')),const SizedBox(width:8),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('بستن'))]));
  Widget _sumBox(String label,int value,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:c.withOpacity(.07),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(color:c,fontSize:11)),Text('${toPersianDigits(_money(value))} ریال',style:TextStyle(fontWeight:FontWeight.w800,color:c))]));
}
