
import 'package:flutter/material.dart';

import '../core/services/theme_preferences.dart';
import '../features/auth/application/auth_store.dart';
import '../features/auth/presentation/pages/login_page.dart';
import 'home_shell.dart';
import 'theme/app_theme.dart';

class FinPlanApp extends StatefulWidget {
  const FinPlanApp({super.key});

  @override
  State<FinPlanApp> createState() => _FinPlanAppState();
}

class _FinPlanAppState extends State<FinPlanApp> {
  final AuthStore _authStore = AuthStore();

  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _authStore.restoreSession();
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

  void _toggleTheme() {
    final isDark = _themeMode != ThemeMode.dark;

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });

    ThemePreferences.saveIsDark(isDark);
  }

  @override
  void dispose() {
    _authStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinPlan',
      themeMode: _themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: AnimatedBuilder(
        animation: _authStore,
        builder: (context, _) {
          if (!_isInitialized || _authStore.isCheckingSession) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (_authStore.isAuthenticated) {
            return HomeShell(
              isDark: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
              onLogout: _authStore.logout,
            );
          }

          return LoginPage(authStore: _authStore);
        },
      ),
    );
  }
}
