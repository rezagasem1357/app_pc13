import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// کنترل بزرگ‌نمایی (زوم) کل رابط کاربری برنامه. مقدار ۱٫۰ یعنی اندازه‌ی
/// عادی؛ مقادیر بزرگ‌تر همه‌چیز (متن، آیکون‌ها، فاصله‌ها) را با هم بزرگ‌تر
/// نشان می‌دهند تا کاربر بتواند صفحه را واضح‌تر ببیند. مقدار انتخابی کاربر
/// در حافظه‌ی دستگاه ذخیره و در اجرای بعدی برنامه بازیابی می‌شود.
class ZoomController extends ValueNotifier<double> {
  ZoomController(super.value);

  static const double min = 0.85;
  static const double max = 1.5;
  static const double step = 0.1;
  static const _prefsKey = 'ui_zoom_scale';

  static Future<ZoomController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    return ZoomController(saved == null ? 1.0 : saved.clamp(min, max));
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, value);
    } catch (_) {}
  }

  void zoomIn() {
    final v = (value + step).clamp(min, max);
    if (v != value) {
      value = v;
      _persist();
    }
  }

  void zoomOut() {
    final v = (value - step).clamp(min, max);
    if (v != value) {
      value = v;
      _persist();
    }
  }

  void reset() {
    if (value != 1.0) {
      value = 1.0;
      _persist();
    }
  }
}

/// نمونه‌ی سراسری کنترل‌کننده زوم؛ در main() قبل از اجرای برنامه با مقدار
/// ذخیره‌شده از حافظه مقداردهی می‌شود.
final ZoomController zoomController = ZoomController(1.0);
