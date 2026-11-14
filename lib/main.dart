import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'app/home_navigation_screen.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  await DatabaseHelper.instance.database;

  runApp(const ProviderScope(child: MorningCafeApp()));
}

class MorningCafeApp extends StatefulWidget {
  const MorningCafeApp({super.key});

  @override
  State<MorningCafeApp> createState() => _MorningCafeAppState();
}

class _MorningCafeAppState extends State<MorningCafeApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isAuthenticated = true;
  bool _checkingAuth = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCheckAuth();
  }

  Future<void> _loadSettingsAndCheckAuth() async {
    final db = await DatabaseHelper.instance.database;

    // Load theme
    final themeRes = await db.query('app_settings', where: 'key = ?', whereArgs: ['theme_mode']);
    if (themeRes.isNotEmpty) {
      final val = themeRes.first['value'] as String?;
      if (val == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (val == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }
    }

    // Check biometric lock
    final bioRes = await db.query('app_settings', where: 'key = ?', whereArgs: ['biometric_enabled']);
    final isBio = bioRes.isNotEmpty && bioRes.first['value'] == 'true';

    if (isBio) {
      setState(() {
        _isAuthenticated = false;
        _checkingAuth = true;
      });
      _authenticateBiometric();
    } else {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    final auth = LocalAuthentication();
    try {
      final success = await auth.authenticate(
        localizedReason: 'Unlock Morning Cafe Business Manager',
      );
      if (mounted) {
        setState(() {
          _isAuthenticated = success;
          _checkingAuth = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true; // Fallback so owner is not permanently locked out
          _checkingAuth = false;
        });
      }
    }
  }

  void _onThemeModeChanged(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final db = await DatabaseHelper.instance.database;
    await db.insert('app_settings', {'key': 'theme_mode', 'value': mode.name}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morning Cafe Business Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: (_checkingAuth || !_isAuthenticated)
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text('Morning Cafe Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _authenticateBiometric,
                      child: const Text('Unlock with Biometrics'),
                    ),
                  ],
                ),
              ),
            )
          : HomeNavigationScreen(
              currentThemeMode: _themeMode,
              onThemeModeChanged: _onThemeModeChanged,
            ),
    );
  }
}
