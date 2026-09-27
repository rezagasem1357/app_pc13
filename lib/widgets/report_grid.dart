import 'package:flutter/material.dart';
import '../report_engine.dart';
import '../theme.dart';
import 'desktop_widgets.dart';

/// نمایش جدولی یک گزارش روی صفحه (همان داده‌ای که در PDF چاپ می‌شود).
class ReportGrid extends StatelessWidget {
  const ReportGrid({super.key, required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final cols = data.columns;

    Widget rowOf(List<String> cells, {required TextStyle style, int depth = 0}) {
      return Row(
        children: [
          for (var i = 0; i < cols.length; i++)
            Expanded(
              flex: cols[i].flex,
              child: Container(
                alignment: cols[i].numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                padding: EdgeInsetsDirectional.only(
                  start: 10 + (i == data.nameColumn ? depth * 18.0 : 0),
                  end: 10,
                ),
                child: Text(
                  i < cells.length ? cells[i] : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
        ],
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: rowOf(
              [for (final c in cols) c.title],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(
            child: data.rows.isEmpty
                ? const Center(child: Text('موردی برای نمایش وجود ندارد.', style: TextStyle(color: Colors.black45)))
                : ListView.builder(
                    itemCount: data.rows.length,
                    itemBuilder: (context, i) {
                      final r = data.rows[i];
                      switch (r.kind) {
                        case RowKind.section:
                          return Container(
                            height: 32,
                            color: AppColors.headerFill,
                            alignment: AlignmentDirectional.centerStart,
                            padding: const EdgeInsetsDirectional.only(start: 10),
                            child: Text(
                              r.cells.isEmpty ? '' : r.cells.first,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: AppColors.primaryGreen),
                            ),
                          );
                        case RowKind.total:
                          return Container(
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.headerFill,
                              border: Border(top: BorderSide(color: AppColors.primaryGreen, width: 1.2)),
                            ),
                            child: rowOf(r.cells, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                          );
                        case RowKind.group:
                          return Container(
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F7F4),
                              border: Border(bottom: BorderSide(color: Color(0xFFE6ECE9))),
                            ),
                            child: rowOf(r.cells, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          );
                        case RowKind.normal:
                          return Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: i.isOdd ? AppColors.zebra : Colors.white,
                              border: const Border(bottom: BorderSide(color: Color(0xFFE6ECE9))),
                            ),
                            child: rowOf(
                              r.cells,
                              depth: r.depth,
                              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                            ),
                          );
                      }
                    },
                  ),
          ),
          if (data.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: data.statusOk ? const Color(0xFFEAF6EF) : const Color(0xFFFDECEA),
                border: const Border(top: BorderSide(color: AppColors.border)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
              ),
              child: Row(
                children: [
                  Icon(
                    data.statusOk ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 18,
                    color: data.statusOk ? const Color(0xFF137A4B) : const Color(0xFFB42318),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.status!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: data.statusOk ? const Color(0xFF137A4B) : const Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
