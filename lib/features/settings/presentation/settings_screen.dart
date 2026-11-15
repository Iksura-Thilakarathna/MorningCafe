import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricEnabled = false;
  Map<String, int> _dbStats = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final bioRes = await db.query('app_settings', where: 'key = ?', whereArgs: ['biometric_enabled']);
    final isBio = bioRes.isNotEmpty && bioRes.first['value'] == 'true';

    final prodCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    final ingCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ingredients')) ?? 0;
    final saleCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM daily_sales')) ?? 0;
    final purCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM purchases')) ?? 0;

    if (mounted) {
      setState(() {
        _biometricEnabled = isBio;
        _dbStats = {
          'Products': prodCount,
          'Ingredients': ingCount,
          'Daily Sales': saleCount,
          'Purchases': purCount,
        };
      });
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      try {
        final canCheck = await _auth.canCheckBiometrics;
        if (!canCheck) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device.')),
          );
          return;
        }
        final authenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric app lock',
        );
        if (!authenticated) return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric error: $e')),
        );
        return;
      }
    }

    final db = await DatabaseHelper.instance.database;
    await db.insert('app_settings', {'key': 'biometric_enabled', 'value': enabled ? 'true' : 'false'}, conflictAlgorithm: ConflictAlgorithm.replace);

    setState(() => _biometricEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Profile
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Morning Cafe Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                        SizedBox(height: 6),
                        Text('Location: ${AppConstants.businessLocation}', style: TextStyle(fontSize: 12, color: AppColors.darkText)),
                        SizedBox(height: 3),
                        Text('Currency: ${AppConstants.defaultCurrency}', style: TextStyle(fontSize: 12, color: AppColors.darkText)),
                        SizedBox(height: 3),
                        Text('Timezone: ${AppConstants.defaultTimezone}', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Appearance & Security
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(widget.currentThemeMode.name.toUpperCase()),
                  trailing: DropdownButton<ThemeMode>(
                    value: widget.currentThemeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) widget.onThemeModeChanged(mode);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: const Text('Biometric App Lock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Require fingerprint or face ID to open app'),
                  value: _biometricEnabled,
                  onChanged: _toggleBiometric,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Database Statistics
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Database Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text('Local SQLite storage with foreign key safety and audit ledger.', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _dbStats.entries.map((e) {
                      return Column(
                        children: [
                          Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                          Text(e.key, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // About app
          const Center(
            child: Text(
              'Morning Cafe Business Manager • v1.0.0\nBuilt for Offline Local Operations • Piliyandala, Sri Lanka',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
