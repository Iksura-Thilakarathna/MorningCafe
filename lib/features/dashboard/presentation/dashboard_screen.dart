import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../finance/data/finance_service.dart';
import '../../inventory/data/inventory_service.dart';
import '../../purchases/presentation/purchases_screen.dart';
import '../../sales/presentation/sales_screen.dart';
import '../../wastage/presentation/wastage_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FinanceService _financeService = FinanceService();
  final InventoryService _inventoryService = InventoryService();

  String _filter = 'Last 7 Days';
  late String _startDate;
  late String _endDate;
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  List<Map<String, dynamic>> _inventoryData = [];

  @override
  void initState() {
    super.initState();
    _applyFilter('Last 7 Days');
  }

  void _applyFilter(String filter) {
    _filter = filter;
    final now = DateTime.now();
    final todayStr = Formatters.date(now);

    switch (filter) {
      case 'Today':
        _startDate = todayStr;
        _endDate = todayStr;
        break;
      case 'Yesterday':
        final yest = now.subtract(const Duration(days: 1));
        _startDate = Formatters.date(yest);
        _endDate = Formatters.date(yest);
        break;
      case 'Last 7 Days':
        final sevenDaysAgo = now.subtract(const Duration(days: 6));
        _startDate = Formatters.date(sevenDaysAgo);
        _endDate = todayStr;
        break;
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        _startDate = Formatters.date(monday);
        _endDate = todayStr;
        break;
      case 'Previous Week':
        final lastMonday = now.subtract(Duration(days: now.weekday + 6));
        final lastSunday = lastMonday.add(const Duration(days: 6));
        _startDate = Formatters.date(lastMonday);
        _endDate = Formatters.date(lastSunday);
        break;
    }

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final report = await _financeService.calculate(_startDate, _endDate);
      final inventory = await _inventoryService.getInventoryDashboard();
      if (mounted) {
        setState(() {
          _reportData = report;
          _inventoryData = inventory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Morning Cafe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${Formatters.displayDate(_startDate)} - ${Formatters.displayDate(_endDate)}',
              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterBar(),
                    const SizedBox(height: 14),
                    _buildQuickActionButtons(),
                    const SizedBox(height: 16),
                    _buildSummaryCards(),
                    const SizedBox(height: 20),
                    _buildChartsSection(),
                    const SizedBox(height: 20),
                    _buildWarningsSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Today', 'Yesterday', 'Last 7 Days', 'This Week', 'Previous Week'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              onSelected: (val) {
                if (val) _applyFilter(f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale, size: 18),
            label: const Text('Record Sales'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
              _loadDashboardData();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text('New Purchase'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()));
              _loadDashboardData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    if (_reportData == null) return const SizedBox.shrink();
    final d = _reportData!;

    final netProfit = (d['net_profit'] as num).toDouble();
    final salesRev = (d['sales_revenue'] as num).toDouble();
    final grossProfit = (d['gross_profit'] as num).toDouble();
    final expenses = (d['operating_expenses'] as num).toDouble();
    final wastage = (d['wastage_cost'] as num).toDouble();
    final purchases = (d['total_purchases'] as num).toDouble();
    final closingStock = (d['closing_inventory_value'] as num).toDouble();
    final netCashFlow = (d['net_cash_flow'] as num).toDouble();
    final profitMargin = (d['profit_margin'] as num).toDouble();

    return Column(
      children: [
        // Highlight Card: OPERATIONAL NET PROFIT (Prominent)
        Card(
          color: netProfit >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: netProfit >= 0 ? AppColors.success : AppColors.danger, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('OPERATIONAL NET PROFIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryText)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (netProfit >= 0 ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${profitMargin.toStringAsFixed(1)}% margin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: netProfit >= 0 ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(netProfit),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: netProfit >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sales Revenue + Additional Income - COGS - Wastage - Operating Expenses',
                  style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Grid of 6 key indicators
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _buildMetricTile('Total Sales Revenue', Formatters.currency(salesRev), AppColors.primary, Icons.trending_up),
            _buildMetricTile('Gross Profit', Formatters.currency(grossProfit), AppColors.success, Icons.bar_chart),
            _buildMetricTile('Operating Expenses', '- ${Formatters.currency(expenses)}', AppColors.danger, Icons.money_off),
            _buildMetricTile('Stock Wastage', '- ${Formatters.currency(wastage)}', AppColors.warning, Icons.delete_outline),
            _buildMetricTile('Purchases (Asset)', Formatters.currency(purchases), AppColors.info, Icons.shopping_bag_outlined),
            _buildMetricTile('Closing Stock Value', Formatters.currency(closingStock), AppColors.primaryDark, Icons.inventory_2_outlined),
          ],
        ),

        const SizedBox(height: 10),
        // Cash Flow banner
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: netCashFlow >= 0 ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 8),
                    const Text('Net Cash Flow', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                Text(
                  Formatters.currency(netCashFlow),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: netCashFlow >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, Color color, IconData icon) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_reportData == null) return const SizedBox.shrink();
    final daily = (_reportData!['daily_breakdown'] as List<dynamic>?) ?? [];
    if (daily.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Revenue & Net Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Blue: Revenue, Green: Net Profit', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(daily),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < daily.length) {
                            final dateStr = daily[idx]['date'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(dateStr.substring(5), style: const TextStyle(fontSize: 9)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < daily.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: max(0.0, (daily[i]['sales_revenue'] as num).toDouble()),
                            color: AppColors.primary,
                            width: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: max(0.0, (daily[i]['net_profit'] as num).toDouble()),
                            color: AppColors.success,
                            width: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxY(List<dynamic> daily) {
    double maxVal = 1000.0;
    for (final d in daily) {
      final rev = (d['sales_revenue'] as num).toDouble();
      final net = (d['net_profit'] as num).toDouble();
      if (rev > maxVal) maxVal = rev;
      if (net > maxVal) maxVal = net;
    }
    return maxVal * 1.2;
  }

  Widget _buildWarningsSection() {
    final lowStock = _inventoryData.where((i) {
      final usable = (i['usable_stock'] as num).toDouble();
      final min = (i['min_stock_level'] as num).toDouble();
      return min > 0 && usable <= min;
    }).toList();

    final expiringSoon = _inventoryData.where((i) {
      final exp = i['next_expiry_date'] as String?;
      if (exp == null) return false;
      final diff = DateTime.parse(exp).difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 2;
    }).toList();

    if (lowStock.isEmpty && expiringSoon.isEmpty) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: AppColors.success),
              SizedBox(width: 10),
              Text('All inventory levels healthy. No urgent alerts.', style: TextStyle(fontSize: 13, color: AppColors.success)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lowStock.isNotEmpty) ...[
          const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger)),
          const SizedBox(height: 6),
          ...lowStock.map((item) {
            return Card(
              color: const Color(0xFFFEF2F2),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Current: ${Formatters.quantity(item['usable_stock'], item['measurement_unit'])} (Min: ${item['min_stock_level']})'),
                trailing: TextButton(
                  child: const Text('Restock', style: TextStyle(color: AppColors.primary)),
                  onPressed: () => widget.onNavigateTab(4), // Navigate to more / purchases
                ),
              ),
            );
          }),
        ],
        if (expiringSoon.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Expiring Soon (Food Safety)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning)),
          const SizedBox(height: 6),
          ...expiringSoon.map((item) {
            return Card(
              color: const Color(0xFFFFFBEB),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.timer_outlined, color: AppColors.warning),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Expires: ${item['next_expiry_date']}'),
                trailing: TextButton(
                  child: const Text('Wastage', style: TextStyle(color: AppColors.danger)),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WastageScreen()));
                    _loadDashboardData();
                  },
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
