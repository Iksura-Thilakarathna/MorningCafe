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
    if (mounted) {
      setState(() {
        _allIngredients = ings;
        _purchaseHistory = history;
        if (ings.isNotEmpty && _items.isEmpty) {
          _addItemRow();
        }
        _isLoading = false;
      });
    }
  }

  void _addItemRow() {
    if (_allIngredients.isEmpty) return;
    final firstIng = _allIngredients.first;
    setState(() {
      _items.add({
        'ingredient_id': firstIng['id'] as int,
        'package_quantity': 1.0,
        'package_unit': firstIng['measurement_unit'] as String,
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

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: it['ingredient_id'] as int,
                            decoration: const InputDecoration(labelText: 'Ingredient', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: _allIngredients.map((ing) {
                              return DropdownMenuItem<int>(
                                value: ing['id'] as int,
                                child: Text('${ing['name']} (${ing['measurement_unit']})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                final ing = _allIngredients.firstWhere((i) => i['id'] == v);
                                setState(() {
                                  it['ingredient_id'] = v;
                                  it['package_unit'] = ing['measurement_unit'];
                                  it['usable_duration_days'] = ing['default_usable_days'] ?? 3;
                                });
                              }
                            },
                          ),
                        ),
                        if (_items.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                            onPressed: () => setState(() => _items.removeAt(idx)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: it['package_quantity'].toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              suffixText: it['package_unit'],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (v) => setState(() => it['package_quantity'] = Formatters.parseDouble(v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: it['total_cost'].toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Total Cost (LKR)',
                              prefixText: 'LKR ',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (v) => setState(() => it['total_cost'] = Formatters.parseDouble(v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: it['usable_duration_days']?.toString() ?? '3',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                              suffixText: 'days',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (v) => it['usable_duration_days'] = Formatters.parseInt(v),
                          ),
                        ),
                      ],
                    ),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _isSaving ? null : _savePurchase,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
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
          color: Colors.white,
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ref, style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                Text(
                  Formatters.currency(total),
                  style: TextStyle(fontWeight: FontWeight.bold, color: isCancelled ? Colors.grey : AppColors.primary),
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
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Purchase #$ref?'),
        content: const Text('This will safely reverse the stock movements and reduce the corresponding inventory batches.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Purchase'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _purchaseService.cancelPurchase(purchaseId, 'Cancelled by user');
      _loadInitialData();
    }
  }
}
