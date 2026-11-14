import 'dart:math';
import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class WastageService {
  final DatabaseHelper _dbHelper;

  WastageService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> recordWastage({
    required int ingredientId,
    required double quantity,
    String? unit,
    required String reason,
    required String wastageDate,
    int? batchId,
    String? notes,
  }) async {
    if (quantity <= 0) throw ArgumentError('Wastage quantity must be greater than zero');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final wasteCode = 'WST-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    return await db.transaction((txn) async {
      double unitCost = 0.0;
      int? allocatedBatchId = batchId;

      String wastageUnit = unit ?? 'units';
      if (unit == null) {
        final ingRes = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingredientId]);
        if (ingRes.isNotEmpty) {
          wastageUnit = ingRes.first['measurement_unit'] as String;
        }
      }

      if (batchId != null) {
        // Specific batch selected
        final bRes = await txn.query('stock_batches', where: 'id = ?', whereArgs: [batchId]);
        if (bRes.isEmpty) throw StateError('Selected batch not found');
        final batch = bRes.first;
        final remQty = (batch['remaining_quantity'] as num).toDouble();
        unitCost = (batch['unit_cost'] as num).toDouble();

        final deduct = min(remQty, quantity);
        final newRem = remQty - deduct;
        final newStatus = newRem <= 0.0001 ? 'depleted' : batch['status'];

        await txn.update(
          'stock_batches',
          {'remaining_quantity': newRem, 'status': newStatus, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [batchId],
        );
      } else {
        // Find oldest active or expired batch
        final bRes = await txn.query(
          'stock_batches',
          where: 'ingredient_id = ? AND remaining_quantity > 0.0001',
          whereArgs: [ingredientId],
          orderBy: 'purchase_date ASC, id ASC',
          limit: 1,
        );
        if (bRes.isNotEmpty) {
          final batch = bRes.first;
          allocatedBatchId = batch['id'] as int;
          final remQty = (batch['remaining_quantity'] as num).toDouble();
          unitCost = (batch['unit_cost'] as num).toDouble();

          final deduct = min(remQty, quantity);
          final newRem = remQty - deduct;
          final newStatus = newRem <= 0.0001 ? 'depleted' : batch['status'];

          await txn.update(
            'stock_batches',
            {'remaining_quantity': newRem, 'status': newStatus, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [allocatedBatchId],
          );
        } else {
          // Fallback cost
          final latest = await txn.query(
            'stock_batches',
            columns: ['unit_cost'],
            where: 'ingredient_id = ?',
            whereArgs: [ingredientId],
            orderBy: 'id DESC',
            limit: 1,
          );
          unitCost = latest.isNotEmpty ? (latest.first['unit_cost'] as num).toDouble() : 0.0;
        }
      }

      final totalCost = quantity * unitCost;

      final wasteId = await txn.insert('stock_wastage', {
        'wastage_code': wasteCode,
        'ingredient_id': ingredientId,
        'batch_id': allocatedBatchId,
        'quantity': quantity,
        'unit': wastageUnit,
        'unit_cost': unitCost,
        'total_cost': totalCost,
        'reason': reason,
        'wastage_date': wastageDate,
        'notes': notes?.trim(),
        'created_at': now,
      });

      final movCode = 'MOV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      await txn.insert('stock_movements', {
        'movement_code': movCode,
        'ingredient_id': ingredientId,
        'batch_id': allocatedBatchId,
        'movement_type': 'wastage',
        'quantity': -quantity,
        'unit_cost': unitCost,
        'total_cost': totalCost,
        'movement_date': wastageDate,
        'reference_type': 'wastage',
        'reference_id': wasteId,
        'notes': 'Recorded wastage: $reason',
        'created_at': now,
      });

      await AuditService.log(
        actionType: 'insert',
        tableName: 'stock_wastage',
        recordId: wasteId,
        description: 'Recorded wastage of $quantity $unit ($reason) at cost LKR $totalCost',
        txn: txn,
      );

      return wasteId;
    });
  }

  Future<List<Map<String, dynamic>>> getWastageList({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (startDate != null) {
      whereClause += ' AND sw.wastage_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      whereClause += ' AND sw.wastage_date <= ?';
      args.add(endDate);
    }

    return await db.rawQuery('''
      SELECT 
        sw.*,
        i.name as ingredient_name
      FROM stock_wastage sw
      JOIN ingredients i ON sw.ingredient_id = i.id
      WHERE $whereClause
      ORDER BY sw.wastage_date DESC, sw.id DESC
    ''', args);
  }
}
