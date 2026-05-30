import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Paleta Premium Dark Navy ───────────────────────────
  static const Color bgPrimary   = Color(0xFF080C14);  // Deep dark navy
  static const Color bgSecondary = Color(0xFF0F1623);  // Dark navy surface
  static const Color bgCard      = Color(0xFF131C2E);  // Navy card
  static const Color borderColor = Color(0xFF1A2538);  // Navy border
  static const Color accentLime  = Color(0xFFC8FF32);  // Vibrant lime
  static const Color accentCyan  = Color(0xFF00E5FF);
  static const Color textPrimary = Color(0xFFE8EDF5);  // Cool off-white
  static const Color textMuted   = Color(0xFF7A8BA8);  // Readable blue-gray
  static const Color incomeGreen = Color(0xFF1ED97C);
  static const Color expenseRed  = Color(0xFFFF3D57);
  static const Color usdColor    = Color(0xFF4ADE80);
  static const Color mxnColor    = Color(0xFFFB923C);

  static ThemeData get darkTheme {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final base = ThemeData.dark(useMaterial3: true);
    final tt   = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: bgPrimary,
      textTheme: tt.copyWith(
        displayLarge: tt.displayLarge?.copyWith(
            color: textPrimary, fontWeight: FontWeight.w900, letterSpacing: -1.5),
        headlineLarge: tt.headlineLarge?.copyWith(
            color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: tt.headlineMedium?.copyWith(
            color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge: tt.titleLarge?.copyWith(
            color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: tt.titleMedium?.copyWith(
            color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge:  tt.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: tt.bodyMedium?.copyWith(color: textMuted),
        labelSmall: tt.labelSmall?.copyWith(
            color: textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w700),
      ),
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        surface:     bgSecondary,
        primary:     accentLime,
        onPrimary:   Colors.black,
        secondary:   accentCyan,
        onSecondary: Colors.black,
        error:       expenseRed,
        onSurface:   textPrimary,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentLime, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor, thickness: 1, space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentLime,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textMuted),
      ),
    );
  }
}
