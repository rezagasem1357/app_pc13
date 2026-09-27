import 'package:flutter/material.dart';
import '../theme.dart';

/// سربرگ سبز هر صفحه (شبیه نوار عنوان نرم‌افزارهای حسابداری دسکتاپ):
/// عنوان در سمت راست، دکمه‌های ابزار در سمت چپ و در صورت نیاز تب‌ها در پایین.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                      ),
                    ),
                  ],
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
          ),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}

/// دکمه ابزار روی سربرگ سبز؛ با primary=true به رنگ طلایی نمایش داده می‌شود.
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppColors.splashGreen : Colors.white;
    final bg = primary ? AppColors.gold : Colors.white.withOpacity(0.10);
    final style = TextButton.styleFrom(
      foregroundColor: fg,
      backgroundColor: bg,
      disabledForegroundColor: Colors.white38,
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 12, fontWeight: FontWeight.w700),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: icon == null
          ? TextButton(onPressed: onPressed, style: style, child: Text(label))
          : TextButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }
}

/// نوار تب سفید‌رنگ برای قرارگرفتن روی پس‌زمینه سبز (متن تب‌ها سفید است).
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.controller, required this.tabs, this.isScrollable = false});

  final TabController controller;
  final List<Widget> tabs;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      tabAlignment: isScrollable ? TabAlignment.start : null,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: AppColors.gold,
      indicatorWeight: 3,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 12.5, fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 12.5, fontWeight: FontWeight.w500),
      tabs: tabs,
    );
  }
}

/// کادر سفید با حاشیه نازک (جایگزین Cardهای بزرگ و گرد سبک موبایل).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.color = Colors.white});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class GridCol {
  const GridCol(this.title, {this.flex = 1, this.width, this.numeric = false});
  final String title;
  final int flex;
  final double? width;
  final bool numeric;
}

Widget gridText(String s, {bool bold = false, Color? color, double size = 12.5}) {
  return Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color ?? Colors.black87,
    ),
  );
}

Widget statusChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

Widget iconAction({required IconData icon, required String tooltip, required VoidCallback? onPressed, Color? color}) {
  return SizedBox(
    width: 30,
    height: 30,
    child: IconButton(
      padding: EdgeInsets.zero,
      iconSize: 18,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? Colors.black54),
    ),
  );
}

/// جدول داده‌ی فشرده با سربرگ ستون‌ها، ردیف‌های راه‌راه و ردیف جمع در پایین.
class DataGridView extends StatelessWidget {
  const DataGridView({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cellBuilder,
    this.onRowTap,
    this.footer,
    this.emptyText = 'موردی برای نمایش وجود ندارد.',
    this.rowHeight = 38,
  });

  final List<GridCol> columns;
  final int rowCount;
  final List<Widget> Function(int row) cellBuilder;
  final void Function(int row)? onRowTap;
  final List<Widget>? footer;
  final String emptyText;
  final double rowHeight;

  Widget _cells(List<Widget> cells) {
    final children = <Widget>[];
    for (var i = 0; i < columns.length; i++) {
      final c = columns[i];
      final cell = Container(
        alignment: c.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: i < cells.length ? cells[i] : const SizedBox.shrink(),
      );
      children.add(c.width != null ? SizedBox(width: c.width, child: cell) : Expanded(flex: c.flex, child: cell));
    }
    return Row(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.headerFill,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: _cells([
            for (final c in columns)
              Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryGreen),
              ),
          ]),
        ),
        Expanded(
          child: rowCount == 0
              ? Center(child: Text(emptyText, style: const TextStyle(color: Colors.black45)))
              : ListView.builder(
                  itemCount: rowCount,
                  itemExtent: rowHeight,
                  itemBuilder: (context, i) {
                    return Material(
                      color: i.isOdd ? AppColors.zebra : Colors.white,
                      child: InkWell(
                        hoverColor: const Color(0x14185C3A),
                        onTap: onRowTap == null ? null : () => onRowTap!(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE6ECE9))),
                          ),
                          child: _cells(cellBuilder(i)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (footer != null)
          Container(
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.headerFill,
              border: Border(top: BorderSide(color: AppColors.primaryGreen, width: 1.2)),
            ),
            child: _cells(footer!),
          ),
      ],
    );
  }
}

/// کادر آماری کوچک (شمارنده‌ها و جمع‌ها).
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, required this.color, this.icon, this.width = 210});

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
