import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const HomeNavigationScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};

  void _onTabSelected(int idx) {
    setState(() {
      _currentIndex = idx;
      _loadedTabs.add(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? AppColors.highlightYellow : AppColors.primary;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _loadedTabs.contains(0)
              ? DashboardScreen(onNavigateTab: _onTabSelected)
              : const SizedBox.shrink(),
          _loadedTabs.contains(1)
              ? const SalesScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(2)
              ? const InventoryScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(3)
              ? const FinanceScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(4)
              ? MoreScreen(
                  currentThemeMode: widget.currentThemeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                )
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: selectedColor),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: selectedColor),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: selectedColor),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: selectedColor),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: selectedColor),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
