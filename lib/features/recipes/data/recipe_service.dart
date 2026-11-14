import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class RecipeService {
  final DatabaseHelper _dbHelper;

  RecipeService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Map<String, dynamic>?> getRecipeForProduct(int productId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'product_recipes',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [productId],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getActiveRecipeVersion(int recipeId, [String? targetDate]) async {
    final date = targetDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final db = await _dbHelper.database;
    final res = await db.query(
      'product_recipe_versions',
      where: 'recipe_id = ? AND effective_from <= ?',
      whereArgs: [recipeId, date],
      orderBy: 'effective_from DESC, version_number DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;

    // Fallback: earliest available version
    final fallback = await db.query(
      'product_recipe_versions',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'version_number ASC',
      limit: 1,
    );
    return fallback.isNotEmpty ? fallback.first : null;
  }

  Future<List<Map<String, dynamic>>> getRecipeItems(int versionId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        pri.id,
        pri.recipe_version_id,
        pri.ingredient_id,
        pri.quantity,
        pri.unit,
        i.name as ingredient_name,
        i.measurement_unit as stock_unit
      FROM product_recipe_items pri
      JOIN ingredients i ON pri.ingredient_id = i.id
      WHERE pri.recipe_version_id = ?
      ORDER BY i.name ASC
    ''', [versionId]);
  }

  Future<int> createNewRecipeVersion({
    required int recipeId,
    required List<Map<String, dynamic>> items,
    required String effectiveFrom,
    String? notes,
  }) async {
    if (items.isEmpty) throw ArgumentError('Recipe must have at least one ingredient');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final latest = await txn.query(
        'product_recipe_versions',
        columns: ['version_number'],
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
        orderBy: 'version_number DESC',
        limit: 1,
      );
      final nextVer = latest.isNotEmpty ? (latest.first['version_number'] as int) + 1 : 1;

      final vid = await txn.insert('product_recipe_versions', {
        'recipe_id': recipeId,
        'version_number': nextVer,
        'effective_from': effectiveFrom,
        'notes': notes?.trim(),
        'created_at': now,
      });

      for (final item in items) {
        await txn.insert('product_recipe_items', {
          'recipe_version_id': vid,
          'ingredient_id': item['ingredient_id'],
          'quantity': (item['quantity'] as num).toDouble(),
          'unit': (item['unit'] as String).trim(),
        });
      }

      await AuditService.log(
        actionType: 'insert',
        tableName: 'product_recipe_versions',
        recordId: vid,
        description: 'Created recipe version $nextVer for recipe $recipeId (Effective: $effectiveFrom)',
        txn: txn,
      );

      return vid;
    });
  }

  /// Calculates theoretical ingredient consumption for a product and quantity sold
  Future<List<Map<String, dynamic>>> calculateTheoreticalUsage({
    required int productId,
    required int quantitySold,
    String? saleDate,
  }) async {
    if (quantitySold <= 0) return [];

    final recipe = await getRecipeForProduct(productId);
    if (recipe == null) return [];

    final version = await getActiveRecipeVersion(recipe['id'] as int, saleDate);
    if (version == null) return [];

    final items = await getRecipeItems(version['id'] as int);
    final usage = <Map<String, dynamic>>[];

    for (final item in items) {
      final perProductQty = (item['quantity'] as num).toDouble();
      final totalQty = perProductQty * quantitySold;

      usage.add({
        'ingredient_id': item['ingredient_id'],
        'ingredient_name': item['ingredient_name'],
        'recipe_version_id': version['id'],
        'per_product_quantity': perProductQty,
        'total_quantity': totalQty,
        'unit': item['unit'],
      });
    }

    return usage;
  }
}
