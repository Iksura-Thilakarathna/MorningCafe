import '../../../core/database/database_helper.dart';
import '../../../core/services/audit_service.dart';

class IncomeExpenseService {
  final DatabaseHelper _dbHelper;

  IncomeExpenseService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // --- ADDITIONAL INCOME ---

  Future<int> recordIncome({
    String? transactionDate,
    String? incomeDate,
    String? receivedDate,
    required String category,
    String? description,
    required double amount,
    String? paymentMethod,
    bool isReceived = true,
    String? paymentStatus,
    String? notes,
  }) async {
    final tDate = transactionDate ?? incomeDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final status = paymentStatus ?? (isReceived ? 'received' : 'pending');
    return await recordAdditionalIncome(
      transactionDate: tDate,
      receivedDate: receivedDate,
      category: category,
      description: description ?? category,
      amount: amount,
      paymentStatus: status,
      notes: notes,
    );
  }

  Future<int> recordExpense({
    String? expenseDate,
    String? paidDate,
    required String category,
    String? description,
    required double amount,
    String? paymentMethod,
    bool isPaid = true,
    String? paymentStatus,
    String? notes,
  }) async {
    final eDate = expenseDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final status = paymentStatus ?? (isPaid ? 'paid' : 'pending');
    return await recordAdditionalExpense(
      expenseDate: eDate,
      paidDate: paidDate,
      category: category,
      description: description ?? category,
      amount: amount,
      paymentStatus: status,
      notes: notes,
    );
  }

  Future<int> recordAdditionalIncome({
    required String transactionDate,
    String? receivedDate,
    required String category,
    required String description,
    required double amount,
    String paymentStatus = 'received',
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Income amount must be greater than zero');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('additional_income', {
      'transaction_date': transactionDate,
      'received_date': receivedDate ?? (paymentStatus == 'received' ? transactionDate : null),
      'category': category.trim(),
      'description': description.trim(),
      'amount': amount,
      'payment_status': paymentStatus,
      'notes': notes?.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await AuditService.log(
      actionType: 'insert',
      tableName: 'additional_income',
      recordId: id,
      description: 'Recorded additional income: LKR $amount ($category - $description)',
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> getIncomeList({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      args.add(endDate);
    }

    return await db.query(
      'additional_income',
      where: whereClause,
      whereArgs: args,
      orderBy: 'transaction_date DESC, id DESC',
    );
  }

  Future<void> deleteIncome(int id) async {
    final db = await _dbHelper.database;
    await db.delete('additional_income', where: 'id = ?', whereArgs: [id]);
    await AuditService.log(
      actionType: 'delete',
      tableName: 'additional_income',
      recordId: id,
      description: 'Deleted additional income #$id',
    );
  }

  // --- ADDITIONAL EXPENSES ---

  Future<int> recordAdditionalExpense({
    required String expenseDate,
    String? paidDate,
    required String category,
    required String description,
    required double amount,
    String paymentStatus = 'paid',
    String? receiptPath,
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Expense amount must be greater than zero');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('additional_expenses', {
      'expense_date': expenseDate,
      'paid_date': paidDate ?? (paymentStatus == 'paid' ? expenseDate : null),
      'category': category.trim(),
      'description': description.trim(),
      'amount': amount,
      'payment_status': paymentStatus,
      'receipt_path': receiptPath,
      'notes': notes?.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await AuditService.log(
      actionType: 'insert',
      tableName: 'additional_expenses',
      recordId: id,
      description: 'Recorded operating expense: LKR $amount ($category - $description)',
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> getExpensesList({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final args = <dynamic>[];

    if (startDate != null) {
      whereClause += ' AND expense_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      whereClause += ' AND expense_date <= ?';
      args.add(endDate);
    }

    return await db.query(
      'additional_expenses',
      where: whereClause,
      whereArgs: args,
      orderBy: 'expense_date DESC, id DESC',
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    await db.delete('additional_expenses', where: 'id = ?', whereArgs: [id]);
    await AuditService.log(
      actionType: 'delete',
      tableName: 'additional_expenses',
      recordId: id,
      description: 'Deleted operating expense #$id',
    );
  }
}
