import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT 
        sm.*,
        i.name as ingredient_name,
        i.measurement_unit as stock_unit
      FROM stock_movements sm
      JOIN ingredients i ON sm.ingredient_id = i.id
      ORDER BY sm.movement_date DESC, sm.id DESC
      LIMIT 150
    ''');

    if (mounted) {
      setState(() {
        _movements = rows;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Movement Ledger'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMovements),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
              ? const Center(child: Text('No stock movements recorded yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _movements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final m = _movements[idx];
                    final date = m['movement_date'] as String;
                    final ing = m['ingredient_name'] as String;
                    final unit = m['stock_unit'] as String;
                    final qty = (m['quantity'] as num).toDouble();
                    final cost = (m['total_cost'] as num).toDouble();
                    final type = m['movement_type'] as String;
                    final code = m['movement_code'] as String;

                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final isAddition = qty > 0;
                    final color = isAddition
                        ? (isDark ? AppColors.highlightGreen : AppColors.success)
                        : (isDark ? AppColors.highlightRed : AppColors.danger);

                    return Card(
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(
                            isAddition ? Icons.arrow_downward : Icons.arrow_upward,
                            color: color,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ing, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              '${isAddition ? '+' : ''}${Formatters.quantity(qty, unit)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('Type: ${type.toUpperCase()} • $date', style: const TextStyle(fontSize: 11)),
                            Text('Cost: ${Formatters.currency(cost)} • $code', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
