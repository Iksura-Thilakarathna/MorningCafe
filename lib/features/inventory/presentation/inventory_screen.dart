import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/inventory_service.dart';
import 'opening_stock_screen.dart';
import 'stock_movements_screen.dart';
import 'stock_reconciliation_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    final data = await _inventoryService.getInventoryDashboard();
    if (mounted) {
      setState(() {
        _items = data;
        _isLoading = false;
      });
    }
  }

  double _calculateTotalValuation() {
    double total = 0.0;
    for (final it in _items) {
      total += (it['inventory_value'] as num).toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((i) {
      final name = (i['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final totalValuation = _calculateTotalValuation();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock Batches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Stock Movement Ledger',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StockMovementsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadInventory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInventory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildValuationBanner(totalValuation),
                    const SizedBox(height: 14),
                    _buildQuickActionToolbar(),
                    const SizedBox(height: 14),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    _buildIngredientsList(filtered),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildValuationBanner(double totalValuation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppColors.cardDark : AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.highlightYellow : AppColors.borderLight,
          width: isDark ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL INVENTORY VALUATION',
              style: TextStyle(
                color: isDark ? AppColors.highlightYellow : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Formatters.currency(totalValuation),
              style: TextStyle(
                color: isDark ? AppColors.highlightYellow : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cost of all remaining active stock batches (FIFO valued)',
              style: TextStyle(
                color: isDark ? AppColors.secondaryTextDark : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionToolbar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.inventory, size: 16),
            label: const Text('Opening Stock', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningStockScreen()));
              _loadInventory();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: const Text('Stock Count', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReconciliationScreen()));
              _loadInventory();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search ingredient...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
            : null,
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildIngredientsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No ingredients found.'),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final it = items[idx];
        final id = it['id'] as int;
        final name = it['name'] as String;
        final unit = it['measurement_unit'] as String;
        final usable = (it['usable_stock'] as num).toDouble();
        final expired = (it['expired_stock'] as num).toDouble();
        final minStock = (it['min_stock_level'] as num).toDouble();
        final val = (it['inventory_value'] as num).toDouble();
        final nextExp = it['next_expiry_date'] as String?;

        final isLowStock = minStock > 0 && usable <= minStock;
        final hasExpired = expired > 0.0001;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showBatchesDialog(id, name, unit),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppColors.textDark : AppColors.darkText,
                        ),
                      ),
                      Text(
                        Formatters.currency(val),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.highlightYellow : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Usable: ${Formatters.quantity(usable, unit)}${usable > 0 && val > 0 ? ' • ${Formatters.currency(val / usable)}/${unit == 'pieces' ? 'pc' : unit}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLowStock
                              ? (isDark ? AppColors.highlightRed : AppColors.danger)
                              : (isDark ? AppColors.textDark : AppColors.darkText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkDangerBackground : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LOW STOCK',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.highlightRed : AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (hasExpired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkWarningBackground : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${Formatters.quantity(expired, unit)} EXPIRED',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.highlightOrange : AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (nextExp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Next batch expiry: $nextExp',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBatchesDialog(int ingredientId, String name, String unit) async {
    final batches = await _inventoryService.getStockBatches(ingredientId: ingredientId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('$name - Stock Batches', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: batches.isEmpty
                      ? const Center(child: Text('No batches found.'))
                      : ListView.separated(
                          controller: controller,
                          itemCount: batches.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final b = batches[idx];
                            final rem = (b['remaining_quantity'] as num).toDouble();
                            final initial = (b['initial_quantity'] as num).toDouble();
                            final cost = (b['unit_cost'] as num).toDouble();
                            final status = b['status'] as String;

                            Color statusColor = AppColors.success;
                            if (status == 'depleted') statusColor = Colors.grey;
                            if (status == 'expired') statusColor = AppColors.danger;

                            return ListTile(
                              dense: true,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b['batch_code'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Purchased: ${b['purchase_date']} • Price: ${Formatters.currency(cost)} / ${unit == 'pieces' ? 'piece' : unit}\nRemaining: ${Formatters.quantity(rem, unit)} / ${Formatters.quantity(initial, unit)}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
