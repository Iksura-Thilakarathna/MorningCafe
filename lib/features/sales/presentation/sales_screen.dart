import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../products/data/product_service.dart';
import '../../recipes/data/recipe_service.dart';
import '../data/sales_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SalesService _salesService = SalesService();
  final ProductService _productService = ProductService();
  final RecipeService _recipeService = RecipeService();

  late DateTime _selectedDate;
  List<Map<String, dynamic>> _products = [];
  final Map<int, int> _quantities = {};
  final Map<int, double> _customActualUsage = {};
  final Map<int, List<Map<String, dynamic>>> _productRecipeCache = {};
  List<Map<String, dynamic>> _expectedUsageList = [];

  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final prods = await _productService.getProducts(activeOnly: true);
    final dateStr = Formatters.date(_selectedDate);

    _productRecipeCache.clear();
    for (final p in prods) {
      final pid = p['id'] as int;
      _quantities.putIfAbsent(pid, () => 0);
      final usage = await _recipeService.calculateTheoreticalUsage(
        productId: pid,
        quantitySold: 1,
        saleDate: dateStr,
      );
      _productRecipeCache[pid] = usage;
    }

    if (mounted) {
      setState(() {
        _products = prods;
        _isLoading = false;
        _recomputeExpectedUsageSync();
      });
    }
  }

  void _updateQuantity(int productId, int delta) {
    setState(() {
      final current = _quantities[productId] ?? 0;
      final updated = (current + delta).clamp(0, 9999);
      _quantities[productId] = updated;
      _recomputeExpectedUsageSync();
    });
  }

  void _recomputeExpectedUsageSync() {
    final aggregated = <int, Map<String, dynamic>>{};
    for (final entry in _quantities.entries) {
      final pid = entry.key;
      final qty = entry.value;
      if (qty <= 0) continue;

      final items = _productRecipeCache[pid] ?? [];
      for (final u in items) {
        final iid = u['ingredient_id'] as int;
        final perUnit = (u['total_quantity'] as num).toDouble();
        final totalQ = perUnit * qty;
        if (aggregated.containsKey(iid)) {
          aggregated[iid]!['quantity'] += totalQ;
        } else {
          aggregated[iid] = {
            'ingredient_id': iid,
            'name': u['ingredient_name'],
            'unit': u['unit'],
            'quantity': totalQ,
          };
        }
      }
    }
    _expectedUsageList = aggregated.values.toList();
  }

  double _computeTotalRevenue() {
    double total = 0.0;
    for (final p in _products) {
      final pid = p['id'] as int;
      final qty = _quantities[pid] ?? 0;
      final price = (p['selling_price'] as num).toDouble();
      total += qty * price;
    }
    return total;
  }

  Future<void> _saveDailySales() async {
    final hasItems = _quantities.values.any((q) => q > 0);
    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter quantity for at least one product sold.')),
      );
      return;
    }

    final dateStr = Formatters.date(_selectedDate);
    final totalRevenue = _computeTotalRevenue();

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Daily Sales'),
        content: Text(
          'Record daily sales for $dateStr?\n\nTotal Revenue: ${Formatters.currency(totalRevenue)}\nIngredients will be deducted via FIFO.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await _salesService.recordDailySales(
        saleDate: dateStr,
        productQuantities: _quantities,
        customActualUsage: _customActualUsage.isNotEmpty ? _customActualUsage : null,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily sales for $dateStr saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          for (final key in _quantities.keys) {
            _quantities[key] = 0;
          }
          _customActualUsage.clear();
          _expectedUsageList.clear();
          _notesController.clear();
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _computeTotalRevenue();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Daily Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Sales History',
            onPressed: () => _showSalesHistory(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildProductQuantitiesCard(),
                  const SizedBox(height: 16),
                  _buildExpectedUsageCard(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Daily Notes (Optional)',
                      hintText: 'e.g. Rainy day, special morning discount applied',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(totalRevenue),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.calendar_month, color: AppColors.primary),
        title: const Text('Sale Date', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        subtitle: Text(
          Formatters.displayDate(Formatters.date(_selectedDate)),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: OutlinedButton(
          child: const Text('Change'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2025),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
              _loadProducts();
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductQuantitiesCard() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Quantities Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Tap + or - to record items sold today', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            const Divider(height: 24),
            ..._products.map((p) {
              final pid = p['id'] as int;
              final name = p['name'] as String;
              final price = (p['selling_price'] as num).toDouble();
              final qty = _quantities[pid] ?? 0;
              final lineTotal = qty * price;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(
                            '${Formatters.currency(price)} each • Total: ${Formatters.currency(lineTotal)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.secondaryText),
                          onPressed: () => _updateQuantity(pid, -1),
                        ),
                        Container(
                          width: 44,
                          alignment: Alignment.center,
                          child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                          onPressed: () => _updateQuantity(pid, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpectedUsageCard() {
    if (_expectedUsageList.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppColors.surfaceWarm,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expected Ingredient Consumption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${_expectedUsageList.length} items', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Automatically calculated via recipes and deducted via FIFO', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const Divider(height: 18),
            ..._expectedUsageList.map((u) {
              final name = u['name'] as String;
              final unit = u['unit'] as String;
              final qty = (u['quantity'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 12)),
                    Text(Formatters.quantity(qty, unit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(double totalRevenue) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Daily Sales Revenue:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(
              Formatters.currency(totalRevenue),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveDailySales,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Daily Sales', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showSalesHistory(BuildContext context) async {
    final history = await _salesService.getDailySales();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Recorded Daily Sales History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('No daily sales records found.'))
                      : ListView.separated(
                          controller: controller,
                          itemCount: history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final row = history[idx];
                            final rev = (row['total_revenue'] as num).toDouble();
                            final cogs = (row['total_cogs'] as num).toDouble();
                            final gross = rev - cogs;
                            return ListTile(
                              title: Text(Formatters.displayDate(row['sale_date']), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('COGS: ${Formatters.currency(cogs)} • Gross: ${Formatters.currency(gross)}'),
                              trailing: Text(
                                Formatters.currency(rev),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
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
