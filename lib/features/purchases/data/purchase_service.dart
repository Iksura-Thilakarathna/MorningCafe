import 'dart:math';
import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';
import '../../ingredients/data/ingredient_service.dart';
import '../../inventory/data/inventory_service.dart';

class PurchaseService {
  final DatabaseHelper _dbHelper;
  final IngredientService _ingredientService;
  final InventoryService _inventoryService;

  PurchaseService([
    DatabaseHelper? dbHelper,
    IngredientService? ingredientService,
    InventoryService? inventoryService,
  ])  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _ingredientService = ingredientService ?? IngredientService(dbHelper),
        _inventoryService = inventoryService ?? InventoryService(dbHelper);

  Future<int> recordPurchase({
    String? referenceNo,
    required String purchaseDate,
    String? supplierName,
    String? invoiceNumber,
    String paymentStatus = 'paid',
    String? paymentMethod,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final ref = referenceNo ?? invoiceNumber ?? 'PO-${DateTime.now().millisecondsSinceEpoch}';
    final formattedItems = items.map((it) {
      return {
        'ingredient_id': it['ingredient_id'],
        'package_quantity': it['quantity'] ?? it['package_quantity'] ?? 1.0,
        'package_unit': it['package_unit'] ?? it['unit'] ?? 'pcs',
        'total_cost': it['total_cost'] ?? ((it['quantity'] as num).toDouble() * (it['unit_price'] as num).toDouble()),
        'usable_duration_days': it['usable_duration_days'],
        'use_by_date': it['use_by_date'],
      };
    }).toList();

    return await createPurchase(
      referenceNo: ref,
      purchaseDate: purchaseDate,
      supplierName: supplierName,
      paymentStatus: paymentStatus,
      items: formattedItems,
      notes: notes,
    );
  }

  Future<int> createPurchase({
    required String referenceNo,
    required String purchaseDate,
    String? supplierName,
    String paymentStatus = 'paid',
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    if (items.isEmpty) throw ArgumentError('Purchase must contain at least one item');

    // Pre-calculate conversions before transaction to avoid nested DB connection locks
    final resolvedItems = <Map<String, dynamic>>[];
    for (final it in items) {
      final ingredientId = it['ingredient_id'] as int;
      final pkgQty = (it['package_quantity'] as num).toDouble();
      final pkgUnit = it['package_unit'] as String;
      final totalCost = (it['total_cost'] as num).toDouble();
      final durationDays = it['usable_duration_days'] as int?;
      final useByDate = it['use_by_date'] as String?;

      final conv = await _ingredientService.convertPackageToStock(
        ingredientId: ingredientId,
        packageUnit: pkgUnit,
        packageQuantity: pkgQty,
      );

      final stockQty = (conv['stock_quantity'] as num).toDouble();
      final multiplier = (conv['multiplier'] as num).toDouble();
      final stockUnit = conv['stock_unit'] as String;
      final unitCost = stockQty > 0 ? (totalCost / stockQty) : 0.0;

      String? usableEndDate;
      if (durationDays != null && durationDays > 0) {
        final pDate = DateTime.parse(purchaseDate);
        usableEndDate = pDate.add(Duration(days: durationDays - 1)).toIso8601String().substring(0, 10);
      }

      resolvedItems.add({
        'ingredient_id': ingredientId,
        'package_quantity': pkgQty,
        'package_unit': pkgUnit,
        'total_cost': totalCost,
        'usable_duration_days': durationDays,
        'use_by_date': useByDate,
        'usable_end_date': usableEndDate,
        'stock_quantity': stockQty,
        'conversion_multiplier': multiplier,
        'stock_unit': stockUnit,
        'unit_cost': unitCost,
      });
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', {
        'reference_no': referenceNo.trim(),
        'purchase_date': purchaseDate,
        'supplier_name': supplierName?.trim(),
        'status': 'confirmed',
        'total_amount': 0.0,
        'payment_status': paymentStatus,
        'notes': notes?.trim(),
        'created_at': now,
        'updated_at': now,
      });

      double totalPurchaseAmount = 0.0;

      for (final it in resolvedItems) {
        final ingredientId = it['ingredient_id'] as int;
        final pkgQty = (it['package_quantity'] as num).toDouble();
        final pkgUnit = it['package_unit'] as String;
        final totalCost = (it['total_cost'] as num).toDouble();
        final durationDays = it['usable_duration_days'] as int?;
        final useByDate = it['use_by_date'] as String?;
        final stockQty = (it['stock_quantity'] as num).toDouble();
        final multiplier = (it['conversion_multiplier'] as num).toDouble();
        final stockUnit = it['stock_unit'] as String;
        final unitCost = (it['unit_cost'] as num).toDouble();
        final usableEndDate = it['usable_end_date'] as String?;

        final itemId = await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'ingredient_id': ingredientId,
          'package_quantity': pkgQty,
          'package_unit': pkgUnit,
          'conversion_multiplier': multiplier,
          'stock_quantity': stockQty,
          'stock_unit': stockUnit,
          'total_cost': totalCost,
          'unit_cost': unitCost,
          'usable_duration_days': durationDays,
          'use_by_date': useByDate,
          'created_at': now,
        });

        final batchCode = 'BAT-$purchaseId-$itemId-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';
        final batchId = await txn.insert('stock_batches', {
          'batch_code': batchCode,
          'ingredient_id': ingredientId,
          'purchase_item_id': itemId,
          'source_type': 'purchase',
          'purchase_date': purchaseDate,
          'initial_quantity': stockQty,
          'remaining_quantity': stockQty,
          'unit_cost': unitCost,
          'use_by_date': useByDate,
          'usable_duration_days': durationDays,
          'usable_end_date': usableEndDate,
          'status': 'active',
          'notes': 'Purchase #$referenceNo item $itemId',
          'created_at': now,
          'updated_at': now,
        });

        final movCode = 'MOV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
        await txn.insert('stock_movements', {
          'movement_code': movCode,
          'ingredient_id': ingredientId,
          'batch_id': batchId,
          'movement_type': 'purchase',
          'quantity': stockQty,
          'unit_cost': unitCost,
          'total_cost': totalCost,
          'movement_date': purchaseDate,
          'reference_type': 'purchase',
          'reference_id': purchaseId,
          'notes': 'Purchase #$referenceNo stock receipt',
          'created_at': now,
        });

        totalPurchaseAmount += totalCost;
      }

      await txn.update(
        'purchases',
        {'total_amount': totalPurchaseAmount},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      await AuditService.log(
        actionType: 'insert',
        tableName: 'purchases',
        recordId: purchaseId,
        newValues: {'reference_no': referenceNo, 'amount': totalPurchaseAmount},
        description: 'Recorded purchase #$referenceNo total LKR $totalPurchaseAmount',
        txn: txn,
      );

      return purchaseId;
    });
  }

  Future<void> cancelPurchase(int purchaseId, String reason) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await _inventoryService.reverseMovementsForReference(
        txn: txn,
        referenceType: 'purchase',
        referenceId: purchaseId,
        reversalReason: reason,
      );

      await txn.update(
        'purchases',
        {'status': 'cancelled', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      await AuditService.log(
        actionType: 'cancel',
        tableName: 'purchases',
        recordId: purchaseId,
        description: 'Cancelled purchase $purchaseId: $reason',
        txn: txn,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getPurchases({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (startDate != null) {
      whereClause += ' AND purchase_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      whereClause += ' AND purchase_date <= ?';
      args.add(endDate);
    }

    return await db.query(
      'purchases',
      where: whereClause,
      whereArgs: args,
      orderBy: 'purchase_date DESC, id DESC',
    );
  }

  Future<Map<String, dynamic>?> getPurchaseById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query('purchases', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        pi.*,
        i.name as ingredient_name
      FROM purchase_items pi
      JOIN ingredients i ON pi.ingredient_id = i.id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
    ''', [purchaseId]);
  }
}
