import 'package:flutter/material.dart';

/// تم نرم‌افزار: رنگ‌ها و فونت هم‌خوان با اپ موبایل (Vazir + سبز تیره #185C3A)،
/// اما با ابعاد فشرده و حرفه‌ای مخصوص نرم‌افزارهای دسکتاپ حسابداری.
class AppColors {
  static const primaryGreen = Color(0xFF185C3A);
  static const splashGreen = Color(0xFF12462D);
  static const gold = Color(0xFFD6B65A);
  static const darkGreen = Color(0xFF2D7B54);
  static const border = Color(0xFFD5DEDA);
  static const surface = Color(0xFFF1F4F3);
  static const headerFill = Color(0xFFE3EEE8);
  static const zebra = Color(0xFFF8FAF9);
}

ThemeData buildAppTheme() {
  const radius = 4.0;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Vazir',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
    ),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: 'Vazir', fontSize: 13.5, height: 1.5),
      bodyMedium: TextStyle(fontFamily: 'Vazir', fontSize: 12.5, height: 1.45),
      bodySmall: TextStyle(fontFamily: 'Vazir', fontSize: 11.5, height: 1.4),
      titleLarge: TextStyle(fontFamily: 'Vazir', fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontFamily: 'Vazir', fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontFamily: 'Vazir', fontSize: 12.5, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(fontFamily: 'Vazir', fontSize: 12.5, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontFamily: 'Vazir', fontSize: 11.5, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 46,
      iconTheme: IconThemeData(color: Colors.white, size: 20),
      titleTextStyle: TextStyle(
        fontFamily: 'Vazir',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      labelStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 12.5),
      hintStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 12.5, color: Colors.black38),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: const TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: const TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(72, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: const TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: const TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 460,
      contentTextStyle: TextStyle(fontFamily: 'Vazir', fontSize: 12.5),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 0.6, color: AppColors.border),
  );
}
