import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../ingredients/data/ingredient_service.dart';
import '../data/wastage_service.dart';

class WastageScreen extends StatefulWidget {
  const WastageScreen({super.key});

  @override
  State<WastageScreen> createState() => _WastageScreenState();
}

class _WastageScreenState extends State<WastageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WastageService _wastageService = WastageService();
  final IngredientService _ingredientService = IngredientService();

  List<Map<String, dynamic>> _ingredients = [];
  int? _selectedIngredientId;
  String _unit = '';
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedReason = AppConstants.wastageReasons.first;
  DateTime _wastageDate = DateTime.now();

  List<Map<String, dynamic>> _wastageHistory = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final ings = await _ingredientService.getIngredients(activeOnly: true);
    final history = await _wastageService.getWastageList();
    if (mounted) {
      setState(() {
        _ingredients = ings;
        _wastageHistory = history;
        if (ings.isNotEmpty && _selectedIngredientId == null) {
          _selectedIngredientId = ings.first['id'] as int;
          _unit = ings.first['measurement_unit'] as String;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWastage() async {
    if (_selectedIngredientId == null) return;
    final qty = Formatters.parseDouble(_qtyController.text);
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than zero.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dateStr = Formatters.date(_wastageDate);
      await _wastageService.recordWastage(
        ingredientId: _selectedIngredientId!,
        quantity: qty,
        unit: _unit,
        reason: _selectedReason,
        wastageDate: dateStr,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock wastage recorded successfully!'), backgroundColor: AppColors.success),
        );
        _qtyController.clear();
        _notesController.clear();
        _isSaving = false;
        _loadData();
        _tabController.animateTo(1);
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
        title: const Text('Stock Wastage & Losses'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Record Wastage'),
            Tab(text: 'Wastage History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecordTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildRecordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedIngredientId,
            decoration: const InputDecoration(labelText: 'Wasted Ingredient'),
            items: _ingredients.map((i) {
              return DropdownMenuItem<int>(
                value: i['id'] as int,
                child: Text('${i['name']} (${i['measurement_unit']})'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                final ing = _ingredients.firstWhere((i) => i['id'] == v);
                setState(() {
                  _selectedIngredientId = v;
                  _unit = ing['measurement_unit'] as String;
                });
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity Wasted',
              suffixText: _unit,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: const InputDecoration(labelText: 'Reason for Wastage'),
            items: AppConstants.wastageReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _selectedReason = v!),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _wastageDate,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _wastageDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Wastage Date'),
              child: Text(Formatters.displayDate(Formatters.date(_wastageDate)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (Optional)', hintText: 'e.g. Expired after 3 days shelf life'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: _isSaving ? null : _saveWastage,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Record Wastage Deduction', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_wastageHistory.isEmpty) {
      return const Center(child: Text('No wastage recorded.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _wastageHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final w = _wastageHistory[idx];
        final cost = (w['total_cost'] as num).toDouble();
        final qty = (w['quantity'] as num).toDouble();
        final unit = w['unit'] as String;
        return Card(
          color: Colors.white,
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(w['ingredient_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(Formatters.currency(cost), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
              ],
            ),
            subtitle: Text('Wasted: ${Formatters.quantity(qty, unit)} • Reason: ${w['reason']}\nDate: ${w['wastage_date']}'),
          ),
        );
      },
    );
  }
}
