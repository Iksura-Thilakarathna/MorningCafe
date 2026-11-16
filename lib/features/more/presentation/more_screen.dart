import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../ingredients/presentation/ingredients_screen.dart';
import '../../inventory/presentation/stock_reconciliation_screen.dart';
import '../../products/presentation/products_screen.dart';
import '../../purchases/presentation/purchases_screen.dart';
import '../../recipes/presentation/recipes_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../wastage/presentation/wastage_screen.dart';

class MoreScreen extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const MoreScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final menuItems = [
      {
        'title': 'Products & Selling Prices',
        'subtitle': 'Manage product catalog, selling prices & price history',
        'icon': Icons.fastfood_outlined,
        'color': isDark ? AppColors.highlightOrange : AppColors.accentSausage,
        'page': const ProductsScreen(),
      },
      {
        'title': 'Product Recipes',
        'subtitle': 'Formulate recipes and ingredient explosion ratios',
        'icon': Icons.menu_book_outlined,
        'color': isDark ? AppColors.highlightYellow : AppColors.accentGold,
        'page': const RecipesScreen(),
      },
      {
        'title': 'Purchases & Stock Inflow',
        'subtitle': 'Record shopping receipts, unit costs & batches',
        'icon': Icons.shopping_bag_outlined,
        'color': isDark ? AppColors.highlightYellow : AppColors.info,
        'page': const PurchasesScreen(),
      },
      {
        'title': 'Ingredients & Conversions',
        'subtitle': 'Raw materials, units & packaging multipliers',
        'icon': Icons.egg_alt_outlined,
        'color': isDark ? AppColors.highlightOrange : AppColors.warning,
        'page': const IngredientsScreen(),
      },
      {
        'title': 'Stock Wastage & Losses',
        'subtitle': 'Record expired, spoiled or spilled ingredients',
        'icon': Icons.delete_outline,
        'color': isDark ? AppColors.highlightRed : AppColors.danger,
        'page': const WastageScreen(),
      },
      {
        'title': 'Stock Reconciliation',
        'subtitle': 'Compare physical counts with system stock',
        'icon': Icons.fact_check_outlined,
        'color': isDark ? AppColors.highlightYellow : AppColors.primary,
        'page': const StockReconciliationScreen(),
      },
      {
        'title': 'Weekly Reports & Statements',
        'subtitle': 'Net Profit, COGS, Cash Flow, PDF & CSV export',
        'icon': Icons.analytics_outlined,
        'color': isDark ? AppColors.highlightGreen : AppColors.success,
        'page': const ReportsScreen(),
      },
      {
        'title': 'Backup & Restore',
        'subtitle': 'Full JSON database export, share & safe restore',
        'icon': Icons.backup_outlined,
        'color': isDark ? AppColors.highlightOrange : AppColors.info,
        'page': const BackupScreen(),
      },
      {
        'title': 'Settings & Security',
        'subtitle': 'Business profile, biometric lock & theme mode',
        'icon': Icons.settings_outlined,
        'color': isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
        'page': SettingsScreen(
          currentThemeMode: currentThemeMode,
          onThemeModeChanged: onThemeModeChanged,
        ),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Operations'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Morning Cafe Brand Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Morning Cafe',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: isDark ? AppColors.highlightYellow : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Piliyandala, Sri Lanka',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sausage Buns & Omelette Burgers',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.highlightOrange : AppColors.accentSausage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...menuItems.map((item) {
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: isDark ? 0.22 : 0.12),
                    child: Icon(item['icon'] as IconData, color: color, size: 20),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.textDark : AppColors.darkText,
                    ),
                  ),
                  subtitle: Text(
                    item['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'] as Widget));
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
