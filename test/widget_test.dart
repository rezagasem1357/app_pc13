// تست پایه‌ی برنامه — نسخه پیش‌فرضی که Flutter در ابتدای پروژه می‌سازد به کلاس
// «MyApp» اشاره می‌کند که در این پروژه اصلاً وجود ندارد (کلاس اصلی برنامه
// «StoreAccountingApp» است)، به همین دلیل در flutter analyze خطای واقعی
// می‌داد. این نسخه فقط یک تست دودی (smoke test) ساده است که بررسی می‌کند
// برنامه بدون خطا بالا می‌آید.
import 'package:flutter_test/flutter_test.dart';

import 'package:store_accounting_desktop/main.dart';

void main() {
  testWidgets('برنامه بدون خطا اجرا می‌شود', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreAccountingApp());
    // فقط یک فریم رندر می‌کنیم؛ چون بعد از آن تایمر ۲ثانیه‌ای اسپلش صفحه را
    // عوض می‌کند و در محیط تست نیازی به منتظرماندن برای آن نیست.
    await tester.pump();
  });
}
