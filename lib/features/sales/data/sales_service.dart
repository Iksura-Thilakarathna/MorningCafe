import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';
import '../../inventory/data/inventory_service.dart';
import '../../products/data/product_service.dart';
import '../../recipes/data/recipe_service.dart';

class SalesService {
  final DatabaseHelper _dbHelper;
  final ProductService _productService;
  final RecipeService _recipeService;
  final InventoryService _inventoryService;

  SalesService([
    DatabaseHelper? dbHelper,
    ProductService? productService,
    RecipeService? recipeService,
    InventoryService? inventoryService,
  ])  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _productService = productService ?? ProductService(dbHelper),
        _recipeService = recipeService ?? RecipeService(dbHelper),
        _inventoryService = inventoryService ?? InventoryService(dbHelper);

  Future<_PreparedSaleData> _prepareSaleData(String saleDate, Map<int, int> productQuantities) async {
    final processedLines = <Map<String, dynamic>>[];
    final aggregatedTheoreticalUsage = <int, Map<String, dynamic>>{};
    double totalRevenue = 0.0;

    for (final entry in productQuantities.entries) {
      final productId = entry.key;
      final qtySold = entry.value;
      if (qtySold <= 0) continue;

      final product = await _productService.getProductById(productId);
      if (product == null) continue;

      final currentSellingPrice = (product['selling_price'] as num).toDouble();
      final lineTotal = qtySold * currentSellingPrice;
      totalRevenue += lineTotal;

      final recipe = await _recipeService.getRecipeForProduct(productId);
      int? recipeVersionId;
      if (recipe != null) {
        final version = await _recipeService.getActiveRecipeVersion(recipe['id'] as int, saleDate);
        if (version != null) {
          recipeVersionId = version['id'] as int;
          final items = await _recipeService.getRecipeItems(recipeVersionId);

          for (final it in items) {
            final ingId = it['ingredient_id'] as int;
            final perProduct = (it['quantity'] as num).toDouble();
            final totalIngQty = perProduct * qtySold;

            if (aggregatedTheoreticalUsage.containsKey(ingId)) {
              aggregatedTheoreticalUsage[ingId]!['quantity'] += totalIngQty;
            } else {
              aggregatedTheoreticalUsage[ingId] = {
                'ingredient_id': ingId,
                'name': it['ingredient_name'],
                'unit': it['unit'],
                'quantity': totalIngQty,
              };
            }
          }
        }
      }

      processedLines.add({
        'product_id': productId,
        'recipe_version_id': recipeVersionId,
        'quantity_sold': qtySold,
        'unit_price': currentSellingPrice,
        'line_total': lineTotal,
      });
    }

    return _PreparedSaleData(
      totalRevenue: totalRevenue,
      processedLines: processedLines,
      aggregatedTheoreticalUsage: aggregatedTheoreticalUsage,
    );
  }

  /// Records daily sales with product revenue calculation and FIFO ingredient stock consumption
  Future<int> recordDailySales({
    required String saleDate,
    required Map<int, int> productQuantities,
    Map<int, double>? customActualUsage,
    String? notes,
  }) async {
    final db = await _dbHelper.database;

    // Check duplicate daily sale for this date
    final existing = await db.query(
      'daily_sales',
      where: 'sale_date = ?',
      whereArgs: [saleDate],
    );
    if (existing.isNotEmpty) {
      throw StateError('Daily sales for $saleDate have already been recorded');
    }

    // Pre-fetch product & recipe data before transaction to avoid nested connection locks
    final prep = await _prepareSaleData(saleDate, productQuantities);
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final saleId = await txn.insert('daily_sales', {
        'sale_date': saleDate,
        'total_revenue': prep.totalRevenue,
        'total_cogs': 0.0,
        'notes': notes?.trim(),
        'is_reconciled': 0,
        'created_at': now,
        'updated_at': now,
      });

      for (final line in prep.processedLines) {
        await txn.insert('daily_sale_items', {
          'daily_sale_id': saleId,
          'product_id': line['product_id'],
          'recipe_version_id': line['recipe_version_id'],
          'quantity_sold': line['quantity_sold'],
          'unit_price': line['unit_price'],
          'line_total': line['line_total'],
          'line_cogs': 0.0,
          'created_at': now,
        });
      }

      double totalCogs = 0.0;
      final allIngredientIds = {...prep.aggregatedTheoreticalUsage.keys, ...(customActualUsage?.keys ?? [])};

      for (final ingId in allIngredientIds) {
        final theo = prep.aggregatedTheoreticalUsage[ingId];
        final theoQty = theo != null ? (theo['quantity'] as double) : 0.0;
        final actualQty = (customActualUsage != null && customActualUsage.containsKey(ingId))
            ? customActualUsage[ingId]!
            : theoQty;

        if (actualQty <= 0) continue;

        final ing = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingId]);
        final unit = ing.isNotEmpty ? (ing.first['measurement_unit'] as String) : (theo?['unit'] ?? 'units');

        final consumeResult = await _inventoryService.consumeIngredientFIFO(
          txn: txn,
          ingredientId: ingId,
          quantityToConsume: actualQty,
          referenceType: 'sale',
          referenceId: saleId,
          movementDate: saleDate,
          notes: 'Daily sales consumption for $saleDate',
        );

        final ingCost = (consumeResult['total_cost'] as num).toDouble();
        totalCogs += ingCost;

        final variance = actualQty - theoQty;
        final unitCost = actualQty > 0 ? (ingCost / actualQty) : 0.0;

        await txn.insert('ingredient_usage_records', {
          'daily_sale_id': saleId,
          'ingredient_id': ingId,
          'theoretical_quantity': theoQty,
          'actual_quantity': actualQty,
          'unit': unit,
          'unit_cost': unitCost,
          'total_cost': ingCost,
          'variance_quantity': variance,
          'is_confirmed': 1,
          'notes': 'Recorded with daily sale #$saleId',
          'created_at': now,
        });
      }

      await txn.update(
        'daily_sales',
        {
          'total_revenue': prep.totalRevenue,
          'total_cogs': totalCogs,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await AuditService.log(
        actionType: 'insert',
        tableName: 'daily_sales',
        recordId: saleId,
        newValues: {'date': saleDate, 'revenue': prep.totalRevenue, 'cogs': totalCogs},
        description: 'Recorded daily sales for $saleDate (Revenue: LKR ${prep.totalRevenue}, COGS: LKR $totalCogs)',
        txn: txn,
      );

      return saleId;
    });
  }

  Future<void> editDailySales({
    required int saleId,
    required Map<int, int> productQuantities,
    Map<int, double>? customActualUsage,
    String? notes,
  }) async {
    await updateDailySales(
      saleId: saleId,
      productQuantities: productQuantities,
      customActualUsage: customActualUsage,
      notes: notes,
    );
  }

  /// Updates an existing daily sales record safely (reverses prior stock movements and re-applies consumption)
  Future<void> updateDailySales({
    required int saleId,
    required Map<int, int> productQuantities,
    Map<int, double>? customActualUsage,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final sale = await getDailySaleById(saleId);
    if (sale == null) throw StateError('Sale record not found');

    final saleDate = sale['sale_date'] as String;
    final prep = await _prepareSaleData(saleDate, productQuantities);
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Revert previous stock movements
      await _inventoryService.reverseMovementsForReference(
        txn: txn,
        referenceType: 'sale',
        referenceId: saleId,
        reversalReason: 'Correction/Edit of daily sale #$saleId',
      );

      // 2. Clear old sale items and usage records
      await txn.delete('daily_sale_items', where: 'daily_sale_id = ?', whereArgs: [saleId]);
      await txn.delete('ingredient_usage_records', where: 'daily_sale_id = ?', whereArgs: [saleId]);

      // 3. Insert new sale items
      for (final line in prep.processedLines) {
        await txn.insert('daily_sale_items', {
          'daily_sale_id': saleId,
          'product_id': line['product_id'],
          'recipe_version_id': line['recipe_version_id'],
          'quantity_sold': line['quantity_sold'],
          'unit_price': line['unit_price'],
          'line_total': line['line_total'],
          'line_cogs': 0.0,
          'created_at': now,
        });
      }

      double totalCogs = 0.0;
      final allIngredientIds = {...prep.aggregatedTheoreticalUsage.keys, ...(customActualUsage?.keys ?? [])};

      for (final ingId in allIngredientIds) {
        final theo = prep.aggregatedTheoreticalUsage[ingId];
        final theoQty = theo != null ? (theo['quantity'] as double) : 0.0;
        final actualQty = (customActualUsage != null && customActualUsage.containsKey(ingId))
            ? customActualUsage[ingId]!
            : theoQty;

        if (actualQty <= 0) continue;

        final ing = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingId]);
        final unit = ing.isNotEmpty ? (ing.first['measurement_unit'] as String) : (theo?['unit'] ?? 'units');

        final consumeResult = await _inventoryService.consumeIngredientFIFO(
          txn: txn,
          ingredientId: ingId,
          quantityToConsume: actualQty,
          referenceType: 'sale',
          referenceId: saleId,
          movementDate: saleDate,
          notes: 'Re-applied daily sales consumption for $saleDate',
        );

        final ingCost = (consumeResult['total_cost'] as num).toDouble();
        totalCogs += ingCost;

        final variance = actualQty - theoQty;
        final unitCost = actualQty > 0 ? (ingCost / actualQty) : 0.0;

        await txn.insert('ingredient_usage_records', {
          'daily_sale_id': saleId,
          'ingredient_id': ingId,
          'theoretical_quantity': theoQty,
          'actual_quantity': actualQty,
          'unit': unit,
          'unit_cost': unitCost,
          'total_cost': ingCost,
          'variance_quantity': variance,
          'is_confirmed': 1,
          'notes': 'Updated with daily sale #$saleId',
          'created_at': now,
        });
      }

      await txn.update(
        'daily_sales',
        {
          'total_revenue': prep.totalRevenue,
          'total_cogs': totalCogs,
          'notes': notes?.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await AuditService.log(
        actionType: 'update',
        tableName: 'daily_sales',
        recordId: saleId,
        description: 'Corrected daily sale #$saleId (New Revenue: LKR ${prep.totalRevenue}, New COGS: LKR $totalCogs)',
        txn: txn,
      );
    });
  }

  Future<void> cancelSale(int saleId, String reason) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await _inventoryService.reverseMovementsForReference(
        txn: txn,
        referenceType: 'sale',
        referenceId: saleId,
        reversalReason: reason,
      );

      await txn.update(
        'daily_sales',
        {'notes': 'CANCELLED: $reason', 'total_revenue': 0.0, 'total_cogs': 0.0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await AuditService.log(
        actionType: 'cancel',
        tableName: 'daily_sales',
        recordId: saleId,
        description: 'Cancelled daily sale #$saleId: $reason',
        txn: txn,
      );
    });
  }

  Future<List<Map<String, dynamic>>> previewRecipeRequirements(Map<int, int> productQuantities) async {
    final aggregated = <int, Map<String, dynamic>>{};

    for (final entry in productQuantities.entries) {
      final pid = entry.key;
      final qty = entry.value;
      if (qty <= 0) continue;

      final recipe = await _recipeService.getRecipeForProduct(pid);
      if (recipe == null) continue;

      final version = await _recipeService.getActiveRecipeVersion(recipe['id'] as int);
      if (version == null) continue;

      final items = await _recipeService.getRecipeItems(version['id'] as int);
      for (final it in items) {
        final ingId = it['ingredient_id'] as int;
        final req = (it['quantity'] as num).toDouble() * qty;

        if (aggregated.containsKey(ingId)) {
          aggregated[ingId]!['total_quantity'] += req;
        } else {
          aggregated[ingId] = {
            'ingredient_id': ingId,
            'ingredient_name': it['ingredient_name'],
            'unit': it['unit'],
            'total_quantity': req,
          };
        }
      }
    }

    return aggregated.values.toList();
  }

  Future<List<Map<String, dynamic>>> getDailySales({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (startDate != null) {
      whereClause += ' AND sale_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      whereClause += ' AND sale_date <= ?';
      args.add(endDate);
    }

    return await db.query(
      'daily_sales',
      where: whereClause,
      whereArgs: args,
      orderBy: 'sale_date DESC, id DESC',
    );
  }

  Future<Map<String, dynamic>?> getDailySaleById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query('daily_sales', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getDailySaleItems(int dailySaleId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        dsi.*,
        p.name as product_name
      FROM daily_sale_items dsi
      JOIN products p ON dsi.product_id = p.id
      WHERE dsi.daily_sale_id = ?
      ORDER BY p.id ASC
    ''', [dailySaleId]);
  }

  Future<List<Map<String, dynamic>>> getIngredientUsageForSale(int dailySaleId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        iur.*,
        i.name as ingredient_name
      FROM ingredient_usage_records iur
      JOIN ingredients i ON iur.ingredient_id = i.id
      WHERE iur.daily_sale_id = ?
      ORDER BY i.name ASC
    ''', [dailySaleId]);
  }
}

class _PreparedSaleData {
  final double totalRevenue;
  final List<Map<String, dynamic>> processedLines;
  final Map<int, Map<String, dynamic>> aggregatedTheoreticalUsage;

  _PreparedSaleData({
    required this.totalRevenue,
    required this.processedLines,
    required this.aggregatedTheoreticalUsage,
  });
}
