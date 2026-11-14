import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class IngredientService {
  final DatabaseHelper _dbHelper;

  IngredientService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getIngredients({bool activeOnly = false}) async {
    final db = await _dbHelper.database;
    if (activeOnly) {
      return await db.query('ingredients', where: 'is_active = 1', orderBy: 'id ASC');
    }
    return await db.query('ingredients', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getIngredientById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> createIngredient({
    required String name,
    required String measurementUnit,
    double minStockLevel = 0.0,
    int? defaultUsableDays,
    String? defaultStorageInfo,
    String? description,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Ingredient name cannot be empty');

    final db = await _dbHelper.database;
    final dup = await db.query(
      'ingredients',
      where: 'LOWER(name) = ?',
      whereArgs: [cleanName.toLowerCase()],
    );
    if (dup.isNotEmpty) throw StateError('Ingredient "$cleanName" already exists');

    final now = DateTime.now().toIso8601String();
    return await db.transaction((txn) async {
      final iid = await txn.insert('ingredients', {
        'name': cleanName,
        'description': description?.trim(),
        'measurement_unit': measurementUnit.trim(),
        'min_stock_level': minStockLevel,
        'default_usable_days': defaultUsableDays,
        'default_storage_info': defaultStorageInfo?.trim(),
        'is_active': 1,
        'notes': notes?.trim(),
        'created_at': now,
        'updated_at': now,
      });

      await AuditService.log(
        actionType: 'insert',
        tableName: 'ingredients',
        recordId: iid,
        newValues: {'name': cleanName, 'unit': measurementUnit},
        description: 'Created ingredient: $cleanName ($measurementUnit)',
        txn: txn,
      );

      return iid;
    });
  }

  Future<void> updateIngredient({
    required int id,
    required String name,
    required String measurementUnit,
    required double minStockLevel,
    int? defaultUsableDays,
    String? defaultStorageInfo,
    String? description,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Ingredient name cannot be empty');

    final db = await _dbHelper.database;
    final dup = await db.query(
      'ingredients',
      where: 'LOWER(name) = ? AND id != ?',
      whereArgs: [cleanName.toLowerCase(), id],
    );
    if (dup.isNotEmpty) throw StateError('Another ingredient named "$cleanName" already exists');

    final now = DateTime.now().toIso8601String();
    await db.update(
      'ingredients',
      {
        'name': cleanName,
        'description': description?.trim(),
        'measurement_unit': measurementUnit.trim(),
        'min_stock_level': minStockLevel,
        'default_usable_days': defaultUsableDays,
        'default_storage_info': defaultStorageInfo?.trim(),
        'notes': notes?.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleIngredientStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'ingredients',
      {'is_active': isActive ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getConversions(int ingredientId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'unit_conversions',
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
    );
  }

  Future<void> setConversion({
    required int ingredientId,
    required String purchaseUnit,
    required String stockUnit,
    required double multiplier,
  }) async {
    if (multiplier <= 0) throw ArgumentError('Multiplier must be greater than zero');
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.delete(
      'unit_conversions',
      where: 'ingredient_id = ? AND LOWER(purchase_unit) = ?',
      whereArgs: [ingredientId, purchaseUnit.trim().toLowerCase()],
    );

    await db.insert('unit_conversions', {
      'ingredient_id': ingredientId,
      'purchase_unit': purchaseUnit.trim().toLowerCase(),
      'stock_unit': stockUnit.trim().toLowerCase(),
      'multiplier': multiplier,
      'created_at': now,
    });
  }

  /// Converts purchase package quantity into base stock quantity
  Future<Map<String, dynamic>> convertPackageToStock({
    required int ingredientId,
    required String packageUnit,
    required double packageQuantity,
  }) async {
    final ing = await getIngredientById(ingredientId);
    if (ing == null) throw StateError('Ingredient not found');

    final stockUnit = ing['measurement_unit'] as String;
    final cleanPkgUnit = packageUnit.trim().toLowerCase();
    final cleanStockUnit = stockUnit.trim().toLowerCase();

    if (cleanPkgUnit == cleanStockUnit) {
      return {
        'stock_quantity': packageQuantity,
        'multiplier': 1.0,
        'stock_unit': stockUnit,
      };
    }

    final db = await _dbHelper.database;
    final conv = await db.query(
      'unit_conversions',
      where: 'ingredient_id = ? AND LOWER(purchase_unit) = ?',
      whereArgs: [ingredientId, cleanPkgUnit],
    );

    if (conv.isNotEmpty) {
      final mult = (conv.first['multiplier'] as num).toDouble();
      return {
        'stock_quantity': packageQuantity * mult,
        'multiplier': mult,
        'stock_unit': stockUnit,
      };
    }

    return {
      'stock_quantity': packageQuantity,
      'multiplier': 1.0,
      'stock_unit': stockUnit,
    };
  }
}
