import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'app/home_navigation_screen.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          ? Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Scaffold(
                  backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 130,
                                height: 130,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Morning Cafe',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              color: isDark ? AppColors.highlightYellow : AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Piliyandala, Sri Lanka',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            icon: Icon(
                              Icons.fingerprint,
                              size: 22,
                              color: isDark ? const Color(0xFF160E0A) : Colors.white,
                            ),
                            label: const Text('Unlock Business Records'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.highlightYellow : AppColors.primary,
                              foregroundColor: isDark ? const Color(0xFF160E0A) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _authenticateBiometric,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : HomeNavigationScreen(
              currentThemeMode: _themeMode,
              onThemeModeChanged: _onThemeModeChanged,
            ),
    );
  }
}
