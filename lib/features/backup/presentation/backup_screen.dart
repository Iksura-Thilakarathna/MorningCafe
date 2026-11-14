import 'package:flutter/material.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  String? _lastBackupDate;
  String? _createdBackupPath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final date = await _backupService.getLastBackupDate();
    if (mounted) {
      setState(() => _lastBackupDate = date);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    try {
      final path = await _backupService.createBackupFile();
      if (mounted) {
        setState(() {
          _createdBackupPath = path;
          _isProcessing = false;
        });
        _loadLastBackup();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database backup created successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _shareBackup() async {
    if (_createdBackupPath == null) return;
    await _backupService.shareBackupFile(_createdBackupPath!);
  }

  void _showRestoreDialog() {
    final jsonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WARNING: Restoring will overwrite the current database. Make sure you have a recent backup.',
                style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Paste Backup JSON Content',
                  hintText: 'Paste the contents of your backup JSON file here...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Confirm Restore'),
            onPressed: () async {
              final text = jsonCtrl.text.trim();
              if (text.isEmpty) return;

              try {
                await _backupService.restoreFromBackup(text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database restored successfully!'), backgroundColor: AppColors.success),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Data Safety'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Local Offline Storage Safety', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All your cafe business records are stored securely on this phone without requiring internet access or cloud servers. Create regular backups to prevent data loss.',
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Last Backup Created:', style: TextStyle(fontSize: 13)),
                        Text(
                          _lastBackupDate != null ? Formatters.displayDateTime(_lastBackupDate!) : 'Never',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _lastBackupDate != null ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Full Database Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isProcessing ? null : _createBackup,
              ),
            ),
            if (_createdBackupPath != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Backup File (WhatsApp, Drive, Email)'),
                  onPressed: _shareBackup,
                ),
              ),
            ],
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            const Text('Restore from Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            const Text('Restore your business database from a previously created JSON backup file.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore, color: AppColors.danger),
              label: const Text('Restore Database from Backup', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
              onPressed: _showRestoreDialog,
            ),
          ],
        ),
      ),
    );
  }
}
