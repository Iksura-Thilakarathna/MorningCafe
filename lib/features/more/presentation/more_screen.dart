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
    final menuItems = [
      {
        'title': 'Products & Selling Prices',
        'subtitle': 'Manage product catalog, selling prices & price history',
        'icon': Icons.fastfood_outlined,
        'color': AppColors.primary,
        'page': const ProductsScreen(),
      },
      {
        'title': 'Product Recipes',
        'subtitle': 'Formulate recipes and ingredient explosion ratios',
        'icon': Icons.menu_book_outlined,
        'color': AppColors.accentCafe,
        'page': const RecipesScreen(),
      },
      {
        'title': 'Purchases & Stock Inflow',
        'subtitle': 'Record shopping receipts, unit costs & batches',
        'icon': Icons.shopping_bag_outlined,
        'color': AppColors.info,
        'page': const PurchasesScreen(),
      },
      {
        'title': 'Ingredients & Conversions',
        'subtitle': 'Raw materials, units & packaging multipliers',
        'icon': Icons.egg_alt_outlined,
        'color': const Color(0xFFD97706),
        'page': const IngredientsScreen(),
      },
      {
        'title': 'Stock Wastage & Losses',
        'subtitle': 'Record expired, spoiled or spilled ingredients',
        'icon': Icons.delete_outline,
        'color': AppColors.danger,
        'page': const WastageScreen(),
      },
      {
        'title': 'Stock Reconciliation',
        'subtitle': 'Compare physical counts with system stock',
        'icon': Icons.fact_check_outlined,
        'color': const Color(0xFF4F46E5),
        'page': const StockReconciliationScreen(),
      },
      {
        'title': 'Weekly Reports & Statements',
        'subtitle': 'Net Profit, COGS, Cash Flow, PDF & CSV export',
        'icon': Icons.analytics_outlined,
        'color': AppColors.success,
        'page': const ReportsScreen(),
      },
      {
        'title': 'Backup & Restore',
        'subtitle': 'Full JSON database export, share & safe restore',
        'icon': Icons.backup_outlined,
        'color': const Color(0xFF0D9488),
        'page': const BackupScreen(),
      },
      {
        'title': 'Settings & Security',
        'subtitle': 'Business profile, biometric lock & theme mode',
        'icon': Icons.settings_outlined,
        'color': AppColors.secondaryText,
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: menuItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final item = menuItems[idx];
          final color = item['color'] as Color;
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(item['icon'] as IconData, color: color, size: 20),
              ),
              title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(item['subtitle'] as String, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.secondaryText),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'] as Widget));
              },
            ),
          );
        },
      ),
    );
  }
}
