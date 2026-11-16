import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/ingredient_service.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  final IngredientService _ingredientService = IngredientService();
  List<Map<String, dynamic>> _ingredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => _isLoading = true);
    final list = await _ingredientService.getIngredients();
    if (mounted) {
      setState(() {
        _ingredients = list;
        _isLoading = false;
      });
    }
  }

  void _showAddEditIngredientModal([Map<String, dynamic>? ingredient]) {
    final nameCtrl = TextEditingController(text: ingredient?['name'] ?? '');
    final unitCtrl = ingredient?['measurement_unit'] ?? AppConstants.standardUnits.first;
    final minCtrl = TextEditingController(text: ingredient != null ? ingredient['min_stock_level'].toString() : '10');
    final daysCtrl = TextEditingController(text: ingredient?['default_usable_days']?.toString() ?? '');
    final storageCtrl = TextEditingController(text: ingredient?['default_storage_info'] ?? '');
    String selectedUnit = unitCtrl;

    final isEdit = ingredient != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Ingredient' : 'New Ingredient'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Ingredient Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: AppConstants.standardUnits.contains(selectedUnit) ? selectedUnit : AppConstants.standardUnits.first,
                    decoration: const InputDecoration(labelText: 'Base Measurement Unit'),
                    items: AppConstants.standardUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setModalState(() => selectedUnit = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Minimum Stock Alert Level'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Default Usable Shelf Days (1-7, Optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: storageCtrl,
                    decoration: const InputDecoration(labelText: 'Storage Info (e.g. Fridge 2-4 C)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final minStock = Formatters.parseDouble(minCtrl.text);
                  final days = daysCtrl.text.isNotEmpty ? Formatters.parseInt(daysCtrl.text) : null;

                  if (isEdit) {
                    await _ingredientService.updateIngredient(
                      id: ingredient['id'] as int,
                      name: name,
                      measurementUnit: selectedUnit,
                      minStockLevel: minStock,
                      defaultUsableDays: days,
                      defaultStorageInfo: storageCtrl.text.trim(),
                    );
                  } else {
                    await _ingredientService.createIngredient(
                      name: name,
                      measurementUnit: selectedUnit,
                      minStockLevel: minStock,
                      defaultUsableDays: days,
                      defaultStorageInfo: storageCtrl.text.trim(),
                    );
                  }
                  Navigator.pop(ctx);
                  _loadIngredients();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUnitConversionsModal(int ingredientId, String ingredientName, String stockUnit) async {
    final conversions = await _ingredientService.getConversions(ingredientId);
    final pkgUnitCtrl = TextEditingController();
    final multCtrl = TextEditingController();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unit Conversions: $ingredientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Stock Unit: $stockUnit. Converts purchased packaging to stock units.', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                    const Divider(height: 20),
                    if (conversions.isEmpty)
                      const Text('No conversions configured (e.g. 1 bottle = 500 ml)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))
                    else
                      ...conversions.map((c) {
                        return ListTile(
                          dense: true,
                          title: Text('1 ${c['purchase_unit']} = ${c['multiplier']} $stockUnit', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }),
                    const SizedBox(height: 14),
                    const Text('Add / Update Conversion:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pkgUnitCtrl,
                            decoration: const InputDecoration(labelText: 'Purchase Unit (e.g. bottle, pack)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: multCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Multiplier (in $stockUnit)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text('Save Conversion'),
                        onPressed: () async {
                          final pkgUnit = pkgUnitCtrl.text.trim();
                          final mult = Formatters.parseDouble(multCtrl.text);
                          if (pkgUnit.isEmpty || mult <= 0) return;
                          await _ingredientService.setConversion(
                            ingredientId: ingredientId,
                            purchaseUnit: pkgUnit,
                            stockUnit: stockUnit,
                            multiplier: mult,
                          );
                          Navigator.pop(ctx);
                          _loadIngredients();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients & Supplies'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _ingredients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final ing = _ingredients[idx];
                final id = ing['id'] as int;
                final name = ing['name'] as String;
                final unit = ing['measurement_unit'] as String;
                final minStock = (ing['min_stock_level'] as num).toDouble();
                final storage = ing['default_storage_info'] ?? 'General storage';
                final days = ing['default_usable_days'];

                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Card(
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          'Base: $unit',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.highlightYellow : AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text('Min Alert: $minStock $unit • Shelf: ${days != null ? "$days days" : "Standard"}', style: const TextStyle(fontSize: 11)),
                        Text('Storage: $storage', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showAddEditIngredientModal(ing),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.sync_alt, size: 14),
                              label: const Text('Conversions', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showUnitConversionsModal(id, name, unit),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditIngredientModal(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
