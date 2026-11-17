import 'dart:math';
import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';
import '../../inventory/data/inventory_service.dart';

class FinanceService {
  final DatabaseHelper _dbHelper;
  final InventoryService _inventoryService;

  FinanceService([DatabaseHelper? dbHelper, InventoryService? inventoryService])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _inventoryService = inventoryService ?? InventoryService(dbHelper);

  Future<Map<String, dynamic>> calculateWeeklyNetProfit({required String startDate, required String endDate}) async {
    return await calculate(startDate, endDate);
  }

  Future<Map<String, dynamic>> calculateFinancialStatement({required String startDate, required String endDate}) async {
    return await calculate(startDate, endDate);
  }

  Future<Map<String, dynamic>> calculateCashFlow({required String startDate, required String endDate}) async {
    final res = await calculate(startDate, endDate);
    return {
      'cash_in': res['cash_inflows'],
      'cash_out': res['cash_outflows'],
      'net_cash_flow': res['net_cash_flow'],
    };
  }

  /// Centralized financial calculation engine
  Future<Map<String, dynamic>> calculate(String startDate, String endDate) async {
    final db = await _dbHelper.database;

    // 1. Sales Revenue & Units
    final salesRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_revenue), 0.0) as total_revenue,
        COALESCE(SUM(total_cogs), 0.0) as total_cogs,
        COUNT(id) as sales_days
      FROM daily_sales
      WHERE sale_date >= ? AND sale_date <= ?
    ''', [startDate, endDate]);

    final unitsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(dsi.quantity_sold), 0) as units_sold
      FROM daily_sale_items dsi
      JOIN daily_sales ds ON dsi.daily_sale_id = ds.id
      WHERE ds.sale_date >= ? AND ds.sale_date <= ?
    ''', [startDate, endDate]);

    final salesRow = salesRes.first;
    final salesRevenue = (salesRow['total_revenue'] as num).toDouble();
    final cogs = (salesRow['total_cogs'] as num).toDouble();
    final unitsSold = (unitsRes.first['units_sold'] as num).toInt();
    final salesDays = (salesRow['sales_days'] as num).toInt();

    // 2. Product-wise breakdown
    final productRes = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        COALESCE(SUM(dsi.quantity_sold), 0) as units_sold,
        COALESCE(SUM(dsi.line_total), 0.0) as revenue
      FROM products p
      LEFT JOIN (
        SELECT dsi.product_id, dsi.quantity_sold, dsi.line_total
        FROM daily_sale_items dsi
        JOIN daily_sales ds ON dsi.daily_sale_id = ds.id
        WHERE ds.sale_date >= ? AND ds.sale_date <= ?
      ) dsi ON p.id = dsi.product_id
      GROUP BY p.id
      ORDER BY p.id ASC
    ''', [startDate, endDate]);

    // 3. Additional Income
    final incomeRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount), 0.0) as total_income,
        COALESCE(SUM(CASE WHEN payment_status = 'received' THEN amount ELSE 0.0 END), 0.0) as received_income
      FROM additional_income
      WHERE transaction_date >= ? AND transaction_date <= ?
    ''', [startDate, endDate]);

    final additionalIncome = (incomeRes.first['total_income'] as num).toDouble();
    final receivedAdditionalIncome = (incomeRes.first['received_income'] as num).toDouble();

    // 4. Gross Profit
    final grossProfit = salesRevenue - cogs;
    final totalBusinessIncome = salesRevenue + additionalIncome;

    // 5. Stock Wastage Cost
    final wasteRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_cost), 0.0) as total_wastage,
        COALESCE(SUM(quantity), 0.0) as total_qty
      FROM stock_wastage
      WHERE wastage_date >= ? AND wastage_date <= ?
    ''', [startDate, endDate]);

    final wastageCost = (wasteRes.first['total_wastage'] as num).toDouble();

    // 6. Operating Expenses
    final expRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount), 0.0) as total_expenses,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN amount ELSE 0.0 END), 0.0) as paid_expenses
      FROM additional_expenses
      WHERE expense_date >= ? AND expense_date <= ?
    ''', [startDate, endDate]);

    final operatingExpenses = (expRes.first['total_expenses'] as num).toDouble();
    final paidOperatingExpenses = (expRes.first['paid_expenses'] as num).toDouble();

    // 7. Net Profit Formula:
    // Net Profit = Sales Revenue + Additional Income - COGS - Stock Wastage - Additional Operating Expenses
    final netProfit = salesRevenue + additionalIncome - cogs - wastageCost - operatingExpenses;

    final profitMargin = salesRevenue > 0.001 ? ((netProfit / salesRevenue) * 100) : 0.0;

    // 8. Purchases in Period (capitalized as inventory asset, not deducted from net profit!)
    final purRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_purchases,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0.0 END), 0.0) as paid_purchases
      FROM purchases
      WHERE purchase_date >= ? AND purchase_date <= ? AND status = 'confirmed'
    ''', [startDate, endDate]);

    final totalPurchases = (purRes.first['total_purchases'] as num).toDouble();
    final paidPurchases = (purRes.first['paid_purchases'] as num).toDouble();

    // 9. Cash Flow:
    // Cash Inflows = Collected Sales Revenue + Received Additional Income
    // Cash Outflows = Paid Purchases + Paid Operating Expenses
    // Net Cash Flow = Cash Inflows - Cash Outflows
    final cashInflows = salesRevenue + receivedAdditionalIncome;
    final cashOutflows = paidPurchases + paidOperatingExpenses;
    final netCashFlow = cashInflows - cashOutflows;

    // 10. Inventory Valuation Reconciliation:
    // Opening inventory = net ledger movements before startDate
    final openMoveRes = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN quantity > 0 THEN total_cost ELSE -total_cost END), 0.0) as val
      FROM stock_movements
      WHERE movement_date < ?
    ''', [startDate]);
    double openingInventoryValue = max(0.0, (openMoveRes.first['val'] as num).toDouble());

    // Period net inventory change
    final periodMoveRes = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN quantity > 0 THEN total_cost ELSE -total_cost END), 0.0) as val
      FROM stock_movements
      WHERE movement_date >= ? AND movement_date <= ?
    ''', [startDate, endDate]);
    final periodNetChange = (periodMoveRes.first['val'] as num).toDouble();

    double closingInventoryValue = max(0.0, openingInventoryValue + periodNetChange);

    // Fallback if no movements yet and date is today or later
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (endDate.compareTo(todayStr) >= 0 && openingInventoryValue == 0.0 && periodNetChange == 0.0) {
      closingInventoryValue = await _inventoryService.getTotalInventoryValuation();
    }

    // 11. Daily Breakdown Table
    final dailyBreakdown = await _calculateDailyBreakdown(startDate, endDate);

    return {
      'period': {
        'start_date': startDate,
        'end_date': endDate,
      },
      'sales_revenue': salesRevenue,
      'units_sold': unitsSold,
      'sales_days': salesDays,
      'product_breakdown': productRes,
      'additional_income': additionalIncome,
      'received_additional_income': receivedAdditionalIncome,
      'total_business_income': totalBusinessIncome,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'wastage_cost': wastageCost,
      'operating_expenses': operatingExpenses,
      'paid_operating_expenses': paidOperatingExpenses,
      'net_profit': netProfit,
      'profit_margin': profitMargin,
      'total_purchases': totalPurchases,
      'paid_purchases': paidPurchases,
      'opening_inventory_value': openingInventoryValue,
      'closing_inventory_value': closingInventoryValue,
      'cash_inflows': cashInflows,
      'cash_outflows': cashOutflows,
      'net_cash_flow': netCashFlow,
      'daily_breakdown': dailyBreakdown,
    };
  }

  Future<List<Map<String, dynamic>>> _calculateDailyBreakdown(String startDate, String endDate) async {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final db = await _dbHelper.database;

    // Single aggregated batch queries for the entire period (fast, non-blocking)
    final salesRes = await db.rawQuery('''
      SELECT sale_date, COALESCE(SUM(total_revenue), 0.0) as rev, COALESCE(SUM(total_cogs), 0.0) as cogs 
      FROM daily_sales WHERE sale_date >= ? AND sale_date <= ? GROUP BY sale_date
    ''', [startDate, endDate]);
    final salesMap = {for (final r in salesRes) r['sale_date'] as String: r};

    final wasteRes = await db.rawQuery('''
      SELECT wastage_date, COALESCE(SUM(total_cost), 0.0) as wcost 
      FROM stock_wastage WHERE wastage_date >= ? AND wastage_date <= ? GROUP BY wastage_date
    ''', [startDate, endDate]);
    final wasteMap = {for (final r in wasteRes) r['wastage_date'] as String: (r['wcost'] as num).toDouble()};

    final expRes = await db.rawQuery('''
      SELECT expense_date, COALESCE(SUM(amount), 0.0) as exp 
      FROM additional_expenses WHERE expense_date >= ? AND expense_date <= ? GROUP BY expense_date
    ''', [startDate, endDate]);
    final expMap = {for (final r in expRes) r['expense_date'] as String: (r['exp'] as num).toDouble()};

    final incRes = await db.rawQuery('''
      SELECT transaction_date, COALESCE(SUM(amount), 0.0) as inc 
      FROM additional_income WHERE transaction_date >= ? AND transaction_date <= ? GROUP BY transaction_date
    ''', [startDate, endDate]);
    final incMap = {for (final r in incRes) r['transaction_date'] as String: (r['inc'] as num).toDouble()};

    final purRes = await db.rawQuery('''
      SELECT purchase_date, COALESCE(SUM(total_amount), 0.0) as pur 
      FROM purchases WHERE purchase_date >= ? AND purchase_date <= ? AND status = 'confirmed' GROUP BY purchase_date
    ''', [startDate, endDate]);
    final purMap = {for (final r in purRes) r['purchase_date'] as String: (r['pur'] as num).toDouble()};

    final days = <Map<String, dynamic>>[];
    DateTime current = start;

    while (!current.isAfter(end)) {
      final curDateStr = current.toIso8601String().substring(0, 10);
      final s = salesMap[curDateStr];
      final rev = s != null ? (s['rev'] as num).toDouble() : 0.0;
      final cogs = s != null ? (s['cogs'] as num).toDouble() : 0.0;
      final wcost = wasteMap[curDateStr] ?? 0.0;
      final exp = expMap[curDateStr] ?? 0.0;
      final inc = incMap[curDateStr] ?? 0.0;
      final pur = purMap[curDateStr] ?? 0.0;

      final gross = rev - cogs;
      final net = rev + inc - cogs - wcost - exp;

      days.add({
        'date': curDateStr,
        'day_name': _getDayName(current.weekday),
        'sales_revenue': rev,
        'additional_income': inc,
        'cogs': cogs,
        'gross_profit': gross,
        'wastage_cost': wcost,
        'operating_expenses': exp,
        'purchases': pur,
        'net_profit': net,
      });

      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  Future<int> finalizeReport(String startDate, String endDate, String? notes) async {
    final calc = await calculate(startDate, endDate);
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final id = await txn.insert('reporting_periods', {
        'period_start': startDate,
        'period_end': endDate,
        'sales_revenue': calc['sales_revenue'],
        'cogs': calc['cogs'],
        'gross_profit': calc['gross_profit'],
        'wastage_cost': calc['wastage_cost'],
        'operating_expenses': calc['operating_expenses'],
        'additional_income': calc['additional_income'],
        'net_profit': calc['net_profit'],
        'cash_inflows': calc['cash_inflows'],
        'cash_outflows': calc['cash_outflows'],
        'net_cash_flow': calc['net_cash_flow'],
        'opening_inventory_value': calc['opening_inventory_value'],
        'closing_inventory_value': calc['closing_inventory_value'],
        'status': 'finalized',
        'is_finalized': 1,
        'finalized_at': now,
        'notes': notes?.trim(),
        'created_at': now,
      });

      await AuditService.log(
        actionType: 'finalize',
        tableName: 'reporting_periods',
        recordId: id,
        description: 'Finalized financial report for period $startDate to $endDate (Net Profit: LKR ${calc['net_profit']})',
        txn: txn,
      );

      return id;
    });
  }

  Future<Map<String, dynamic>?> getFinalizedPeriod(String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'reporting_periods',
      where: 'period_start = ? AND period_end = ? AND is_finalized = 1',
      whereArgs: [startDate, endDate],
      orderBy: 'id DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }
}
