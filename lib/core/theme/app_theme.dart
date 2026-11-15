import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette (Faithfully derived from Morning Cafe Logo)
  // 1. Deep Espresso / Dark Roasted Coffee
  static const Color primary = Color(0xFF381A0B);
  static const Color primaryDark = Color(0xFF241006);
  static const Color primaryLight = Color(0xFF5E311B);

  // 2. Golden Brioche / Morning Sunburst
  static const Color accentGold = Color(0xFFE5A328);
  static const Color accentGoldLight = Color(0xFFF6CA6B);

  // 3. Savory Paprika Sausage Red-Brown & Steam Orange
  static const Color accentSausage = Color(0xFFA83F1E);
  static const Color accentSteam = Color(0xFFD75C27);
  static const Color accentCafe = Color(0xFFE5A328); // Backward compatibility

  // Text & Background (Warm Artisan Bakery & Cafe)
  static const Color darkText = Color(0xFF2A150A); // Deep Espresso
  static const Color secondaryText = Color(0xFF756256); // Warm Roasted Hazelnut
  static const Color backgroundLight = Color(0xFFFAF7F2); // Warm Cream Linen
  static const Color cardLight = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color surfaceWarm = Color(0xFFF5EEE4); // Warm Latte Tint
  static const Color borderLight = Color(0xFFEADBCE); // Soft Warm Cafe Border

  // Financial Semantics (Harmonized with Warm Palette)
  static const Color success = Color(0xFF1B7A42); // Fresh Herb Emerald (Profit & Income)
  static const Color successBackground = Color(0xFFF0FDF4); // Soft Emerald Tint
  static const Color danger = Color(0xFFBF361B); // Roasted Paprika Red (Expenses & Losses)
  static const Color dangerBackground = Color(0xFFFEF2F2); // Soft Crimson Tint
  static const Color warning = Color(0xFFD97706); // Warm Amber Sun (Wastage & Low Stock)
  static const Color warningBackground = Color(0xFFFFFBEB); // Soft Amber Tint
  static const Color info = Color(0xFF8C533A); // Cinnamon Mocha (Purchases & Capital Assets)
  static const Color infoBackground = Color(0xFFFAF2ED); // Soft Cinnamon Tint

  // Dark Theme Palette (Cozy Evening Cafe)
  static const Color backgroundDark = Color(0xFF160E0A); // Dark Roast Night
  static const Color cardDark = Color(0xFF231712); // Rich Roasted Bean
  static const Color textDark = Color(0xFFFAF3EC); // Steamed Oat Milk White
  static const Color secondaryTextDark = Color(0xFFB5A196); // Warm Biscuit
  static const Color borderDark = Color(0xFF3C281F); // Dark Cocoa Border
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
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.accentGold,
        secondary: AppColors.accentSausage,
        surface: AppColors.cardDark,
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
        indicatorColor: AppColors.accentGold.withValues(alpha: 0.28),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accentGold,
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
          borderSide: const BorderSide(color: AppColors.accentGold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.primaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentGold,
          side: const BorderSide(color: AppColors.accentGold, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentGold,
        foregroundColor: AppColors.primaryDark,
        elevation: 3,
      ),
    );
  }
}
