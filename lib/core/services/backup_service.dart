import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../services/audit_service.dart';

class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const List<String> _allTables = [
    'products',
    'product_price_history',
    'ingredients',
    'ingredient_units',
    'unit_conversions',
    'product_recipes',
    'product_recipe_versions',
    'product_recipe_items',
    'purchases',
    'purchase_items',
    'stock_batches',
    'stock_movements',
    'daily_sales',
    'daily_sale_items',
    'ingredient_usage_records',
    'stock_wastage',
    'additional_income',
    'additional_expenses',
    'stock_counts',
    'stock_count_items',
    'reporting_periods',
    'audit_logs',
    'app_settings',
  ];

  /// Creates a full JSON database backup string
  Future<String> createBackupJson() async {
    final db = await _dbHelper.database;
    final backupData = <String, dynamic>{
      'version': 1,
      'app': 'Morning Cafe Business Manager',
      'created_at': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    for (final table in _allTables) {
      final rows = await db.query(table);
      backupData['tables'][table] = rows;
    }

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Creates a full JSON database backup file and returns its path
  Future<String> createBackupFile() async {
    final jsonString = await createBackupJson();
    final db = await _dbHelper.database;
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'morning_cafe_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    // Update last backup date in settings
    final today = DateTime.now().toIso8601String();
    await db.insert('app_settings', {'key': 'last_backup_date', 'value': today}, conflictAlgorithm: ConflictAlgorithm.replace);

    await AuditService.log(
      actionType: 'backup',
      tableName: 'database',
      description: 'Created database backup: $fileName',
    );

    return file.path;
  }

  /// Shares backup file via native share sheet
  Future<void> shareBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw StateError('Backup file not found');
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Morning Cafe Business Manager Database Backup',
      subject: 'Morning Cafe Database Backup',
    );
  }

  Future<bool> restoreBackupFromJson(String jsonContent) async {
    try {
      await restoreFromBackup(jsonContent);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Restores database from a JSON backup file with validation and rollback safety
  Future<void> restoreFromBackup(String jsonContent) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON format in backup file: $e');
    }

    if (data['app'] != 'Morning Cafe Business Manager') {
      throw const FormatException('This file is not a valid Morning Cafe backup file');
    }

    final tables = data['tables'] as Map<String, dynamic>?;
    if (tables == null || !tables.containsKey('products') || !tables.containsKey('ingredients')) {
      throw const FormatException('Backup is missing required database tables');
    }

    final db = await _dbHelper.database;

    // Transactional restore: disable FKs temporarily during restore, clear, insert, re-enable
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');

      // Clear in reverse order
      for (final table in _allTables.reversed) {
        await txn.delete(table);
      }

      // Populate tables
      for (final table in _allTables) {
        if (tables.containsKey(table)) {
          final rows = (tables[table] as List<dynamic>?) ?? [];
          for (final row in rows) {
            await txn.insert(table, Map<String, dynamic>.from(row as Map));
          }
        }
      }

      await txn.execute('PRAGMA foreign_keys = ON');

      await AuditService.log(
        actionType: 'restore',
        tableName: 'database',
        description: 'Successfully restored database from backup file',
        txn: txn,
      );
    });
  }

  Future<String?> getLastBackupDate() async {
    final db = await _dbHelper.database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: ['last_backup_date']);
    if (res.isNotEmpty) {
      final val = res.first['value'] as String?;
      if (val != null && val.isNotEmpty) return val;
    }
    return null;
  }
}
