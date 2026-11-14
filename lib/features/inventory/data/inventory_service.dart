import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class InventoryService {
  final DatabaseHelper _dbHelper;

  InventoryService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Updates active stock batches to 'expired' if their expiry date or usable_end_date has passed
  Future<void> updateBatchExpiryStatuses([String? checkDate]) async {
    final date = checkDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.execute('''
      UPDATE stock_batches 
      SET status = 'expired', updated_at = ?
      WHERE status = 'active' 
        AND remaining_quantity > 0.0001
        AND (
          (use_by_date IS NOT NULL AND use_by_date < ?)
          OR
          (usable_end_date IS NOT NULL AND usable_end_date < ?)
        )
    ''', [now, date, date]);
  }

  /// Consumes ingredient quantity in strict FIFO order from active, non-expired batches
  Future<Map<String, dynamic>> consumeIngredientFIFO({
    required Transaction txn,
    required int ingredientId,
    required double quantityToConsume,
    required String referenceType,
    required int referenceId,
    required String movementDate,
    String? notes,
  }) async {
    if (quantityToConsume <= 0) {
      return {'total_cost': 0.0, 'consumed_quantity': 0.0, 'batches': []};
    }

    final now = DateTime.now().toIso8601String();

    // 1. Refresh expired status for this date
    await txn.execute('''
      UPDATE stock_batches 
      SET status = 'expired', updated_at = ?
      WHERE status = 'active' 
        AND remaining_quantity > 0.0001
        AND (
          (use_by_date IS NOT NULL AND use_by_date < ?)
          OR
          (usable_end_date IS NOT NULL AND usable_end_date < ?)
        )
    ''', [now, movementDate, movementDate]);

    // 2. Fetch active eligible batches in FIFO order (oldest purchase_date first, then lowest id)
    final eligibleBatches = await txn.query(
      'stock_batches',
      where: "ingredient_id = ? AND status = 'active' AND remaining_quantity > 0.0001",
      whereArgs: [ingredientId],
      orderBy: 'purchase_date ASC, id ASC',
    );

    double remainingNeed = quantityToConsume;
    double totalCost = 0.0;
    final consumedBatches = <Map<String, dynamic>>[];

    for (final b in eligibleBatches) {
      if (remainingNeed <= 0.00001) break;

      final batchId = b['id'] as int;
      final remQty = (b['remaining_quantity'] as num).toDouble();
      final unitCost = (b['unit_cost'] as num).toDouble();

      final deduct = min(remQty, remainingNeed);
      final cost = deduct * unitCost;
      final newRem = remQty - deduct;
      final newStatus = (newRem <= 0.0001) ? 'depleted' : 'active';

      await txn.update(
        'stock_batches',
        {
          'remaining_quantity': newRem,
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [batchId],
      );

      final movCode = 'MOV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      final movType = referenceType == 'sale'
          ? 'sales_consumption'
          : (referenceType == 'wastage' ? 'wastage' : 'stock_adjustment');

      await txn.insert('stock_movements', {
        'movement_code': movCode,
        'ingredient_id': ingredientId,
        'batch_id': batchId,
        'movement_type': movType,
        'quantity': -deduct,
        'unit_cost': unitCost,
        'total_cost': cost,
        'movement_date': movementDate,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'notes': notes ?? 'FIFO consumption from batch ${b['batch_code']}',
        'created_at': now,
      });

      totalCost += cost;
      remainingNeed -= deduct;

      consumedBatches.add({
        'batch_id': batchId,
        'batch_code': b['batch_code'],
        'quantity': deduct,
        'unit_cost': unitCost,
        'cost': cost,
      });
    }

    // If stock shortage occurred, log unbatched deficit at latest known unit cost
    if (remainingNeed > 0.0001) {
      final latest = await txn.query(
        'stock_batches',
        columns: ['unit_cost'],
        where: 'ingredient_id = ?',
        whereArgs: [ingredientId],
        orderBy: 'id DESC',
        limit: 1,
      );
      final fallbackCost = latest.isNotEmpty ? (latest.first['unit_cost'] as num).toDouble() : 0.0;
      final deficitCost = remainingNeed * fallbackCost;

      final movCode = 'DEF-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      await txn.insert('stock_movements', {
        'movement_code': movCode,
        'ingredient_id': ingredientId,
        'batch_id': null,
        'movement_type': 'stock_adjustment',
        'quantity': -remainingNeed,
        'unit_cost': fallbackCost,
        'total_cost': deficitCost,
        'movement_date': movementDate,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'notes': 'Unbatched consumption deficit (stock shortage)',
        'created_at': now,
      });

      totalCost += deficitCost;
      consumedBatches.add({
        'batch_id': null,
        'batch_code': 'DEFICIT',
        'quantity': remainingNeed,
        'unit_cost': fallbackCost,
        'cost': deficitCost,
      });
    }

    return {
      'total_cost': totalCost,
      'consumed_quantity': quantityToConsume,
      'batches': consumedBatches,
    };
  }

  /// Reverses all stock movements for a given reference (e.g. edited sale or edited purchase)
  Future<void> reverseMovementsForReference({
    required Transaction txn,
    required String referenceType,
    required int referenceId,
    required String reversalReason,
  }) async {
    final movements = await txn.query(
      'stock_movements',
      where: "reference_type = ? AND reference_id = ? AND movement_type != 'correction'",
      whereArgs: [referenceType, referenceId],
    );

    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    for (final m in movements) {
      final qty = (m['quantity'] as num).toDouble();
      final batchId = m['batch_id'] as int?;

      if (qty < 0) {
        // Was a deduction: restore quantity back to batch
        final restoreQty = qty.abs();
        if (batchId != null) {
          await txn.execute('''
            UPDATE stock_batches 
            SET remaining_quantity = remaining_quantity + ?, status = 'active', updated_at = ?
            WHERE id = ?
          ''', [restoreQty, now, batchId]);
        }

        final corrCode = 'CORR-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
        await txn.insert('stock_movements', {
          'movement_code': corrCode,
          'ingredient_id': m['ingredient_id'],
          'batch_id': batchId,
          'movement_type': 'correction',
          'quantity': restoreQty,
          'unit_cost': m['unit_cost'],
          'total_cost': m['total_cost'],
          'movement_date': today,
          'reference_type': referenceType,
          'reference_id': referenceId,
          'notes': 'Reversal of ${m['movement_code']}: $reversalReason',
          'created_at': now,
        });
      } else if (qty > 0) {
        // Was an addition (like purchase or opening): deduct quantity from batch
        final deductQty = qty;
        if (batchId != null) {
          await txn.execute('''
            UPDATE stock_batches 
            SET remaining_quantity = MAX(0, remaining_quantity - ?),
                status = CASE WHEN remaining_quantity - ? <= 0.0001 THEN 'depleted' ELSE status END,
                updated_at = ?
            WHERE id = ?
          ''', [deductQty, deductQty, now, batchId]);
        }

        final corrCode = 'CORR-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
        await txn.insert('stock_movements', {
          'movement_code': corrCode,
          'ingredient_id': m['ingredient_id'],
          'batch_id': batchId,
          'movement_type': 'correction',
          'quantity': -deductQty,
          'unit_cost': m['unit_cost'],
          'total_cost': m['total_cost'],
          'movement_date': today,
          'reference_type': referenceType,
          'reference_id': referenceId,
          'notes': 'Reversal of ${m['movement_code']}: $reversalReason',
          'created_at': now,
        });
      }
    }
  }

  /// Records opening stock for an ingredient
  Future<int> recordOpeningStock({
    required int ingredientId,
    required double quantity,
    required double unitCost,
    required String date,
    int? usableDurationDays,
    String? useByDate,
    String? notes,
  }) async {
    if (quantity <= 0) throw ArgumentError('Quantity must be greater than zero');
    if (unitCost < 0) throw ArgumentError('Unit cost cannot be negative');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    String? usableEndDate;
    if (usableDurationDays != null && usableDurationDays > 0) {
      final parsedDate = DateTime.parse(date);
      usableEndDate = parsedDate.add(Duration(days: usableDurationDays - 1)).toIso8601String().substring(0, 10);
    }

    return await db.transaction((txn) async {
      final batchCode = 'OPEN-$ingredientId-${DateTime.now().millisecondsSinceEpoch}';
      final batchId = await txn.insert('stock_batches', {
        'batch_code': batchCode,
        'ingredient_id': ingredientId,
        'purchase_item_id': null,
        'source_type': 'opening_stock',
        'purchase_date': date,
        'initial_quantity': quantity,
        'remaining_quantity': quantity,
        'unit_cost': unitCost,
        'use_by_date': useByDate,
        'usable_duration_days': usableDurationDays,
        'usable_end_date': usableEndDate,
        'status': 'active',
        'notes': notes ?? 'Opening stock balance',
        'created_at': now,
        'updated_at': now,
      });

      final movCode = 'MOV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      await txn.insert('stock_movements', {
        'movement_code': movCode,
        'ingredient_id': ingredientId,
        'batch_id': batchId,
        'movement_type': 'opening_stock',
        'quantity': quantity,
        'unit_cost': unitCost,
        'total_cost': quantity * unitCost,
        'movement_date': date,
        'reference_type': 'opening_stock',
        'reference_id': batchId,
        'notes': notes ?? 'Initial opening stock',
        'created_at': now,
      });

      await AuditService.log(
        actionType: 'insert',
        tableName: 'stock_batches',
        recordId: batchId,
        description: 'Recorded opening stock: $quantity units at LKR $unitCost for ingredient $ingredientId',
        txn: txn,
      );

      return batchId;
    });
  }

  /// Performs physical stock count reconciliation
  Future<int> performStockReconciliation({
    required String countDate,
    required List<Map<String, dynamic>> counts,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final countCode = 'STK-COUNT-${DateTime.now().millisecondsSinceEpoch}';

    return await db.transaction((txn) async {
      final countId = await txn.insert('stock_counts', {
        'count_code': countCode,
        'count_date': countDate,
        'status': 'completed',
        'notes': notes?.trim(),
        'created_at': now,
      });

      for (final item in counts) {
        final ingredientId = item['ingredient_id'] as int;
        final physicalQty = (item['physical_quantity'] as num).toDouble();

        // Calculate current system quantity from movement ledger
        final moveRes = await txn.rawQuery('''
          SELECT COALESCE(SUM(quantity), 0) as balance 
          FROM stock_movements 
          WHERE ingredient_id = ? AND movement_date <= ?
        ''', [ingredientId, countDate]);
        final systemQty = (moveRes.first['balance'] as num).toDouble();
        final diff = physicalQty - systemQty;

        if (diff.abs() > 0.0001) {
          // Latest unit cost
          final costRes = await txn.rawQuery('''
            SELECT unit_cost FROM stock_batches WHERE ingredient_id = ? ORDER BY id DESC LIMIT 1
          ''', [ingredientId]);
          final unitCost = costRes.isNotEmpty ? (costRes.first['unit_cost'] as num).toDouble() : 0.0;
          final adjValue = diff.abs() * unitCost;

          await txn.insert('stock_count_items', {
            'stock_count_id': countId,
            'ingredient_id': ingredientId,
            'system_quantity': systemQty,
            'physical_quantity': physicalQty,
            'difference_quantity': diff,
            'unit_cost': unitCost,
            'adjustment_value': adjValue,
            'adjustment_status': 'adjusted',
          });

          if (diff < 0) {
            // Shortage: consume deficit via FIFO
            final shortage = diff.abs();
            await consumeIngredientFIFO(
              txn: txn,
              ingredientId: ingredientId,
              quantityToConsume: shortage,
              referenceType: 'stock_count',
              referenceId: countId,
              movementDate: countDate,
              notes: 'Physical count shortage adjustment (-$shortage)',
            );
          } else {
            // Surplus: create adjustment batch
            final surplus = diff;
            final adjBatchCode = 'ADJ-$ingredientId-${DateTime.now().millisecondsSinceEpoch}';
            final batchId = await txn.insert('stock_batches', {
              'batch_code': adjBatchCode,
              'ingredient_id': ingredientId,
              'source_type': 'adjustment',
              'purchase_date': countDate,
              'initial_quantity': surplus,
              'remaining_quantity': surplus,
              'unit_cost': unitCost,
              'status': 'active',
              'notes': 'Stock count surplus adjustment (+$surplus)',
              'created_at': now,
              'updated_at': now,
            });

            final movCode = 'MOV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
            await txn.insert('stock_movements', {
              'movement_code': movCode,
              'ingredient_id': ingredientId,
              'batch_id': batchId,
              'movement_type': 'stock_adjustment',
              'quantity': surplus,
              'unit_cost': unitCost,
              'total_cost': surplus * unitCost,
              'movement_date': countDate,
              'reference_type': 'stock_count',
              'reference_id': countId,
              'notes': 'Physical count surplus adjustment (+$surplus)',
              'created_at': now,
            });
          }
        }
      }

      await AuditService.log(
        actionType: 'reconciliation',
        tableName: 'stock_counts',
        recordId: countId,
        description: 'Completed physical stock count reconciliation on $countDate',
        txn: txn,
      );

      return countId;
    });
  }

  /// Returns batches for an ingredient or all batches
  Future<List<Map<String, dynamic>>> getStockBatches({int? ingredientId, String? status}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (ingredientId != null) {
      whereClause += ' AND sb.ingredient_id = ?';
      args.add(ingredientId);
    }
    if (status != null) {
      whereClause += ' AND sb.status = ?';
      args.add(status);
    }

    return await db.rawQuery('''
      SELECT 
        sb.*,
        i.name as ingredient_name,
        i.measurement_unit as stock_unit
      FROM stock_batches sb
      JOIN ingredients i ON sb.ingredient_id = i.id
      WHERE $whereClause
      ORDER BY sb.purchase_date ASC, sb.id ASC
    ''', args);
  }

  /// Calculates total inventory valuation across active batches
  Future<double> getTotalInventoryValuation() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_quantity * unit_cost), 0.0) as total_val
      FROM stock_batches
      WHERE status = 'active' AND remaining_quantity > 0.0001
    ''');
    return (res.first['total_val'] as num).toDouble();
  }

  /// Returns full inventory dashboard data with warnings
  Future<List<Map<String, dynamic>>> getInventoryDashboard([String? targetDate]) async {
    final date = targetDate ?? DateTime.now().toIso8601String().substring(0, 10);
    await updateBatchExpiryStatuses(date);

    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        i.id,
        i.name,
        i.measurement_unit,
        i.min_stock_level,
        i.default_storage_info,
        i.is_active,
        COALESCE(SUM(CASE WHEN sb.status = 'active' THEN sb.remaining_quantity ELSE 0 END), 0) as usable_stock,
        COALESCE(SUM(CASE WHEN sb.status = 'expired' THEN sb.remaining_quantity ELSE 0 END), 0) as expired_stock,
        COALESCE(SUM(sb.remaining_quantity), 0) as total_current_stock,
        COALESCE(SUM(CASE WHEN sb.status = 'active' THEN sb.remaining_quantity * sb.unit_cost ELSE 0 END), 0) as inventory_value,
        MIN(CASE WHEN sb.status = 'active' AND sb.remaining_quantity > 0.0001 THEN COALESCE(sb.use_by_date, sb.usable_end_date) ELSE NULL END) as next_expiry_date
      FROM ingredients i
      LEFT JOIN stock_batches sb ON i.id = sb.ingredient_id AND sb.remaining_quantity > 0.0001
      WHERE i.is_active = 1
      GROUP BY i.id
      ORDER BY i.name ASC
    ''');

    return rows;
  }

  /// Helper to consume stock FIFO directly without manual transaction handling
  Future<double> consumeStockFIFO({
    required int ingredientId,
    required double requiredQuantity,
    required String transactionType,
    required int referenceId,
    required String transactionDate,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final res = await consumeIngredientFIFO(
        txn: txn,
        ingredientId: ingredientId,
        quantityToConsume: requiredQuantity,
        referenceType: transactionType,
        referenceId: referenceId,
        movementDate: transactionDate,
        notes: notes,
      );
      return (res['total_cost'] as num).toDouble();
    });
  }

  /// Helper to return current active usable stock quantity for an ingredient
  Future<double> getUsableStock(int ingredientId, [String? checkDate]) async {
    await updateBatchExpiryStatuses(checkDate);
    final batches = await getStockBatches(ingredientId: ingredientId, status: 'active');
    double total = 0.0;
    for (final b in batches) {
      total += (b['remaining_quantity'] as num).toDouble();
    }
    return total;
  }

  /// Helper to return all batches for an ingredient
  Future<List<Map<String, dynamic>>> getBatchDetails(int ingredientId) async {
    return await getStockBatches(ingredientId: ingredientId);
  }
}
