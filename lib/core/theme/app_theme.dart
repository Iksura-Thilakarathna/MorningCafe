import 'package:flutter/material.dart';

class AppColors {
  // Brand Foundation (Morning Cafe Logo)
  static const Color primary = Color(0xFF381A0B); // Deep Roast Espresso
  static const Color primaryDark = Color(0xFF241006); // Dark Mocha
  static const Color primaryLight = Color(0xFF5E311B); // Warm Roast

  // Brand Accents
  static const Color accentGold = Color(0xFFE5A328); // Golden Brioche Bun & Sunburst
  static const Color accentGoldLight = Color(0xFFF6CA6B);
  static const Color accentSausage = Color(0xFFA83F1E); // Savory Paprika Sausage
  static const Color accentSteam = Color(0xFFD75C27); // Warm Steam Orange
  static const Color accentCafe = Color(0xFFE5A328); // Backward compatibility

  // VIBRANT HIGHLIGHT COLORS (High-contrast, glowing in Dark Mode)
  static const Color highlightYellow = Color(0xFFFBBF24); // Glowing Amber Gold
  static const Color highlightOrange = Color(0xFFFB923C); // Bright Paprika Flame
  static const Color highlightGreen = Color(0xFF22C55E); // Electric Emerald Green
  static const Color highlightRed = Color(0xFFF87171); // Soft Coral Red
  static const Color highlightCream = Color(0xFFFAF3EC); // Crisp Oat Milk White

  // Surfaces & Backgrounds (Light Theme - Warm Artisan Linen)
  static const Color backgroundLight = Color(0xFFFAF7F2); // Warm Cream Linen
  static const Color cardLight = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color surfaceWarm = Color(0xFFF5EEE4); // Warm Latte Tint
  static const Color borderLight = Color(0xFFEADBCE); // Soft Warm Cafe Border
  static const Color darkText = Color(0xFF2A150A); // Deep Espresso
  static const Color secondaryText = Color(0xFF756256); // Warm Roasted Hazelnut

  // Financial Semantics (Light Mode)
  static const Color success = Color(0xFF1B7A42); // Fresh Herb Emerald
  static const Color successBackground = Color(0xFFF0FDF4); // Soft Emerald Tint
  static const Color danger = Color(0xFFBF361B); // Roasted Paprika Red
  static const Color dangerBackground = Color(0xFFFEF2F2); // Soft Crimson Tint
  static const Color warning = Color(0xFFD97706); // Warm Amber Sun
  static const Color warningBackground = Color(0xFFFFFBEB); // Soft Amber Tint
  static const Color info = Color(0xFF8C533A); // Cinnamon Mocha
  static const Color infoBackground = Color(0xFFFAF2ED); // Soft Cinnamon Tint

  // Surfaces & Backgrounds (Dark Theme - Rich Roasted Espresso Night)
  static const Color backgroundDark = Color(0xFF140D09); // Deep Roasted Espresso
  static const Color cardDark = Color(0xFF221610); // Rich Roasted Bean Card
  static const Color surfaceWarmDark = Color(0xFF2B1C15); // Subtle Warm Dark Tint
  static const Color textDark = Color(0xFFFAF3EC); // Steamed Oat Milk White
  static const Color secondaryTextDark = Color(0xFFB5A196); // Warm Biscuit Grey
  static const Color borderDark = Color(0xFF38251C); // Subtle Dark Cocoa Border

  // Financial Semantics (Dark Mode Backgrounds)
  static const Color darkSuccessBackground = Color(0xFF12281B); // Deep Forest Emerald
  static const Color darkDangerBackground = Color(0xFF2D1210); // Deep Dark Crimson
  static const Color darkWarningBackground = Color(0xFF2D1C0E); // Deep Dark Amber
  static const Color darkInfoBackground = Color(0xFF281912); // Deep Dark Mocha

  // Dynamic Helpers based on Brightness
  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textDark : darkText;

  static Color subtext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? secondaryTextDark : secondaryText;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;

  static Color profit(BuildContext context, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (amount >= 0) {
      return isDark ? highlightGreen : success;
    } else {
      return isDark ? highlightRed : danger;
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.accentGold,
        tertiary: AppColors.accentSausage,
        surface: AppColors.cardLight,
        onSurface: AppColors.darkText,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardLight,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        elevation: 2,
        indicatorColor: AppColors.accentGold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        backgroundColor: AppColors.cardLight,
        selectedColor: AppColors.accentGold.withValues(alpha: 0.22),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.darkText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardLight,
        elevation: 6,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentGold,
        brightness: Brightness.dark,
        primary: AppColors.highlightYellow,
        secondary: AppColors.highlightOrange,
        tertiary: AppColors.highlightGreen,
        surface: AppColors.cardDark,
        onSurface: AppColors.textDark,
        onPrimary: AppColors.primaryDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        elevation: 2,
        indicatorColor: AppColors.highlightYellow.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.highlightYellow,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryTextDark,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.highlightYellow, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlightYellow,
          foregroundColor: const Color(0xFF160E0A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.highlightYellow,
          side: const BorderSide(color: AppColors.highlightYellow, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.highlightYellow,
        foregroundColor: Color(0xFF160E0A),
        elevation: 3,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        backgroundColor: AppColors.cardDark,
        selectedColor: AppColors.highlightYellow.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textDark),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDark,
        elevation: 6,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.secondaryTextDark,
          fontSize: 14,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.highlightYellow,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
