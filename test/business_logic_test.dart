import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:morning_cafe/core/database/database_helper.dart';
import 'package:morning_cafe/core/services/backup_service.dart';
import 'package:morning_cafe/features/finance/data/finance_service.dart';
import 'package:morning_cafe/features/income_expense/data/income_expense_service.dart';
import 'package:morning_cafe/features/ingredients/data/ingredient_service.dart';
import 'package:morning_cafe/features/inventory/data/inventory_service.dart';
import 'package:morning_cafe/features/products/data/product_service.dart';
import 'package:morning_cafe/features/purchases/data/purchase_service.dart';
import 'package:morning_cafe/features/recipes/data/recipe_service.dart';
import 'package:morning_cafe/features/sales/data/sales_service.dart';
import 'package:morning_cafe/features/wastage/data/wastage_service.dart';

void main() {
  // Initialize sqflite ffi for desktop/test execution
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ProductService productService;
  late IngredientService ingredientService;
  late RecipeService recipeService;
  late InventoryService inventoryService;
  late PurchaseService purchaseService;
  late SalesService salesService;
  late WastageService wastageService;
  late IncomeExpenseService incomeExpenseService;
  late FinanceService financeService;
  late BackupService backupService;

  setUp(() async {
    // Fresh in-memory database for each test
    db = await DatabaseHelper.createInMemoryDatabase();
    productService = ProductService();
    ingredientService = IngredientService();
    recipeService = RecipeService();
    inventoryService = InventoryService();
    purchaseService = PurchaseService();
    salesService = SalesService();
    wastageService = WastageService();
    incomeExpenseService = IncomeExpenseService();
    financeService = FinanceService();
    backupService = BackupService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Morning Cafe Business Logic & Financial Integrity Tests', () {
    // -------------------------------------------------------------
    // Test 1: Daily sales revenue calculation
    // -------------------------------------------------------------
    test('1. Daily sales revenue calculation for multiple products', () async {
      // Products seeded:
      // ID 1: Single Sausage Bun @ 120
      // ID 2: Double Sausage Bun @ 150
      // ID 3: Omelette Burger @ 150
      final saleId = await salesService.recordDailySales(
        saleDate: '2026-03-01',
        productQuantities: {
          1: 10, // 10 * 120 = 1200
          2: 10, // 10 * 150 = 1500
          3: 5,  // 5 * 150 = 750
        },
        notes: 'Sunday morning rush',
      );

      final sale = await salesService.getDailySaleById(saleId);
      expect(sale, isNotNull);
      expect(sale!['total_revenue'], equals(3450.0));

      final items = await salesService.getDailySaleItems(saleId);
      final totalUnits = items.fold<int>(0, (sum, i) => sum + (i['quantity_sold'] as int));
      expect(totalUnits, equals(25));

      final allSales = await salesService.getDailySales(
        startDate: '2026-03-01',
        endDate: '2026-03-01',
      );
      expect(allSales.length, equals(1));
      expect(allSales[0]['total_revenue'], equals(3450.0));
    });

    // -------------------------------------------------------------
    // Test 2: Double sausage bun recipe consumption (2 sausages/bun)
    // -------------------------------------------------------------
    test('2. Double sausage bun recipe consumes exactly 2 sausages per bun', () async {
      final recipe = await recipeService.getRecipeForProduct(2); // Double Sausage Bun
      expect(recipe, isNotNull);
      final version = await recipeService.getActiveRecipeVersion(recipe!['id'] as int);
      final items = await recipeService.getRecipeItems(version!['id'] as int);

      // Find sausage ingredient requirement
      final sausageItem = items.firstWhere(
        (i) => (i['ingredient_name'] as String).toLowerCase().contains('sausage') &&
               !(i['ingredient_name'] as String).toLowerCase().contains('bun'),
      );
      expect(sausageItem['quantity'], equals(2.0));

      // Preview consumption for 15 Double Sausage Buns
      final preview = await salesService.previewRecipeRequirements({2: 15});

      final sausageReq = preview.firstWhere(
        (p) => (p['ingredient_name'] as String).toLowerCase().contains('sausage') &&
               !(p['ingredient_name'] as String).toLowerCase().contains('bun'),
      );
      expect(sausageReq['total_quantity'], equals(30.0)); // 15 buns * 2 = 30 sausages
    });

    // -------------------------------------------------------------
    // Test 3: FIFO inventory costing (50@20, 30@22; consume 60 -> 1220)
    // -------------------------------------------------------------
    test('3. FIFO inventory costing: 50 @ 20, 30 @ 22; consume 60 -> cost 1,220, rem qty 20, rem val 440', () async {
      // Create ingredient
      final ingId = await ingredientService.createIngredient(
        name: 'FIFO Test Sausage',
        measurementUnit: 'pcs',
        minStockLevel: 10,
      );

      // Batch 1: 50 pcs @ LKR 20.00
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 50,
        unitCost: 20.00,
        date: '2026-03-01',
      );

      // Batch 2: 30 pcs @ LKR 22.00
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 30,
        unitCost: 22.00,
        date: '2026-03-02',
      );

      // Consume 60 pcs
      final cost = await inventoryService.consumeStockFIFO(
        ingredientId: ingId,
        requiredQuantity: 60,
        transactionType: 'production_sales',
        referenceId: 999,
        transactionDate: '2026-03-03',
      );

      // Expected cost: (50 * 20) + (10 * 22) = 1,000 + 220 = 1,220.00
      expect(cost, equals(1220.00));

      // Remaining stock: 20 pcs in Batch 2 @ 22.00 = 440.00
      final usableQty = await inventoryService.getUsableStock(ingId);
      expect(usableQty, equals(20.0));

      final batches = await inventoryService.getBatchDetails(ingId);
      expect(batches.length, equals(2));
      expect(batches[0]['remaining_quantity'], equals(0.0));
      expect(batches[1]['remaining_quantity'], equals(20.0));

      final remVal = (batches[1]['remaining_quantity'] as num).toDouble() * (batches[1]['unit_cost'] as num).toDouble();
      expect(remVal, equals(440.00));
    });

    // -------------------------------------------------------------
    // Test 4: Weekly net profit formula (21900 + 500 - 8000 - 400 - 1500 = 12500)
    // -------------------------------------------------------------
    test('4. Weekly net profit formula: Sales 21,900, Addl Income 500, COGS 8,000, Wastage 400, Exp 1,500 -> 12,500', () async {
      const sDate = '2026-03-01';
      const eDate = '2026-03-07';

      // 1. Sales: 21,900
      await db.insert('daily_sales', {
        'sale_date': sDate,
        'total_revenue': 21900.0,
        'total_cogs': 8000.0,
        'notes': 'Test sales',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Additional Income: 500
      await incomeExpenseService.recordIncome(
        category: 'Catering / Bulk Order',
        amount: 500.0,
        incomeDate: '2026-03-02',
        paymentMethod: 'cash',
        isReceived: true,
      );

      // 3. Wastage: 400
      final ingId = await ingredientService.createIngredient(
        name: 'Profit Test Ingredient',
        measurementUnit: 'pcs',
      );
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 50,
        unitCost: 20.0,
        date: sDate,
      );
      await wastageService.recordWastage(
        ingredientId: ingId,
        quantity: 20.0,
        reason: 'expired',
        wastageDate: '2026-03-04',
      );

      // 4. Additional Expenses: 1,500
      await incomeExpenseService.recordExpense(
        category: 'Gas / Fuel',
        amount: 1500.0,
        expenseDate: '2026-03-05',
        paymentMethod: 'cash',
        isPaid: true,
      );

      final profitData = await financeService.calculateWeeklyNetProfit(
        startDate: sDate,
        endDate: eDate,
      );

      expect(profitData['sales_revenue'], equals(21900.0));
      expect(profitData['additional_income'], equals(500.0));
      expect(profitData['cogs'], equals(8000.0));
      expect(profitData['wastage_cost'], equals(400.0));
      expect(profitData['operating_expenses'], equals(1500.0));
      expect(profitData['net_profit'], equals(12500.0));
    });

    // -------------------------------------------------------------
    // Test 5: Remaining stock calculation
    // -------------------------------------------------------------
    test('5. Remaining stock calculation (Opening 100 + Purchase 50 - Usage 40 - Wastage 10 = 100)', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Remaining Stock Bread',
        measurementUnit: 'pcs',
      );

      // Opening stock: 100 pcs
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 100,
        unitCost: 10.0,
        date: '2026-03-01',
      );

      // Purchase: 50 pcs
      await purchaseService.recordPurchase(
        supplierName: 'Baker Supplier',
        invoiceNumber: 'INV-100',
        purchaseDate: '2026-03-02',
        paymentStatus: 'paid',
        items: [
          {'ingredient_id': ingId, 'quantity': 50.0, 'unit_price': 12.0, 'unit': 'pcs'},
        ],
      );

      // Usage: 40 pcs
      await inventoryService.consumeStockFIFO(
        ingredientId: ingId,
        requiredQuantity: 40.0,
        transactionType: 'production_sales',
        referenceId: 1,
        transactionDate: '2026-03-03',
      );

      // Wastage: 10 pcs
      await wastageService.recordWastage(
        ingredientId: ingId,
        quantity: 10.0,
        reason: 'spoiled',
        wastageDate: '2026-03-04',
      );

      final currentStock = await inventoryService.getUsableStock(ingId);
      // 100 + 50 - 40 - 10 = 100
      expect(currentStock, equals(100.0));
    });

    // -------------------------------------------------------------
    // Test 6: Stock wastage deduction without double counting
    // -------------------------------------------------------------
    test('6. Stock wastage deduction without double counting', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Wastage Test Patty',
        measurementUnit: 'pcs',
      );

      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 20,
        unitCost: 50.0,
        date: '2026-03-01',
      );

      // Record wastage of 5 units = LKR 250
      await wastageService.recordWastage(
        ingredientId: ingId,
        quantity: 5,
        reason: 'dropped',
        wastageDate: '2026-03-02',
      );

      // Remaining stock should now be 15
      final usable = await inventoryService.getUsableStock(ingId);
      expect(usable, equals(15.0));

      // Financial statement check: wastage is 250, COGS is 0
      final stmt = await financeService.calculateFinancialStatement(
        startDate: '2026-03-01',
        endDate: '2026-03-07',
      );
      expect(stmt['cogs'], equals(0.0));
      expect(stmt['wastage_cost'], equals(250.0));
      expect(stmt['net_profit'], equals(-250.0));
    });

    // -------------------------------------------------------------
    // Test 7: Opening stock capitalization without expense distortion
    // -------------------------------------------------------------
    test('7. Opening stock capitalization without expense distortion', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Capitalization Oil',
        measurementUnit: 'l',
      );

      // Record 10 Liters @ 800 = 8,000 LKR asset
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 10,
        unitCost: 800.0,
        date: '2026-03-01',
      );

      final stmt = await financeService.calculateFinancialStatement(
        startDate: '2026-03-01',
        endDate: '2026-03-07',
      );

      // Opening stock should NOT be recorded as purchases or operating expenses
      expect(stmt['total_purchases'], equals(0.0));
      expect(stmt['operating_expenses'], equals(0.0));
      expect(stmt['cogs'], equals(0.0));
      expect(stmt['net_profit'], equals(0.0));

      // Valuation should be 8,000
      final val = await inventoryService.getTotalInventoryValuation();
      expect(val, equals(8000.0));
    });

    // -------------------------------------------------------------
    // Test 8: Historical selling price preservation across price updates
    // -------------------------------------------------------------
    test('8. Historical selling price preservation across price updates', () async {
      // 1. Initial price of Single Sausage Bun is 120. Record sale.
      await salesService.recordDailySales(
        saleDate: '2026-03-01',
        productQuantities: {
          1: 10, // 10 * 120 = 1200
        },
      );

      // 2. Change product price from 120 to 140
      await productService.updateProduct(
        id: 1,
        name: 'Single Sausage Bun',
        description: 'New price',
        newPrice: 140.0,
      );

      // 3. Verify price history has been recorded
      final history = await productService.getPriceHistory(1);
      expect(history.length, equals(2));
      expect(history[0]['old_price'], equals(120.0));
      expect(history[0]['new_price'], equals(140.0));

      // 4. Verify past sale was NOT modified
      final sales = await salesService.getDailySales(startDate: '2026-03-01', endDate: '2026-03-01');
      expect(sales.length, equals(1));
      expect(sales[0]['total_revenue'], equals(1200.0));
    });

    // -------------------------------------------------------------
    // Test 9: Historical recipe version preservation across updates
    // -------------------------------------------------------------
    test('9. Historical recipe version preservation across recipe updates', () async {
      // Product 1 initial recipe
      final recipe = await recipeService.getRecipeForProduct(1);
      expect(recipe, isNotNull);
      final recipeId = recipe!['id'] as int;

      final v1Version = await recipeService.getActiveRecipeVersion(recipeId, '2026-03-01');
      expect(v1Version!['version_number'], equals(1));

      // Create Version 2 effective 2026-03-05
      final v1Items = await recipeService.getRecipeItems(v1Version['id'] as int);
      final v2Items = v1Items.map((it) {
        return {
          'ingredient_id': it['ingredient_id'],
          'quantity': (it['quantity'] as num).toDouble() * 2,
          'unit': it['unit'],
        };
      }).toList();

      final v2VersionId = await recipeService.createNewRecipeVersion(
        recipeId: recipeId,
        effectiveFrom: '2026-03-05',
        notes: 'Double portions version',
        items: v2Items,
      );
      expect(v2VersionId, isPositive);

      // Verify effective date routing:
      // On 2026-03-02: returns V1
      final v1Check = await recipeService.getActiveRecipeVersion(recipeId, '2026-03-02');
      expect(v1Check!['version_number'], equals(1));

      // On 2026-03-06: returns V2
      final v2Check = await recipeService.getActiveRecipeVersion(recipeId, '2026-03-06');
      expect(v2Check!['version_number'], equals(2));
    });

    // -------------------------------------------------------------
    // Test 10: Late expense entry captured on transaction date
    // -------------------------------------------------------------
    test('10. Late expense entry captured on transaction date, not entry date', () async {
      // Incurred on 2026-03-02 (Week 1), recorded with expenseDate: '2026-03-02'
      await incomeExpenseService.recordExpense(
        category: 'Maintenance & Repairs',
        amount: 2500.0,
        expenseDate: '2026-03-02',
        notes: 'Recorded late',
      );

      // Report for Week 1 (2026-03-01 to 2026-03-07)
      final week1 = await financeService.calculateWeeklyNetProfit(
        startDate: '2026-03-01',
        endDate: '2026-03-07',
      );
      expect(week1['operating_expenses'], equals(2500.0));

      // Report for Week 2 (2026-03-08 to 2026-03-14)
      final week2 = await financeService.calculateWeeklyNetProfit(
        startDate: '2026-03-08',
        endDate: '2026-03-14',
      );
      expect(week2['operating_expenses'], equals(0.0));
    });

    // -------------------------------------------------------------
    // Test 11: Duplicate daily sales prevention
    // -------------------------------------------------------------
    test('11. Duplicate daily sales prevention and safe editing', () async {
      // Record initial sale for 2026-03-01
      final saleId = await salesService.recordDailySales(
        saleDate: '2026-03-01',
        productQuantities: {1: 10},
      );

      // Attempting to record duplicate sale on same date throws StateError
      expect(
        () async => await salesService.recordDailySales(
          saleDate: '2026-03-01',
          productQuantities: {1: 15},
        ),
        throwsA(isA<StateError>()),
      );

      // Safe editing updates cleanly
      await salesService.editDailySales(
        saleId: saleId,
        productQuantities: {1: 15},
      );

      final sale = await salesService.getDailySaleById(saleId);
      expect(sale!['total_revenue'], equals(15 * 120.0));
    });

    // -------------------------------------------------------------
    // Test 12: Zero sales report without division-by-zero
    // -------------------------------------------------------------
    test('12. Zero sales report without division-by-zero or crash', () async {
      final stmt = await financeService.calculateFinancialStatement(
        startDate: '2026-03-01',
        endDate: '2026-03-07',
      );

      expect(stmt['sales_revenue'], equals(0.0));
      expect(stmt['gross_profit'], equals(0.0));
      expect(stmt['net_profit'], equals(0.0));
      expect(stmt['profit_margin'], equals(0.0));
      expect(stmt['cogs'], equals(0.0));
      expect(stmt['wastage_cost'], equals(0.0));
    });

    // -------------------------------------------------------------
    // Test 13: Inventory asset valuation reconciliation
    // -------------------------------------------------------------
    test('13. Inventory asset valuation reconciliation (Opening + Purchases - COGS - Wastage = Closing)', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Reconciliation Sauce',
        measurementUnit: 'ml',
      );

      // Opening: 1000 ml @ 0.50 = 500
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 1000,
        unitCost: 0.50,
        date: '2026-03-01',
      );

      // Purchase: 2000 ml @ 0.60 = 1200
      await purchaseService.recordPurchase(
        supplierName: 'Sauce Co',
        invoiceNumber: 'INV-S1',
        purchaseDate: '2026-03-02',
        paymentStatus: 'paid',
        items: [
          {'ingredient_id': ingId, 'quantity': 2000.0, 'unit_price': 0.60, 'unit': 'ml'},
        ],
      );

      // COGS (consume 1200 ml): 1000 @ 0.50 + 200 @ 0.60 = 500 + 120 = 620
      final cogs = await inventoryService.consumeStockFIFO(
        ingredientId: ingId,
        requiredQuantity: 1200,
        transactionType: 'production_sales',
        referenceId: 10,
        transactionDate: '2026-03-03',
      );
      expect(cogs, equals(620.0));

      // Wastage (waste 100 ml from second batch): 100 @ 0.60 = 60
      await wastageService.recordWastage(
        ingredientId: ingId,
        quantity: 100,
        reason: 'spill',
        wastageDate: '2026-03-04',
      );

      // Remaining stock should be: 3000 - 1200 - 100 = 1700 ml @ 0.60 = 1020
      final usable = await inventoryService.getUsableStock(ingId);
      expect(usable, equals(1700.0));

      final batches = await inventoryService.getBatchDetails(ingId);
      final itemVal = batches.fold<double>(0.0, (sum, b) => sum + (b['remaining_quantity'] as num).toDouble() * (b['unit_cost'] as num).toDouble());
      expect(itemVal, equals(1020.0));

      // Mathematical balance:
      // Opening (500) + Purchases (1200) - COGS (620) - Wastage (60) = 1020.0
      const opening = 500.0;
      const purchases = 1200.0;
      const wastage = 60.0;
      final expectedClosing = opening + purchases - cogs - wastage;
      expect(itemVal, equals(expectedClosing));
    });

    // -------------------------------------------------------------
    // Test 14: Expired stock exclusion from production allocation
    // -------------------------------------------------------------
    test('14. Expired stock exclusion from production allocation', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Perishable Leaf',
        measurementUnit: 'g',
        defaultUsableDays: 1,
      );

      // Batch 1: Expired yesterday
      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 100,
        unitCost: 1.0,
        date: '2026-03-01',
        usableDurationDays: 1,
      );

      // Mark batch 1 expired
      await db.update(
        'stock_batches',
        {'status': 'expired', 'usable_end_date': '2026-03-02'},
        where: 'ingredient_id = ?',
        whereArgs: [ingId],
      );

      // Batch 2: Fresh today (100 units @ 1.50)
      await db.insert('stock_batches', {
        'batch_code': 'FRESH-1',
        'ingredient_id': ingId,
        'source_type': 'purchase',
        'purchase_date': '2026-03-06',
        'initial_quantity': 100.0,
        'remaining_quantity': 100.0,
        'unit_cost': 1.50,
        'usable_end_date': '2026-03-10',
        'status': 'active',
        'created_at': '2026-03-06',
        'updated_at': '2026-03-06',
      });

      // Usable stock should be 100, excluding the 100 expired units
      final usable = await inventoryService.getUsableStock(ingId, '2026-03-06');
      expect(usable, equals(100.0));

      // Consume 20 units - MUST allocate from fresh batch @ 1.50 = 30.0
      final consumedCost = await inventoryService.consumeStockFIFO(
        ingredientId: ingId,
        requiredQuantity: 20,
        transactionType: 'production_sales',
        referenceId: 5,
        transactionDate: '2026-03-06',
      );
      expect(consumedCost, equals(30.0));
    });

    // -------------------------------------------------------------
    // Test 15: Purchase cancellation/reversal
    // -------------------------------------------------------------
    test('15. Purchase cancellation/reversal restores inventory accurately', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Cancel Test Egg',
        measurementUnit: 'pcs',
      );

      // Purchase 50 eggs
      final purchaseId = await purchaseService.recordPurchase(
        supplierName: 'Poultry Farm',
        invoiceNumber: 'INV-PF1',
        purchaseDate: '2026-03-01',
        paymentStatus: 'paid',
        items: [
          {'ingredient_id': ingId, 'quantity': 50.0, 'unit_price': 35.0, 'unit': 'pcs'},
        ],
      );

      expect(await inventoryService.getUsableStock(ingId), equals(50.0));

      // Cancel the purchase
      await purchaseService.cancelPurchase(purchaseId, 'Wrong delivery item');

      // Usable stock must now be 0
      expect(await inventoryService.getUsableStock(ingId), equals(0.0));

      // Check purchase status is cancelled
      final p = await purchaseService.getPurchaseById(purchaseId);
      expect(p!['status'], equals('cancelled'));
    });

    // -------------------------------------------------------------
    // Test 16: Sales edit/correction reconciliation
    // -------------------------------------------------------------
    test('16. Sales cancellation restores consumed inventory', () async {
      // Initial stock of Single Sausage Bun ingredient (sausage)
      final bunIng = await ingredientService.getIngredients();
      final sausageIng = bunIng.firstWhere((i) => i['name'] == 'Sausages');
      final sausageId = sausageIng['id'] as int;

      await inventoryService.recordOpeningStock(
        ingredientId: sausageId,
        quantity: 50,
        unitCost: 25.0,
        date: '2026-03-01',
      );

      // Record sale of 10 Single Sausage Buns (consumes 10 sausages)
      final saleId = await salesService.recordDailySales(
        saleDate: '2026-03-01',
        productQuantities: {1: 10},
      );

      expect(await inventoryService.getUsableStock(sausageId), equals(40.0));

      // Cancel the sale
      await salesService.cancelSale(saleId, 'Customer order returned');

      // Sausages must be restored back to 50
      expect(await inventoryService.getUsableStock(sausageId), equals(50.0));
    });

    // -------------------------------------------------------------
    // Test 17: Physical stock reconciliation (shortage vs surplus)
    // -------------------------------------------------------------
    test('17. Physical stock reconciliation: shortage logs adjustment, surplus adds batch', () async {
      final ingId = await ingredientService.createIngredient(
        name: 'Reconciliation Mayo',
        measurementUnit: 'g',
      );

      await inventoryService.recordOpeningStock(
        ingredientId: ingId,
        quantity: 500,
        unitCost: 1.0,
        date: '2026-03-01',
      );

      // Case A: Shortage (System: 500, Physical: 480 -> -20)
      await inventoryService.performStockReconciliation(
        countDate: '2026-03-02',
        counts: [
          {'ingredient_id': ingId, 'physical_quantity': 480.0},
        ],
        notes: 'End of week count',
      );

      expect(await inventoryService.getUsableStock(ingId), equals(480.0));

      // Case B: Surplus (System: 480, Physical: 520 -> +40)
      await inventoryService.performStockReconciliation(
        countDate: '2026-03-03',
        counts: [
          {'ingredient_id': ingId, 'physical_quantity': 520.0},
        ],
        notes: 'Found extra pack',
      );

      expect(await inventoryService.getUsableStock(ingId), equals(520.0));
    });

    // -------------------------------------------------------------
    // Test 18: Additional income aggregation
    // -------------------------------------------------------------
    test('18. Additional income aggregation by date range without duplication', () async {
      await incomeExpenseService.recordIncome(
        category: 'Event Stall Advance',
        amount: 3000.0,
        incomeDate: '2026-03-01',
        paymentMethod: 'bank_transfer',
        isReceived: true,
      );

      await incomeExpenseService.recordIncome(
        category: 'Scrap Packaging Sale',
        amount: 500.0,
        incomeDate: '2026-03-05',
        paymentMethod: 'cash',
        isReceived: true,
      );

      // Different period income
      await incomeExpenseService.recordIncome(
        category: 'April Booking',
        amount: 2000.0,
        incomeDate: '2026-04-01',
        paymentMethod: 'cash',
        isReceived: true,
      );

      final list = await incomeExpenseService.getIncomeList(
        startDate: '2026-03-01',
        endDate: '2026-03-07',
      );

      expect(list.length, equals(2));
      final total = list.fold<double>(0.0, (sum, i) => sum + (i['amount'] as num).toDouble());
      expect(total, equals(3500.0));
    });

    // -------------------------------------------------------------
    // Test 19: Cash Flow vs Net Profit distinction
    // -------------------------------------------------------------
    test('19. Cash Flow vs Net Profit distinction (Cash Out vs Inventory Accrual)', () async {
      const sDate = '2026-03-01';
      const eDate = '2026-03-07';

      final ingId = await ingredientService.createIngredient(
        name: 'Cash Flow Ingredient',
        measurementUnit: 'pcs',
      );

      // 1. Purchase 10,000 LKR of stock with CASH
      await purchaseService.recordPurchase(
        supplierName: 'Wholesaler',
        invoiceNumber: 'INV-CF1',
        purchaseDate: sDate,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        items: [
          {'ingredient_id': ingId, 'quantity': 100.0, 'unit_price': 100.0, 'unit': 'pcs'},
        ],
      );

      // 2. Sales of 3,000 LKR (cash)
      await db.insert('daily_sales', {
        'sale_date': sDate,
        'total_revenue': 3000.0,
        'total_cogs': 1000.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Net Profit (Accrual): Sales (3,000) - COGS (1,000) = +2,000
      final profit = await financeService.calculateWeeklyNetProfit(
        startDate: sDate,
        endDate: eDate,
      );
      expect(profit['net_profit'], equals(2000.0));

      // Cash Flow: Cash in (3,000) - Cash out (10,000 purchase) = -7,000
      final cashFlow = await financeService.calculateCashFlow(
        startDate: sDate,
        endDate: eDate,
      );
      expect(cashFlow['cash_in'], equals(3000.0));
      expect(cashFlow['cash_out'], equals(10000.0));
      expect(cashFlow['net_cash_flow'], equals(-7000.0));
    });

    // -------------------------------------------------------------
    // Test 20: Full database backup and restore validation
    // -------------------------------------------------------------
    test('20. Full database backup and restore validation', () async {
      // 1. Create a custom product and ingredient
      final pid = await productService.createProduct(
        name: 'Custom Gourmet Bun',
        sellingPrice: 250.0,
        description: 'Special bun',
      );
      final iid = await ingredientService.createIngredient(
        name: 'Gourmet Cheese',
        measurementUnit: 'g',
      );

      // 2. Generate backup JSON
      final backupJson = await backupService.createBackupJson();
      expect(backupJson, isNotEmpty);

      final Map<String, dynamic> data = jsonDecode(backupJson);
      expect(data.containsKey('tables'), isTrue);
      expect(data['app'], equals('Morning Cafe Business Manager'));

      final tables = data['tables'] as Map<String, dynamic>;
      final productsList = tables['products'] as List<dynamic>;
      expect(productsList.any((p) => p['id'] == pid), isTrue);

      // 3. Restore backup into database
      final restoreSuccess = await backupService.restoreBackupFromJson(backupJson);
      expect(restoreSuccess, isTrue);

      // 4. Verify data survived restoration
      final restoredProduct = await productService.getProductById(pid);
      expect(restoredProduct, isNotNull);
      expect(restoredProduct!['name'], equals('Custom Gourmet Bun'));

      final restoredIngredient = await ingredientService.getIngredientById(iid);
      expect(restoredIngredient, isNotNull);
      expect(restoredIngredient!['name'], equals('Gourmet Cheese'));
    });
  });
}
