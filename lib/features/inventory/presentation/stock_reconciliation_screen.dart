import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/inventory_service.dart';

class StockReconciliationScreen extends StatefulWidget {
  const StockReconciliationScreen({super.key});

  @override
  State<StockReconciliationScreen> createState() => _StockReconciliationScreenState();
}

class _StockReconciliationScreenState extends State<StockReconciliationScreen> {
  final InventoryService _inventoryService = InventoryService();
  List<Map<String, dynamic>> _ingredients = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await _inventoryService.getInventoryDashboard();
    if (mounted) {
      setState(() {
        _ingredients = list;
        for (final item in list) {
          final id = item['id'] as int;
          final usable = (item['usable_stock'] as num).toDouble();
          _controllers[id] = TextEditingController(text: usable.toString());
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReconciliation() async {
    final counts = <Map<String, dynamic>>[];

    for (final item in _ingredients) {
      final id = item['id'] as int;
      final text = _controllers[id]?.text ?? '';
      final physicalQty = Formatters.parseDouble(text, -1.0);
      if (physicalQty >= 0) {
        counts.add({
          'ingredient_id': id,
          'physical_quantity': physicalQty,
        });
      }
    }

    if (counts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Stock Reconciliation'),
        content: const Text(
          'Reconciling physical stock will automatically record shortages (consumed via FIFO) or surpluses (adjustment batches) in your inventory ledger.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm Adjustment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _inventoryService.performStockReconciliation(
        countDate: today,
        counts: counts,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock count reconciled successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
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
        title: const Text('Physical Stock Reconciliation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.surfaceWarm,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: const [
                          Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Enter your actual physical count. The system will calculate variances and adjust inventory batches.',
                              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _ingredients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = _ingredients[idx];
                      final id = item['id'] as int;
                      final name = item['name'] as String;
                      final unit = item['measurement_unit'] as String;
                      final systemQty = (item['usable_stock'] as num).toDouble();
                      final controller = _controllers[id];

                      return Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('System Book: ${Formatters.quantity(systemQty, unit)}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Physical',
                                    suffixText: unit,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Reconciliation Notes (Optional)',
                      hintText: 'e.g. End of month physical store check',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitReconciliation,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Apply Stock Adjustments', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
