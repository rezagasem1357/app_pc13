import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'zoom_controller.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loaded = await ZoomController.load();
  zoomController.value = loaded.value;
  runApp(const StoreAccountingApp());
}

class StoreAccountingApp extends StatelessWidget {
  const StoreAccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابداری فروشگاه',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ValueListenableBuilder<double>(
            valueListenable: zoomController,
            builder: (context, scale, cachedChild) {
              final mq = MediaQuery.of(context);
              // ترفند بزرگ‌نمایی: به برنامه اندازه‌ی «منطقی» کوچک‌تر/بزرگ‌تر از
              // اندازه‌ی واقعی صفحه می‌دهیم و سپس با Transform.scale خروجی را
              // به اندازه‌ی واقعی بازمی‌گردانیم؛ در نتیجه همه‌ی اجزا (متن،
              // آیکون، فاصله‌ها، عرض ستون‌ها) با هم بزرگ یا کوچک می‌شوند.
              final logicalSize = mq.size / scale;
              return MediaQuery(
                data: mq.copyWith(size: logicalSize),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: logicalSize.width,
                    height: logicalSize.height,
                    child: cachedChild,
                  ),
                ),
              );
            },
            child: content,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
