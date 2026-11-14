import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class AuditService {
  static Future<void> log({
    required String actionType,
    required String tableName,
    int? recordId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    required String description,
    Transaction? txn,
  }) async {
    final now = DateTime.now().toIso8601String();
    final row = {
      'action_type': actionType,
      'table_name': tableName,
      'record_id': recordId,
      'old_values': oldValues != null ? jsonEncode(oldValues) : null,
      'new_values': newValues != null ? jsonEncode(newValues) : null,
      'action_description': description,
      'created_at': now,
    };

    if (txn != null) {
      await txn.insert('audit_logs', row);
    } else {
      final db = await DatabaseHelper.instance.database;
      await db.insert('audit_logs', row);
    }
  }

  static Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'audit_logs',
      orderBy: 'id DESC',
      limit: limit,
    );
  }
}
