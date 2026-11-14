import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class ProductService {
  final DatabaseHelper _dbHelper;

  ProductService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getProducts({bool activeOnly = false}) async {
    final db = await _dbHelper.database;
    if (activeOnly) {
      return await db.query('products', where: 'is_active = 1', orderBy: 'id ASC');
    }
    return await db.query('products', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> createProduct({
    required String name,
    required double sellingPrice,
    String? description,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Product name cannot be empty');
    if (sellingPrice < 0) throw ArgumentError('Product selling price cannot be negative');

    final db = await _dbHelper.database;

    final existing = await db.query(
      'products',
      where: 'LOWER(name) = ?',
      whereArgs: [cleanName.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw StateError('A product with the name "$cleanName" already exists');
    }

    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final pid = await txn.insert('products', {
        'name': cleanName,
        'description': description?.trim(),
        'selling_price': sellingPrice,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Record price history
      await txn.insert('product_price_history', {
        'product_id': pid,
        'old_price': 0.00,
        'new_price': sellingPrice,
        'changed_at': now,
        'changed_by': 'owner',
        'reason': 'Initial product price setup',
      });

      await AuditService.log(
        actionType: 'insert',
        tableName: 'products',
        recordId: pid,
        newValues: {'name': cleanName, 'price': sellingPrice},
        description: 'Created product: $cleanName with price LKR $sellingPrice',
        txn: txn,
      );

      return pid;
    });
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required double newPrice,
    String? description,
    String? priceChangeReason,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Product name cannot be empty');
    if (newPrice < 0) throw ArgumentError('Product selling price cannot be negative');

    final db = await _dbHelper.database;
    final current = await getProductById(id);
    if (current == null) throw StateError('Product not found');

    final dup = await db.query(
      'products',
      where: 'LOWER(name) = ? AND id != ?',
      whereArgs: [cleanName.toLowerCase(), id],
    );
    if (dup.isNotEmpty) throw StateError('Another product named "$cleanName" already exists');

    final oldPrice = (current['selling_price'] as num).toDouble();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'products',
        {
          'name': cleanName,
          'description': description?.trim(),
          'selling_price': newPrice,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if ((newPrice - oldPrice).abs() > 0.001) {
        await txn.insert('product_price_history', {
          'product_id': id,
          'old_price': oldPrice,
          'new_price': newPrice,
          'changed_at': now,
          'changed_by': 'owner',
          'reason': priceChangeReason ?? 'Price update from management',
        });
      }

      await AuditService.log(
        actionType: 'update',
        tableName: 'products',
        recordId: id,
        oldValues: current,
        newValues: {'name': cleanName, 'price': newPrice},
        description: 'Updated product $id: $cleanName (Price: $oldPrice -> $newPrice)',
        txn: txn,
      );
    });
  }

  Future<void> toggleProductStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'products',
      {'is_active': isActive ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(int productId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'product_price_history',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'changed_at DESC',
    );
  }
}
