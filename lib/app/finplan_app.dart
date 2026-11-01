
import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'theme/app_theme.dart';

class FinPlanApp extends StatefulWidget {
  const FinPlanApp({super.key});

  @override
  State<FinPlanApp> createState() => _FinPlanAppState();
}

class _FinPlanAppState extends State<FinPlanApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinPlan',
      themeMode: _themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: HomeShell(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
