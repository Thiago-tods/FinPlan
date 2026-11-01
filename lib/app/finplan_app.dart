
import 'package:flutter/material.dart';

import '../core/services/theme_preferences.dart';
import 'home_shell.dart';
import 'theme/app_theme.dart';

class FinPlanApp extends StatefulWidget {
  const FinPlanApp({super.key});

  @override
  State<FinPlanApp> createState() => _FinPlanAppState();
}

class _FinPlanAppState extends State<FinPlanApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final isDark = await ThemePreferences.loadIsDark();

      if (!mounted) return;

      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _toggleTheme() async {
    final newTheme = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    setState(() {
      _themeMode = newTheme;
    });

    await ThemePreferences.saveIsDark(
      newTheme == ThemeMode.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinPlan',
      themeMode: _themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: _isInitialized
          ? HomeShell(
              isDark: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
            )
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}
