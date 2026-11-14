import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // For testing: allow injecting an in-memory or custom Database
  static void setDatabaseForTesting(Database testDb) {
    _database = testDb;
  }

  static Future<Database> createInMemoryDatabase() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await instance._createDB(db, version);
      },
      onConfigure: instance._onConfigure,
    );
    setDatabaseForTesting(db);
    return db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('morning_cafe.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Incremental future migrations
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Products
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        selling_price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Product Price History
    await db.execute('''
      CREATE TABLE product_price_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        old_price REAL NOT NULL,
        new_price REAL NOT NULL,
        changed_at TEXT NOT NULL,
        changed_by TEXT,
        reason TEXT
      )
    ''');

    // 3. Ingredients
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        measurement_unit TEXT NOT NULL,
        min_stock_level REAL NOT NULL DEFAULT 0.0,
        default_usable_days INTEGER,
        default_storage_info TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Ingredient Units
    await db.execute('''
      CREATE TABLE ingredient_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_name TEXT UNIQUE NOT NULL,
        abbreviation TEXT NOT NULL,
        unit_type TEXT NOT NULL
      )
    ''');

    // 5. Unit Conversions
    await db.execute('''
      CREATE TABLE unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
        purchase_unit TEXT NOT NULL,
        stock_unit TEXT NOT NULL,
        multiplier REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 6. Product Recipes
    await db.execute('''
      CREATE TABLE product_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 7. Product Recipe Versions
    await db.execute('''
      CREATE TABLE product_recipe_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL REFERENCES product_recipes(id) ON DELETE RESTRICT,
        version_number INTEGER NOT NULL,
        effective_from TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 8. Product Recipe Items
    await db.execute('''
      CREATE TABLE product_recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_version_id INTEGER NOT NULL REFERENCES product_recipe_versions(id) ON DELETE CASCADE,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL
      )
    ''');

    // 9. Purchases
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_no TEXT UNIQUE NOT NULL,
        purchase_date TEXT NOT NULL,
        supplier_name TEXT,
        status TEXT NOT NULL DEFAULT 'confirmed',
        total_amount REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 10. Purchase Items
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        package_quantity REAL NOT NULL,
        package_unit TEXT NOT NULL,
        conversion_multiplier REAL NOT NULL DEFAULT 1.0,
        stock_quantity REAL NOT NULL,
        stock_unit TEXT NOT NULL,
        total_cost REAL NOT NULL,
        unit_cost REAL NOT NULL,
        usable_duration_days INTEGER,
        use_by_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 11. Stock Batches
    await db.execute('''
      CREATE TABLE stock_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_code TEXT UNIQUE NOT NULL,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        purchase_item_id INTEGER REFERENCES purchase_items(id) ON DELETE SET NULL,
        source_type TEXT NOT NULL DEFAULT 'purchase',
        purchase_date TEXT NOT NULL,
        initial_quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        use_by_date TEXT,
        usable_duration_days INTEGER,
        usable_end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 12. Stock Movements
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movement_code TEXT UNIQUE NOT NULL,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        batch_id INTEGER REFERENCES stock_batches(id) ON DELETE SET NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        movement_date TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 13. Daily Sales
    await db.execute('''
      CREATE TABLE daily_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_date TEXT UNIQUE NOT NULL,
        total_revenue REAL NOT NULL DEFAULT 0.0,
        total_cogs REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        is_reconciled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 14. Daily Sale Items
    await db.execute('''
      CREATE TABLE daily_sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_sale_id INTEGER NOT NULL REFERENCES daily_sales(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        recipe_version_id INTEGER REFERENCES product_recipe_versions(id) ON DELETE RESTRICT,
        quantity_sold INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        line_total REAL NOT NULL,
        line_cogs REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    // 15. Ingredient Usage Records
    await db.execute('''
      CREATE TABLE ingredient_usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_sale_id INTEGER NOT NULL REFERENCES daily_sales(id) ON DELETE CASCADE,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        theoretical_quantity REAL NOT NULL,
        actual_quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        variance_quantity REAL NOT NULL DEFAULT 0.0,
        is_confirmed INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 16. Stock Wastage
    await db.execute('''
      CREATE TABLE stock_wastage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wastage_code TEXT UNIQUE NOT NULL,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        batch_id INTEGER REFERENCES stock_batches(id) ON DELETE SET NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        reason TEXT NOT NULL,
        wastage_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 17. Additional Income
    await db.execute('''
      CREATE TABLE additional_income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_date TEXT NOT NULL,
        received_date TEXT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'received',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 18. Additional Expenses
    await db.execute('''
      CREATE TABLE additional_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_date TEXT NOT NULL,
        paid_date TEXT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        receipt_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 19. Stock Counts
    await db.execute('''
      CREATE TABLE stock_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        count_code TEXT UNIQUE NOT NULL,
        count_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 20. Stock Count Items
    await db.execute('''
      CREATE TABLE stock_count_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_count_id INTEGER NOT NULL REFERENCES stock_counts(id) ON DELETE CASCADE,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        system_quantity REAL NOT NULL,
        physical_quantity REAL NOT NULL,
        difference_quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        adjustment_value REAL NOT NULL,
        adjustment_status TEXT NOT NULL DEFAULT 'adjusted'
      )
    ''');

    // 21. Reporting Periods
    await db.execute('''
      CREATE TABLE reporting_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        sales_revenue REAL NOT NULL,
        cogs REAL NOT NULL,
        gross_profit REAL NOT NULL,
        wastage_cost REAL NOT NULL,
        operating_expenses REAL NOT NULL,
        additional_income REAL NOT NULL,
        net_profit REAL NOT NULL,
        cash_inflows REAL NOT NULL,
        cash_outflows REAL NOT NULL,
        net_cash_flow REAL NOT NULL,
        opening_inventory_value REAL NOT NULL,
        closing_inventory_value REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'finalized',
        is_finalized INTEGER NOT NULL DEFAULT 1,
        finalized_at TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 22. Audit Logs
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER,
        old_values TEXT,
        new_values TEXT,
        action_description TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 23. App Settings
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Performance Indexes
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
    await db.execute('CREATE INDEX idx_ingredients_active ON ingredients(is_active)');
    await db.execute('CREATE INDEX idx_purchases_date ON purchases(purchase_date)');
    await db.execute('CREATE INDEX idx_batches_ing_status ON stock_batches(ingredient_id, status)');
    await db.execute('CREATE INDEX idx_batches_date ON stock_batches(purchase_date)');
    await db.execute('CREATE INDEX idx_movements_date ON stock_movements(movement_date)');
    await db.execute('CREATE INDEX idx_movements_ing ON stock_movements(ingredient_id)');
    await db.execute('CREATE INDEX idx_movements_ref ON stock_movements(reference_type, reference_id)');
    await db.execute('CREATE INDEX idx_sales_date ON daily_sales(sale_date)');
    await db.execute('CREATE INDEX idx_wastage_date ON stock_wastage(wastage_date)');
    await db.execute('CREATE INDEX idx_income_date ON additional_income(transaction_date)');
    await db.execute('CREATE INDEX idx_expenses_date ON additional_expenses(expense_date)');

    // Seed Initial Data
    await seedInitialData(db);
  }

  /// Seeds initial products, ingredients, unit conversions, recipes, settings
  Future<void> seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Initial Products
    await db.insert('products', {
      'id': 1,
      'name': 'Single Sausage Bun',
      'description': 'Freshly baked bun with one juicy sausage and house sauce',
      'selling_price': 120.00,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('products', {
      'id': 2,
      'name': 'Double Sausage Bun',
      'description': 'Hearty bun with two juicy sausages and house sauce',
      'selling_price': 150.00,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('products', {
      'id': 3,
      'name': 'Omelette Burger',
      'description': 'Burger bun with fresh spiced egg omelette and garden greens',
      'selling_price': 150.00,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Initial Price History
    for (int pid = 1; pid <= 3; pid++) {
      final price = (pid == 1) ? 120.00 : 150.00;
      await db.insert('product_price_history', {
        'product_id': pid,
        'old_price': 0.00,
        'new_price': price,
        'changed_at': now,
        'changed_by': 'system_seed',
        'reason': 'Initial product price configuration',
      });
    }

    // 2. Initial Ingredients
    final initialIngredients = [
      {'id': 1, 'name': 'Sausage Buns', 'unit': 'pieces', 'min': 20.0, 'days': 3, 'storage': 'Bakery crate, ambient dry shelf'},
      {'id': 2, 'name': 'Omelette Burger Buns', 'unit': 'pieces', 'min': 15.0, 'days': 3, 'storage': 'Bakery crate, ambient dry shelf'},
      {'id': 3, 'name': 'Sausages', 'unit': 'pieces', 'min': 30.0, 'days': 7, 'storage': 'Chilled refrigerator 2-4 C'},
      {'id': 4, 'name': 'Eggs', 'unit': 'pieces', 'min': 20.0, 'days': 7, 'storage': 'Egg rack, cool storage'},
      {'id': 5, 'name': 'Mayonnaise', 'unit': 'ml', 'min': 200.0, 'days': 7, 'storage': 'Refrigerate after opening'},
      {'id': 6, 'name': 'Tomato Sauce', 'unit': 'ml', 'min': 200.0, 'days': 7, 'storage': 'Refrigerate after opening'},
      {'id': 7, 'name': 'Salad Leaves', 'unit': 'leaves', 'min': 25.0, 'days': 2, 'storage': 'Crisper drawer, chilled'},
      {'id': 8, 'name': 'Cooking Oil', 'unit': 'ml', 'min': 500.0, 'days': null, 'storage': 'Pantry shelf'},
      {'id': 9, 'name': 'Packaging Bags', 'unit': 'pieces', 'min': 50.0, 'days': null, 'storage': 'Packaging dry shelf'},
    ];

    for (final ing in initialIngredients) {
      await db.insert('ingredients', {
        'id': ing['id'],
        'name': ing['name'],
        'description': 'Standard bakery / food ingredient',
        'measurement_unit': ing['unit'],
        'min_stock_level': ing['min'],
        'default_usable_days': ing['days'],
        'default_storage_info': ing['storage'],
        'is_active': 1,
        'notes': 'Default seeded item',
        'created_at': now,
        'updated_at': now,
      });
    }

    // 3. Unit Conversions
    await db.insert('unit_conversions', {
      'ingredient_id': 3,
      'purchase_unit': 'pack',
      'stock_unit': 'pieces',
      'multiplier': 10.0,
      'created_at': now,
    });
    await db.insert('unit_conversions', {
      'ingredient_id': 5,
      'purchase_unit': 'bottle',
      'stock_unit': 'ml',
      'multiplier': 500.0,
      'created_at': now,
    });
    await db.insert('unit_conversions', {
      'ingredient_id': 6,
      'purchase_unit': 'bottle',
      'stock_unit': 'ml',
      'multiplier': 500.0,
      'created_at': now,
    });
    await db.insert('unit_conversions', {
      'ingredient_id': 8,
      'purchase_unit': 'bottle',
      'stock_unit': 'ml',
      'multiplier': 1000.0,
      'created_at': now,
    });
    await db.insert('unit_conversions', {
      'ingredient_id': 9,
      'purchase_unit': 'pack',
      'stock_unit': 'pieces',
      'multiplier': 100.0,
      'created_at': now,
    });

    // 4. Recipes
    await db.insert('product_recipes', {
      'id': 1,
      'product_id': 1,
      'name': 'Standard Single Sausage Bun Recipe',
      'description': '1 bun, 1 sausage, mayo, sauce, salad',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('product_recipes', {
      'id': 2,
      'product_id': 2,
      'name': 'Standard Double Sausage Bun Recipe',
      'description': '1 bun, 2 sausages, mayo, sauce, salad',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('product_recipes', {
      'id': 3,
      'product_id': 3,
      'name': 'Standard Omelette Burger Recipe',
      'description': '1 burger bun, 1 egg, mayo, salad',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Recipe Versions (Version 1, effective 2026-01-01)
    await db.insert('product_recipe_versions', {
      'id': 1,
      'recipe_id': 1,
      'version_number': 1,
      'effective_from': '2026-01-01',
      'notes': 'Initial standard recipe',
      'created_at': now,
    });
    await db.insert('product_recipe_versions', {
      'id': 2,
      'recipe_id': 2,
      'version_number': 1,
      'effective_from': '2026-01-01',
      'notes': 'Initial standard recipe',
      'created_at': now,
    });
    await db.insert('product_recipe_versions', {
      'id': 3,
      'recipe_id': 3,
      'version_number': 1,
      'effective_from': '2026-01-01',
      'notes': 'Initial standard recipe',
      'created_at': now,
    });

    // Recipe Items
    // Single Sausage Bun: 1 sausage bun (id 1), 1 sausage (id 3), 10 ml mayo (id 5), 10 ml tomato sauce (id 6), 1 salad leaf (id 7)
    await db.insert('product_recipe_items', {'recipe_version_id': 1, 'ingredient_id': 1, 'quantity': 1.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 1, 'ingredient_id': 3, 'quantity': 1.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 1, 'ingredient_id': 5, 'quantity': 10.0, 'unit': 'ml'});
    await db.insert('product_recipe_items', {'recipe_version_id': 1, 'ingredient_id': 6, 'quantity': 10.0, 'unit': 'ml'});
    await db.insert('product_recipe_items', {'recipe_version_id': 1, 'ingredient_id': 7, 'quantity': 1.0, 'unit': 'leaves'});

    // Double Sausage Bun: 1 sausage bun (id 1), 2 sausages (id 3), 10 ml mayo (id 5), 10 ml tomato sauce (id 6), 1 salad leaf (id 7)
    await db.insert('product_recipe_items', {'recipe_version_id': 2, 'ingredient_id': 1, 'quantity': 1.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 2, 'ingredient_id': 3, 'quantity': 2.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 2, 'ingredient_id': 5, 'quantity': 10.0, 'unit': 'ml'});
    await db.insert('product_recipe_items', {'recipe_version_id': 2, 'ingredient_id': 6, 'quantity': 10.0, 'unit': 'ml'});
    await db.insert('product_recipe_items', {'recipe_version_id': 2, 'ingredient_id': 7, 'quantity': 1.0, 'unit': 'leaves'});

    // Omelette Burger: 1 burger bun (id 2), 1 egg (id 4), 10 ml mayo (id 5), 1 salad leaf (id 7)
    await db.insert('product_recipe_items', {'recipe_version_id': 3, 'ingredient_id': 2, 'quantity': 1.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 3, 'ingredient_id': 4, 'quantity': 1.0, 'unit': 'pieces'});
    await db.insert('product_recipe_items', {'recipe_version_id': 3, 'ingredient_id': 5, 'quantity': 10.0, 'unit': 'ml'});
    await db.insert('product_recipe_items', {'recipe_version_id': 3, 'ingredient_id': 7, 'quantity': 1.0, 'unit': 'leaves'});

    // 5. App Settings
    await db.insert('app_settings', {'key': 'business_name', 'value': 'Morning Cafe'});
    await db.insert('app_settings', {'key': 'business_location', 'value': 'Piliyandala, Sri Lanka'});
    await db.insert('app_settings', {'key': 'currency', 'value': 'LKR'});
    await db.insert('app_settings', {'key': 'timezone', 'value': 'Asia/Colombo'});
    await db.insert('app_settings', {'key': 'theme_mode', 'value': 'system'});
    await db.insert('app_settings', {'key': 'biometric_enabled', 'value': 'false'});
    await db.insert('app_settings', {'key': 'last_backup_date', 'value': ''});
  }

  /// Execute code inside a transactional block
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Closes database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
