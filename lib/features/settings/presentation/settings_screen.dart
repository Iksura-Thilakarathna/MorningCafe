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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Profile
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Morning Cafe Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppColors.highlightYellow : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Location: ${AppConstants.businessLocation}',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDark : AppColors.darkText),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Currency: ${AppConstants.defaultCurrency}',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDark : AppColors.darkText),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Timezone: ${AppConstants.defaultTimezone}',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                        ),
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
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.dark_mode_outlined, color: isDark ? AppColors.highlightYellow : AppColors.primary),
                  title: Text(
                    'Theme Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? AppColors.textDark : AppColors.darkText,
                    ),
                  ),
                  subtitle: Text(
                    widget.currentThemeMode.name.toUpperCase(),
                    style: TextStyle(color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                  ),
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
                  secondary: Icon(Icons.fingerprint, color: isDark ? AppColors.highlightYellow : AppColors.primary),
                  title: Text(
                    'Biometric App Lock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? AppColors.textDark : AppColors.darkText,
                    ),
                  ),
                  subtitle: Text(
                    'Require fingerprint or face ID to open app',
                    style: TextStyle(color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                  ),
                  value: _biometricEnabled,
                  onChanged: _toggleBiometric,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Database Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.textDark : AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Local SQLite storage with foreign key safety and audit ledger.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _dbStats.entries.map((e) {
                      return Column(
                        children: [
                          Text(
                            '${e.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? AppColors.highlightYellow : AppColors.primary,
                            ),
                          ),
                          Text(
                            e.key,
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText),
                          ),
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
