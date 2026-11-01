
import 'package:flutter/material.dart';

import '../core/widgets/placeholder_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';

class HomeShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const HomeShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const PlaceholderPage(
        title: 'Movimentações',
        icon: Icons.swap_horiz_rounded,
      ),
      const PlaceholderPage(
        title: 'Investimentos',
        icon: Icons.trending_up_rounded,
      ),
      const PlaceholderPage(
        title: 'Planejamento',
        icon: Icons.calendar_month_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF2457D6),
            ),
            const SizedBox(width: 9),
            const Text(
              'FinPlan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Alternar tema',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Movimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_rounded),
            label: 'Investir',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Planejar',
          ),
        ],
      ),
    );
  }
}
