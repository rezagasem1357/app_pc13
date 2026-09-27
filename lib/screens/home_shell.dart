import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../storage.dart';
import '../models.dart';
import '../date_utils.dart';
import '../zoom_controller.dart';
import 'voucher_list_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'server_reports_screen.dart';
import 'receipts_payments_screen.dart';
import 'backup_screen.dart';
import 'expenses_screen.dart';
import 'persons_screen.dart';

/// پوسته اصلی اپ: یک نوار کناری ثابت (شبیه منوی سپیدار) + لوگوی فروشگاه در
/// بالای نوار کناری + محتوای صفحه انتخاب‌شده در کنار آن.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.userRole});

  final String userRole;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  String _storeName = 'فروشگاه';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppStorage().loadStoreName().then((n) {
      if (mounted) setState(() => _storeName = n);
    });
  }

  // ترتیب این لیست باید دقیقاً با شماره‌های منوی کناری یکی باشد.
  // قبلاً ترتیب متفاوت بود و باعث می‌شد هر گزینه صفحه گزینه دیگری را باز کند.
  final _pages = const [
    _DashboardBody(),            // 0 داشبورد
    VoucherListScreen(),         // 1 اسناد حسابداری
    ReceiptsPaymentsScreen(),    // 2 دریافت و پرداخت
    ChartOfAccountsScreen(),     // 3 حساب‌ها
    ReportsScreen(),             // 4 گزارش‌ها
    ServerReportsScreen(),       // 5 ارتباط با سرور
    BackupScreen(),              // 6 پشتیبان‌گیری
    SettingsScreen(),            // 7 تنظیمات
    ExpensesScreen(),             // 8 هزینه‌ها و مراکز هزینه
    PersonsScreen(),              // 9 اشخاص و طرف‌حساب‌ها
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1050;
    final sidebarWidth = wide ? 216.0 : 68.0;

    // نکته مهم: چون کل برنامه راست‌چین (RTL) است، در ویجت Row اولین فرزند در
    // سمت راست صفحه قرار می‌گیرد. بنابراین نوار ابزار/منو باید اولین فرزند
    // این Row باشد تا طبق درخواست کاربر، در سمت راست صفحه نمایش داده شود.
    final sidebar = Container(
      width: sidebarWidth,
      color: AppColors.primaryGreen,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
                image: const DecorationImage(image: AssetImage('assets/images/logo.png'), fit: BoxFit.cover),
              ),
            ),
            if (wide) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _storeName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 3),
              Text(widget.userRole, style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1, indent: 12, endIndent: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  _SideItem(index: 0, icon: Icons.dashboard_rounded, label: 'داشبورد', shortcut: 'Esc', selected: _selected == 0, wide: wide, onTap: _select),
                  _SideItem(index: 1, icon: Icons.receipt_long_rounded, label: 'اسناد حسابداری', shortcut: 'F2', selected: _selected == 1, wide: wide, onTap: _select),
                  _SideItem(index: 2, icon: Icons.swap_vert_rounded, label: 'دریافت و پرداخت', shortcut: 'F8', selected: _selected == 2, wide: wide, onTap: _select),
                  _SideItem(index: 3, icon: Icons.account_tree_rounded, label: 'حساب‌ها', shortcut: 'F3', selected: _selected == 3, wide: wide, onTap: _select),
                  _SideItem(index: 4, icon: Icons.bar_chart_rounded, label: 'گزارش‌ها', shortcut: 'F4', selected: _selected == 4, wide: wide, onTap: _select),
                  _SideItem(index: 5, icon: Icons.cloud_sync_rounded, label: 'ارتباط با سرور', shortcut: 'F5', selected: _selected == 5, wide: wide, onTap: _select),
                  _SideItem(index: 6, icon: Icons.backup_outlined, label: 'پشتیبان‌گیری', shortcut: 'F6', selected: _selected == 6, wide: wide, onTap: _select),
                  _SideItem(index: 7, icon: Icons.settings_rounded, label: 'تنظیمات', shortcut: 'F7', selected: _selected == 7, wide: wide, onTap: _select),
                  _SideItem(index: 8, icon: Icons.payments_outlined, label: 'هزینه‌ها و مراکز هزینه', shortcut: 'F9', selected: _selected == 8, wide: wide, onTap: _select),
                  _SideItem(index: 9, icon: Icons.groups_outlined, label: 'اشخاص و طرف‌حساب‌ها', shortcut: 'F10', selected: _selected == 9, wide: wide, onTap: _select),
                ],
              ),
            ),
            if (wide)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text('نسخه ویندوز', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 9.5)),
              ),
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _selected = 0),
          const SingleActivator(LogicalKeyboardKey.f2): () => setState(() => _selected = 1),
          const SingleActivator(LogicalKeyboardKey.f3): () => setState(() => _selected = 3),
          const SingleActivator(LogicalKeyboardKey.f4): () => setState(() => _selected = 4),
          const SingleActivator(LogicalKeyboardKey.f5): () => setState(() => _selected = 5),
          const SingleActivator(LogicalKeyboardKey.f6): () => setState(() => _selected = 6),
          const SingleActivator(LogicalKeyboardKey.f7): () => setState(() => _selected = 7),
          const SingleActivator(LogicalKeyboardKey.f8): () => setState(() => _selected = 2),
          const SingleActivator(LogicalKeyboardKey.f9): () => setState(() => _selected = 8),
          const SingleActivator(LogicalKeyboardKey.f10): () => setState(() => _selected = 9),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.equal, control: true): zoomController.zoomIn,
          const SingleActivator(LogicalKeyboardKey.add, control: true): zoomController.zoomIn,
          const SingleActivator(LogicalKeyboardKey.minus, control: true): zoomController.zoomOut,
          const SingleActivator(LogicalKeyboardKey.digit0, control: true): zoomController.reset,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F4F3),
            body: Row(
              children: [
                sidebar,
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(storeName: _storeName, role: widget.userRole, searchController: _searchController, searchFocus: _searchFocus),
                      Expanded(
                        child: IndexedStack(index: _selected, children: _pages),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _selected = index);

}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.storeName, required this.role, required this.searchController, required this.searchFocus});
  final String storeName;
  final String role;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDDE7E3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                textDirection: TextDirection.rtl,
                readOnly: true,
                onTap: () async { final r = await showSearch<String>(context: context, delegate: _GlobalSearchDelegate()); if (!context.mounted || r == null) return; final page = r == 'persons' ? const PersonsScreen() : r == 'accounts' ? const ChartOfAccountsScreen() : const VoucherListScreen(); Navigator.push(context, MaterialPageRoute(builder: (_) => page)); },
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'جستجو: شخص، حساب، شماره سند، شرح، مرجع...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  suffixText: 'Ctrl+F',
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _ZoomControls(),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 15,
            backgroundColor: Color(0xFFE3EEE8),
            child: Icon(Icons.person_outline_rounded, size: 17, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(role, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
              Text(storeName, style: const TextStyle(color: Colors.black45, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: zoomController,
      builder: (context, scale, _) {
        final percent = toPersianDigits((scale * 100).round().toString());
        return Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDDE7E3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomBtn(
                icon: Icons.remove_rounded,
                tooltip: 'کوچک‌نمایی (Ctrl+-)',
                onPressed: scale > ZoomController.min ? zoomController.zoomOut : null,
              ),
              InkWell(
                onTap: zoomController.reset,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Tooltip(
                    message: 'بازنشانی بزرگ‌نمایی (Ctrl+0)',
                    child: Text('٪$percent', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                  ),
                ),
              ),
              _zoomBtn(
                icon: Icons.add_rounded,
                tooltip: 'بزرگ‌نمایی (Ctrl++)',
                onPressed: scale < ZoomController.max ? zoomController.zoomIn : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _zoomBtn({required IconData icon, required String tooltip, required VoidCallback? onPressed}) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 15,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.index, required this.icon, required this.label, required this.shortcut, required this.selected, required this.wide, required this.onTap});
  final int index;
  final IconData icon;
  final String label;
  final String shortcut;
  final bool selected;
  final bool wide;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? Colors.white.withOpacity(.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => onTap(index),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 8, vertical: 9),
            child: Row(
              mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? AppColors.gold : Colors.white70, size: 18),
                if (wide) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(.14)),
                    ),
                    child: Text(shortcut, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalSearchDelegate extends SearchDelegate<String> {
  final AppStorage _storage = AppStorage();
  _GlobalSearchDelegate() : super(searchFieldLabel: 'جستجو در کل سیستم');
  @override List<Widget>? buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,''),icon:const Icon(Icons.arrow_back));
  Future<List<_SearchHit>> _hits() async {
    final q=query.trim().toLowerCase(); if(q.isEmpty)return [];
    final accounts=await _storage.loadAccounts(); final vouchers=await _storage.loadVouchers(); final persons=await _storage.loadPersons(); final out=< _SearchHit>[];
    for(final p in persons){if('${p.name} ${p.nationalId} ${p.phone} ${p.code}'.toLowerCase().contains(q))out.add(_SearchHit('شخص',p.name,p.typeLabel,const Icon(Icons.person_outline),'persons'));}
    for(final a in accounts){if('${a.code} ${a.name}'.toLowerCase().contains(q))out.add(_SearchHit('حساب',a.name,a.code,const Icon(Icons.account_tree_outlined),'accounts'));}
    for(final v in vouchers){if('${v.number} ${v.date} ${v.description} ${v.reference} ${voucherTypeLabel(v.type)}'.toLowerCase().contains(q))out.add(_SearchHit('سند', 'سند ${v.number} — ${voucherTypeLabel(v.type)}', '${v.date} • ${v.description}',const Icon(Icons.receipt_long_outlined),'vouchers'));}
    return out.take(30).toList();
  }
  @override Widget buildResults(BuildContext context)=>FutureBuilder<List<_SearchHit>>(future:_hits(),builder:(c,s)=>s.connectionState!=ConnectionState.done?const Center(child:CircularProgressIndicator()):_SearchList(items:s.data??[],close:(value)=>close(context,value)));
  @override Widget buildSuggestions(BuildContext context)=>buildResults(context);
}
class _SearchHit { final String kind,title,subtitle,target; final Icon icon; _SearchHit(this.kind,this.title,this.subtitle,this.icon,this.target); }
class _SearchList extends StatelessWidget {
  final List<_SearchHit> items;
  final void Function(String) close;

  const _SearchList({required this.items, required this.close});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final h = items[index];
        return ListTile(
          leading: CircleAvatar(child: h.icon),
          title: Row(
            children: [
              Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Chip(label: Text(h.kind)),
            ],
          ),
          subtitle: Text(h.subtitle),
          onTap: () => close(h.target),
        );
      },
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _storage = AppStorage();
  int _temporaryCount = 0;
  int _permanentCount = 0;
  int _accountsCount = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final vouchers = await _storage.loadVouchers();
    final accounts = await _storage.loadAccounts();
    if (!mounted) return;
    setState(() {
      _temporaryCount = vouchers.where((v) => v.status == VoucherStatus.temporary).length;
      _permanentCount = vouchers.where((v) => v.status == VoucherStatus.permanent).length;
      _accountsCount = accounts.where((a) => a.level == AccountLevel.tafsili).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              children: [
                const Text('داشبورد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('خلاصه وضعیت سیستم حسابداری', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 1150 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
                  final width = (c.maxWidth - (columns - 1) * 14) / columns;
                  final cards = [
                    _QuickCard(title: 'فاکتور فروش', icon: Icons.receipt_long_rounded, color: const Color(0xFF19A974), subtitle: 'ثبت و مشاهده اسناد فروش', onTap: () => _open(context, const VoucherListScreen())),
                    _QuickCard(title: 'دریافت', icon: Icons.file_download_outlined, color: const Color(0xFF3478D5), subtitle: 'ثبت عملیات دریافت', onTap: () => _open(context, const ReceiptsPaymentsScreen())),
                    _QuickCard(title: 'پرداخت', icon: Icons.file_upload_outlined, color: const Color(0xFFE9545D), subtitle: 'ثبت عملیات پرداخت', onTap: () => _open(context, const ReceiptsPaymentsScreen())),
                    _QuickCard(title: 'کالا و انبار', icon: Icons.inventory_2_outlined, color: const Color(0xFF7A55D5), subtitle: 'مدیریت اطلاعات کالا', onTap: () => _comingSoon(context, 'کالا و انبار')),
                    _QuickCard(title: 'اشخاص', icon: Icons.groups_outlined, color: const Color(0xFFF0AA21), subtitle: 'مدیریت طرف حساب‌ها', onTap: () => _comingSoon(context, 'اشخاص')),
                    _QuickCard(title: 'گزارش‌ها', icon: Icons.bar_chart_rounded, color: const Color(0xFF20AEB2), subtitle: 'گزارش‌های مالی و مدیریتی', onTap: () => _comingSoon(context, 'گزارش‌ها')),
                    _QuickCard(title: 'حساب‌ها', icon: Icons.menu_book_rounded, color: const Color(0xFF5270D4), subtitle: 'درخت حساب‌های حسابداری', onTap: () => _open(context, const ChartOfAccountsScreen())),
                    _QuickCard(title: 'ارتباط با سرور', icon: Icons.account_balance_outlined, color: const Color(0xFF2CA9A9), subtitle: 'همگام‌سازی و ارتباط شبکه', onTap: () => _open(context, const ServerReportsScreen())),
                    _QuickCard(title: 'پشتیبان‌گیری', icon: Icons.backup_outlined, color: const Color(0xFF6C63CE), subtitle: 'ذخیره و بازیابی اطلاعات', onTap: () => _open(context, const BackupScreen())),
                    _QuickCard(title: 'تنظیمات', icon: Icons.settings_rounded, color: const Color(0xFF8293A0), subtitle: 'تنظیمات نرم‌افزار', onTap: () => _open(context, const SettingsScreen())),
                  ];
                  return Wrap(spacing: 10, runSpacing: 10, children: cards.map((e) => SizedBox(width: width, child: e)).toList());
                }),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryCard(title: 'اسناد موقت', value: _temporaryCount, icon: Icons.pending_actions_rounded, color: const Color(0xFFF0A12B)),
                    _SummaryCard(title: 'اسناد دائم', value: _permanentCount, icon: Icons.verified_rounded, color: const Color(0xFF19A974)),
                    _SummaryCard(title: 'حساب‌های تفصیلی', value: _accountsCount, icon: Icons.account_tree_rounded, color: const Color(0xFF3478D5)),
                    _SummaryCard(title: 'وضعیت سیستم', valueText: 'فعال', icon: Icons.check_circle_rounded, color: const Color(0xFF20AEB2)),
                  ],
                ),
              ],
            ),
          );
  }

  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
  void _comingSoon(BuildContext context, String name) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بخش «$name» در نسخه فعلی در حال توسعه است.')));
}

class _QuickCard extends StatefulWidget {
  const _QuickCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: hover ? widget.color.withOpacity(.45) : const Color(0xFFD5DEDA)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(6)), child: Icon(widget.icon, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text(widget.subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.black45))])),
              Icon(Icons.chevron_left_rounded, size: 18, color: widget.color),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, this.value, this.valueText, required this.icon, required this.color});
  final String title;
  final int? value;
  final String? valueText;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD5DEDA))),
      child: Row(children: [
        Icon(icon, color: color, size: 22), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.black54)), const SizedBox(height: 3), Text(valueText ?? toPersianDigits((value ?? 0).toString()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color))]),
      ]),
    );
  }
}
