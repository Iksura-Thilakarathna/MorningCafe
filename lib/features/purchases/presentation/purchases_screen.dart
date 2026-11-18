import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../ingredients/data/ingredient_service.dart';
import '../data/purchase_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PurchaseService _purchaseService = PurchaseService();
  final IngredientService _ingredientService = IngredientService();

  DateTime _purchaseDate = DateTime.now();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentStatus = 'paid';

  List<Map<String, dynamic>> _allIngredients = [];
  Map<int, List<Map<String, dynamic>>> _conversions = {};
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> _purchaseHistory = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refController.text = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final ings = await _ingredientService.getIngredients(activeOnly: true);
    final history = await _purchaseService.getPurchases();
    final convMap = <int, List<Map<String, dynamic>>>{};
    for (final ing in ings) {
      final id = ing['id'] as int;
      convMap[id] = await _ingredientService.getConversions(id);
    }

    if (mounted) {
      setState(() {
        _allIngredients = ings;
        _conversions = convMap;
        _purchaseHistory = history;
        if (ings.isNotEmpty && _items.isEmpty) {
          _addItemRow();
        }
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableUnits(int ingredientId, String baseUnit) {
    final list = <String>[baseUnit];
    final convs = _conversions[ingredientId] ?? [];
    for (final c in convs) {
      final u = c['purchase_unit'] as String;
      if (!list.contains(u)) {
        list.add(u);
      }
    }
    return list;
  }

  double _getConversionMultiplier(int ingredientId, String packageUnit) {
    final convs = _conversions[ingredientId] ?? [];
    for (final c in convs) {
      if ((c['purchase_unit'] as String).toLowerCase() == packageUnit.toLowerCase()) {
        return (c['multiplier'] as num).toDouble();
      }
    }
    return 1.0;
  }

  bool _isPerQuantityPreferred(String name) {
    final lower = name.toLowerCase();
    return lower.contains('bun') || lower.contains('egg');
  }

  String _getPerQuantityPriceLabel(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sausage bun')) return 'Price per Sausage Bun';
    if (lower.contains('burger bun')) return 'Price per Burger Bun';
    if (lower.contains('egg')) return 'Price per Egg';
    if (lower.contains('bun')) return 'Price per Bun';
    return 'Price per Unit (LKR)';
  }

  void _addItemRow() {
    if (_allIngredients.isEmpty) return;
    final firstIng = _allIngredients.first;
    setState(() {
      _items.add({
        'ingredient_id': firstIng['id'] as int,
        'package_quantity': 1.0,
        'package_unit': firstIng['measurement_unit'] as String,
        'unit_price': 0.0,
        'total_cost': 0.0,
        'usable_duration_days': firstIng['default_usable_days'] ?? 3,
        'use_by_date': null,
      });
    });
  }

  double _calculateTotal() {
    double sum = 0.0;
    for (final it in _items) {
      sum += (it['total_cost'] as num).toDouble();
    }
    return sum;
  }

  Future<void> _savePurchase() async {
    if (_items.isEmpty) return;

    for (final it in _items) {
      final qty = (it['package_quantity'] as num).toDouble();
      final cost = (it['total_cost'] as num).toDouble();
      if (qty <= 0 || cost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid quantities and costs for all items.')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final ref = _refController.text.trim();
      final date = Formatters.date(_purchaseDate);
      await _purchaseService.createPurchase(
        referenceNo: ref.isNotEmpty ? ref : 'PUR-${DateTime.now().millisecondsSinceEpoch}',
        purchaseDate: date,
        supplierName: _supplierController.text.trim(),
        paymentStatus: _paymentStatus,
        items: _items,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase and stock batches created successfully!'), backgroundColor: AppColors.success),
        );
        _items.clear();
        _addItemRow();
        _refController.text = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        _notesController.clear();
        _isSaving = false;
        _loadInitialData();
        _tabController.animateTo(1); // switch to history tab
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases & Inventory Inflow'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'New Purchase'),
            Tab(text: 'Purchase History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNewPurchaseTab(),
                _buildPurchaseHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildNewPurchaseTab() {
    final total = _calculateTotal();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refController,
                  decoration: const InputDecoration(labelText: 'Invoice / Receipt #'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _purchaseDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Purchase Date'),
                    child: Text(Formatters.displayDate(Formatters.date(_purchaseDate)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _supplierController,
                  decoration: const InputDecoration(labelText: 'Supplier Name (Optional)', hintText: 'e.g. Perera Bakery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _paymentStatus,
                  decoration: const InputDecoration(labelText: 'Payment'),
                  items: const [
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  ],
                  onChanged: (v) => setState(() => _paymentStatus = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Purchased Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                onPressed: _addItemRow,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final it = entry.value;
            final ingId = it['ingredient_id'] as int;
            final ing = _allIngredients.firstWhere(
              (i) => i['id'] == ingId,
              orElse: () => {'name': 'Item', 'measurement_unit': 'units'},
            );
            final baseUnit = ing['measurement_unit'] as String;
            final availableUnits = _getAvailableUnits(ingId, baseUnit);
            final currentPkgUnit = it['package_unit'] as String? ?? baseUnit;
            final multiplier = _getConversionMultiplier(ingId, currentPkgUnit);
            final stockYield = (it['package_quantity'] as num).toDouble() * multiplier;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: it['ingredient_id'] as int,
                            decoration: const InputDecoration(labelText: 'Ingredient', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: _allIngredients.map((item) {
                              return DropdownMenuItem<int>(
                                value: item['id'] as int,
                                child: Text('${item['name']} (${item['measurement_unit']})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                final selected = _allIngredients.firstWhere((i) => i['id'] == v);
                                setState(() {
                                  it['ingredient_id'] = v;
                                  it['package_unit'] = selected['measurement_unit'];
                                  it['usable_duration_days'] = selected['default_usable_days'] ?? 3;
                                });
                              }
                            },
                          ),
                        ),
                        if (availableUnits.length > 1) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: availableUnits.contains(currentPkgUnit) ? currentPkgUnit : baseUnit,
                              decoration: const InputDecoration(labelText: 'Unit', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              items: availableUnits.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(u),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => it['package_unit'] = v);
                                }
                              },
                            ),
                          ),
                        ],
                        if (_items.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                            onPressed: () => setState(() => _items.removeAt(idx)),
                          ),
                      ],
                    ),
                    if (multiplier != 1.0) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Yields ${Formatters.number(stockYield)} $baseUnit in stock ($multiplier $baseUnit per $currentPkgUnit)',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final ingName = ing['name'] as String;
                      final isPerQtyItem = _isPerQuantityPreferred(ingName);
                      final double currentQty = (it['package_quantity'] as num).toDouble();
                      final double currentTotalCost = (it['total_cost'] as num).toDouble();
                      final double currentUnitPrice = (it['unit_price'] as num?)?.toDouble() ??
                          (currentQty > 0 && currentTotalCost > 0 ? (currentTotalCost / currentQty) : 0.0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  key: ValueKey('qty_${idx}_$currentPkgUnit'),
                                  initialValue: it['package_quantity'].toString(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    suffixText: currentPkgUnit,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (v) {
                                    final qty = Formatters.parseDouble(v);
                                    setState(() {
                                      it['package_quantity'] = qty;
                                      final up = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                                      if (up > 0) {
                                        it['total_cost'] = qty * up;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  key: ValueKey('price_${idx}_${it['ingredient_id']}'),
                                  initialValue: currentUnitPrice > 0
                                      ? (currentUnitPrice % 1 == 0 ? currentUnitPrice.toInt().toString() : currentUnitPrice.toStringAsFixed(2))
                                      : '',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: isPerQtyItem ? _getPerQuantityPriceLabel(ingName) : 'Price per $currentPkgUnit',
                                    prefixText: 'LKR ',
                                    suffixText: isPerQtyItem ? 'each' : null,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (v) {
                                    final up = Formatters.parseDouble(v);
                                    setState(() {
                                      it['unit_price'] = up;
                                      it['total_cost'] = (it['package_quantity'] as num).toDouble() * up;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: ValueKey('dur_${idx}_$currentPkgUnit'),
                                  initialValue: it['usable_duration_days']?.toString() ?? '3',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Shelf',
                                    suffixText: 'days',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (v) => it['usable_duration_days'] = Formatters.parseInt(v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final ctrl = TextEditingController(
                                text: currentTotalCost > 0 ? currentTotalCost.toStringAsFixed(2) : '',
                              );
                              final customTotal = await showDialog<double>(
                                context: context,
                                builder: (dlgCtx) => AlertDialog(
                                  title: Text('Edit Total Cost ($ingName)'),
                                  content: TextField(
                                    controller: ctrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Total Cost (LKR)',
                                      prefixText: 'LKR ',
                                    ),
                                  ),
                                  actions: [
                                    OutlinedButton(
                                      onPressed: () => Navigator.pop(dlgCtx),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                                        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? AppColors.highlightYellow : AppColors.primary,
                                        foregroundColor: isDark ? AppColors.primaryDark : Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                      onPressed: () => Navigator.pop(dlgCtx, Formatters.parseDouble(ctrl.text)),
                                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (customTotal != null && customTotal >= 0) {
                                setState(() {
                                  it['total_cost'] = customTotal;
                                  if (currentQty > 0) {
                                    it['unit_price'] = customTotal / currentQty;
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceWarmDark : AppColors.surfaceWarm,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calculate_outlined, size: 14, color: isDark ? AppColors.highlightYellow : AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentUnitPrice > 0
                                            ? 'Auto Total (${Formatters.number(currentQty)} × ${Formatters.currency(currentUnitPrice)}):'
                                            : 'Total Cost:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        Formatters.currency(currentTotalCost),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.highlightYellow : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.edit_outlined, size: 12, color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (Optional)'),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Purchase Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                Formatters.currency(total),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.highlightYellow : AppColors.primary,
                foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryDark : Colors.white,
              ),
              onPressed: _isSaving ? null : _savePurchase,
              child: _isSaving
                  ? CircularProgressIndicator(color: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryDark : Colors.white)
                  : const Text('Save & Add to Stock Batches', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistoryTab() {
    if (_purchaseHistory.isEmpty) {
      return const Center(child: Text('No purchase records found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _purchaseHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final p = _purchaseHistory[idx];
        final id = p['id'] as int;
        final ref = p['reference_no'] as String;
        final date = p['purchase_date'] as String;
        final supplier = p['supplier_name'] ?? 'Direct Market';
        final total = (p['total_amount'] as num).toDouble();
        final status = p['status'] as String;
        final isCancelled = status == 'cancelled';

        return Card(
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ref, style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                Text(
                  Formatters.currency(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCancelled
                        ? Colors.grey
                        : (Theme.of(context).brightness == Brightness.dark ? AppColors.highlightYellow : AppColors.primary),
                  ),
                ),
              ],
            ),
            subtitle: Text('Date: $date • Supplier: $supplier\nStatus: ${status.toUpperCase()}'),
            trailing: isCancelled
                ? const Text('CANCELLED', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold))
                : IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.secondaryText, size: 20),
                    tooltip: 'Cancel & Revert Stock',
                    onPressed: () => _confirmCancelPurchase(id, ref),
                  ),
          ),
        );
      },
    );
  }

  void _confirmCancelPurchase(int purchaseId, String ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text('Cancel Purchase #$ref?'),
          content: const Text('This will safely reverse the stock movements and reduce the corresponding inventory batches.'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('No, Keep'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.highlightRed : AppColors.danger,
                foregroundColor: Colors.white,
                elevation: isDark ? 2 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _purchaseService.cancelPurchase(purchaseId, 'Cancelled by user');
      _loadInitialData();
    }
  }
}
