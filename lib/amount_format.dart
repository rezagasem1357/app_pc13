import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'date_utils.dart';

/// تبدیل ارقام فارسی/عربی به لاتین (بدون تغییر طول رشته تا موقعیت مکان‌نما حفظ شود).
String normalizeDigits(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final sb = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final p = persian.indexOf(ch);
    if (p >= 0) {
      sb.write(p);
      continue;
    }
    final a = arabic.indexOf(ch);
    if (a >= 0) {
      sb.write(a);
      continue;
    }
    sb.write(ch);
  }
  return sb.toString();
}

/// تبدیل متن مبلغ (با یا بدون جداکننده هزارگان، فارسی یا لاتین) به عدد صحیح.
int parseMoney(String text) {
  final digits = normalizeDigits(text).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

/// مبلغ با جداکننده هزارگان (سه رقم سه رقم): 1234567 → 1,234,567
String formatMoney(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return negative ? '-${buf.toString()}' : buf.toString();
}

/// مبلغ با ارقام فارسی و جداکننده هزارگان برای نمایش.
String moneyFa(int value) => toPersianDigits(formatMoney(value));

/// متن اولیه فیلد مبلغ (صفر = خالی).
String amountText(int value) => value == 0 ? '' : formatMoney(value);

/// فرمتر ورودی: هنگام تایپ، هزارگان را خودکار درج می‌کند، ارقام فارسی را به
/// لاتین تبدیل می‌کند و هر نویسه غیرعددی را حذف می‌کند.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  const ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = normalizeDigits(newValue.text);
    var cursor = newValue.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) cursor = text.length;

    var digitsBefore = 0;
    final digitBuf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        digitBuf.write(text[i]);
        if (i < cursor) digitsBefore++;
      }
    }
    var digits = digitBuf.toString();
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    // حذف صفرهای ابتدایی
    final stripped = digits.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
    final removed = digits.length - stripped.length;
    digits = stripped;
    digitsBefore = digitsBefore - removed;
    if (digitsBefore < 0) digitsBefore = 0;
    if (digits.length > 15) return oldValue;

    final formatted = formatMoney(int.parse(digits));
    var pos = 0;
    var seen = 0;
    while (pos < formatted.length && seen < digitsBefore) {
      if (formatted[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

/// فیلد استاندارد مبلغ با هزارگان خودکار.
class AmountTextField extends StatelessWidget {
  const AmountTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '0',
    this.onChanged,
    this.icon,
    this.suffix = 'ریال',
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final ValueChanged<String>? onChanged;
  final IconData? icon;
  final String? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [ThousandsSeparatorFormatter()],
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixText: suffix,
      ),
    );
  }
}
