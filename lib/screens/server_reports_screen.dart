import 'package:flutter/material.dart';
import '../network_service.dart';
import '../date_utils.dart';
import '../amount_format.dart';
import '../widgets/desktop_widgets.dart';
import 'server_settings_tab.dart';

class ServerReportsScreen extends StatefulWidget {
  const ServerReportsScreen({super.key});
  @override State<ServerReportsScreen> createState()=>_ServerReportsScreenState();
}

class _ServerReportsScreenState extends State<ServerReportsScreen> with SingleTickerProviderStateMixin {
  final _service=NetworkService(); late final TabController _tabs=TabController(length:7,vsync:this); List<Map<String,dynamic>> _events=[]; bool _loading=true; String? _error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>_loading=true);try{final c=await _service.loadConfig();if(!c.isConfigured){setState(() { _loading=false; _error='ابتدا تنظیمات اتصال سرور را تکمیل کنید.'; });return;}final e=await _service.fetchRecentEvents(limit:500);if(mounted)setState(() { _events=e; _loading=false; _error=null; });}catch(e){if(mounted)setState(() { _loading=false; _error='خطا در دریافت اطلاعات: $e'; });}}
  List<Map<String,dynamic>> _types(Set<String> types)=>_events.where((e)=>types.contains(e['type']?.toString())).toList();
  List<Map<String,dynamic>> _actions(Set<String> actions)=>_events.where((e)=>actions.contains(Map<String,dynamic>.from(e['payload']??{})['action']?.toString())).toList();
  bool _isSpecial(Map<String,dynamic> e){final t=e['type']?.toString()??'';return {'special_invoice_report','special_invoice','invoice_special','special_invoice_created'}.contains(t);}
  bool _isPayroll(Map<String,dynamic> e){final t=e['type']?.toString()??'';return {'payroll_report','payroll','salary_report','salary_payment','payroll_created'}.contains(t);}
  @override void dispose(){_tabs.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    PageHeader(
      title:'ارتباط با سرور و گزارش‌ها',
      icon:Icons.cloud_sync_rounded,
      actions:[ToolbarButton(label:'بروزرسانی',icon:Icons.refresh_rounded,onPressed:_load)],
      bottom:AppTabBar(controller:_tabs,isScrollable:true,tabs:const [Tab(text:'تنظیمات اتصال'),Tab(text:'فروش صندوق‌داران'),Tab(text:'هزینه‌های روزانه'),Tab(text:'گزارش‌های مدیریت'),Tab(text:'فاکتور ویژه'),Tab(text:'حقوق و دستمزد'),Tab(text:'حذف‌ها')]),
    ),
    Expanded(child:TabBarView(controller:_tabs,children:[const ServerSettingsTab(),_list(_actions({'sales_invoice'}),_saleTile),_list(_actions({'daily_expense'}),_expenseTile),_list(_types({'manager_price_change','manager_cheque_action','accounting_report'}),_managerTile),_list(_events.where(_isSpecial).toList(),_editableTile),_list(_events.where(_isPayroll).toList(),_editableTile),_list(_actions({'invoice_deleted','expense_deleted','manifest_deleted'}),_deletionTile)])),
  ]);

  Widget _list(List<Map<String,dynamic>> list,Widget Function(Map<String,dynamic>) tile){if(_loading)return const Center(child:CircularProgressIndicator());if(_error!=null)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(_error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.red))));if(list.isEmpty)return const Center(child:Text('موردی برای نمایش وجود ندارد.'));return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:list.map((e)=>Card(child:tile(e))).toList()));}
  Widget _saleTile(Map<String,dynamic> e){final p=Map<String,dynamic>.from(e['payload']??{});return ListTile(leading:const Icon(Icons.receipt_long,color:Colors.teal),title:Text('صندوق‌دار ${e['actor_name']??''}: فاکتور ${p['invoice_number']??''}'),subtitle:Text('${p['date']??''}\nمبلغ: ${toPersianDigits((p['total']??0).toString())} ریال'),isThreeLine:true);}
  Widget _expenseTile(Map<String,dynamic> e){final p=Map<String,dynamic>.from(e['payload']??{});return ListTile(leading:const Icon(Icons.payments_outlined,color:Colors.orange),title:Text('صندوق‌دار ${e['actor_name']??''}: هزینه «${p['name']??''}»'),subtitle:Text('${p['date']??''}\nمبلغ: ${toPersianDigits((p['amount']??0).toString())} ریال'),isThreeLine:true);}
  Widget _managerTile(Map<String,dynamic> e){final p=Map<String,dynamic>.from(e['payload']??{});return ListTile(leading:const Icon(Icons.admin_panel_settings_outlined,color:Colors.indigo),title:Text('گزارش مدیریت — ${e['actor_name']??''}'),subtitle:Text(p.toString(),maxLines:3,overflow:TextOverflow.ellipsis));}
  Widget _deletionTile(Map<String,dynamic> e){final p=Map<String,dynamic>.from(e['payload']??{});return ListTile(leading:const Icon(Icons.delete_forever,color:Colors.red),title:Text('${p['user_role']=='manager'?'مدیر':'صندوق‌دار'} ${e['actor_name']??''}: ${p['action']??''}'),subtitle:Text('علت: ${p['reason']??'رویداد مالی حذف شد'}'));}
  Widget _editableTile(Map<String,dynamic> e){final p=Map<String,dynamic>.from(e['payload']??{});final title=p['title']?.toString()??p['name']?.toString()??'گزارش مالی';final amount=p['amount']??p['total']??0;return ListTile(leading:Icon(e['type']?.toString().contains('payroll')==true?Icons.badge_outlined:Icons.receipt_long_outlined,color:Colors.deepPurple),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p['date']??''}\nمبلغ: ${toPersianDigits(amount.toString())} ریال\n${p['description']??''}'),isThreeLine:true,trailing:IconButton(tooltip:'ویرایش',icon:const Icon(Icons.edit_outlined),onPressed:()=>_edit(e)));}
  Future<void> _edit(Map<String,dynamic> e) async {final p=Map<String,dynamic>.from(e['payload']??{});final title=TextEditingController(text:(p['title']??p['name']??'').toString());final rawAmt=p['amount']??p['total'];final amount=TextEditingController(text:rawAmt is num?formatMoney(rawAmt.toInt()):(rawAmt??'').toString());final date=TextEditingController(text:(p['date']??'').toString());final desc=TextEditingController(text:(p['description']??'').toString());final ref=TextEditingController(text:(p['reference']??p['invoice_number']??'').toString());final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ویرایش گزارش سرور'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان / نام')),AmountTextField(controller:amount,label:'مبلغ'),TextField(controller:date,decoration:const InputDecoration(labelText:'تاریخ')),TextField(controller:ref,decoration:const InputDecoration(labelText:'مرجع / شماره')),TextField(controller:desc,maxLines:2,decoration:const InputDecoration(labelText:'شرح'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok!=true)return;final updated=Map<String,dynamic>.from(e);final payload=Map<String,dynamic>.from(p);payload['title']=title.text.trim();payload['name']=title.text.trim();payload['amount']=amount.text.trim().isEmpty?'':parseMoney(amount.text);payload['date']=date.text.trim();payload['reference']=ref.text.trim();payload['description']=desc.text.trim();updated['payload']=payload;updated['updated_at']=DateTime.now().toUtc().toIso8601String();final success=await _service.updateFeedItem(e['id'].toString(),updated);if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(success?'گزارش روی سرور به‌روزرسانی شد.':'ویرایش گزارش روی سرور ناموفق بود.')));if(success)_load();}}
}
