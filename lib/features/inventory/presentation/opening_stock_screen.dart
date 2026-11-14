import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../ingredients/data/ingredient_service.dart';
import '../data/inventory_service.dart';

class OpeningStockScreen extends StatefulWidget {
  const OpeningStockScreen({super.key});

  @override
  State<OpeningStockScreen> createState() => _OpeningStockScreenState();
}

class _OpeningStockScreenState extends State<OpeningStockScreen> {
  final IngredientService _ingredientService = IngredientService();
  final InventoryService _inventoryService = InventoryService();

  List<Map<String, dynamic>> _ingredients = [];
  int? _selectedIngredientId;
  String _unit = '';
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _stockDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final list = await _ingredientService.getIngredients(activeOnly: true);
    if (mounted) {
      setState(() {
        _ingredients = list;
        if (list.isNotEmpty) {
          _selectedIngredientId = list.first['id'] as int;
          _unit = list.first['measurement_unit'] as String;
          if (list.first['default_usable_days'] != null) {
            _daysController.text = list.first['default_usable_days'].toString();
          }
        }
        _isLoading = false;
      });
    }
  }

  void _onIngredientChanged(int? id) {
    if (id == null) return;
    final item = _ingredients.firstWhere((i) => i['id'] == id);
    setState(() {
      _selectedIngredientId = id;
      _unit = item['measurement_unit'] as String;
      if (item['default_usable_days'] != null) {
        _daysController.text = item['default_usable_days'].toString();
      } else {
        _daysController.clear();
      }
    });
  }

  Future<void> _submitOpeningStock() async {
    if (_selectedIngredientId == null) return;

    final qty = Formatters.parseDouble(_qtyController.text);
    final cost = Formatters.parseDouble(_costController.text);
    final days = _daysController.text.isNotEmpty ? Formatters.parseInt(_daysController.text) : null;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than zero.')));
      return;
    }
    if (cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estimated cost cannot be negative.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _inventoryService.recordOpeningStock(
        ingredientId: _selectedIngredientId!,
        quantity: qty,
        unitCost: cost,
        date: Formatters.date(_stockDate),
        usableDurationDays: days,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening stock batch saved successfully!'), backgroundColor: AppColors.success),
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
        title: const Text('Record Opening Stock'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFFEFF6FF),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opening stock establishes your initial inventory valuation. It is not counted as a new purchase or weekly expense.',
                              style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stock Date', style: TextStyle(fontSize: 14)),
                    subtitle: Text(Formatters.displayDate(Formatters.date(_stockDate))),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _stockDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _stockDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _selectedIngredientId,
                    decoration: const InputDecoration(labelText: 'Select Ingredient'),
                    items: _ingredients.map((i) {
                      return DropdownMenuItem<int>(
                        value: i['id'] as int,
                        child: Text('${i['name']} (${i['measurement_unit']})'),
                      );
                    }).toList(),
                    onChanged: _onIngredientChanged,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Initial Quantity in Stock',
                      suffixText: _unit,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Estimated Unit Cost (LKR)',
                      prefixText: 'LKR ',
                      suffixText: 'per $_unit',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Expected Usable Duration (Optional)',
                      suffixText: 'days (1-7)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'e.g. Existing store cupboard count',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitOpeningStock,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Opening Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
