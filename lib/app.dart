import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/splash/splash_gate.dart';

ThemeData _buildTheme() {
  const primary = Color(0xFFF76D20);
  final base = ThemeData(
    fontFamily: 'BalooBhaijaan2',
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF2C2C2C),
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF6E6E6E)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}

class RoutexApp extends StatelessWidget {
  const RoutexApp({super.key});

  @override
  Widget build(BuildContext context) {
    // أي Widget ينهار -> اعرض رسالة واضحة بدلاً من شاشة بيضاء
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'حدث خطأ غير متوقع:\n${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false, // ⬅️ يخفي شارة DEBUG
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(),
      // لو فيه خطأ أثناء بناء أي شاشة، builder هيمسكه برضه
      builder: (context, child) {
        try {
          return child!;
        } catch (e) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: Text(
                'خطأ أثناء بناء الواجهة: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
      },
      home: const SplashGate(),
    );
  }
}

