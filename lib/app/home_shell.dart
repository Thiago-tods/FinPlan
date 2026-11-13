
import 'package:flutter/material.dart';

import '../core/widgets/placeholder_page.dart';
import '../features/accounts/application/accounts_store.dart';
import '../features/accounts/presentation/pages/accounts_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/planning/application/planning_store.dart';
import '../features/planning/presentation/pages/planning_page.dart';
import '../features/transactions/application/transactions_store.dart';
import '../features/transactions/presentation/pages/transactions_page.dart';

class HomeShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const HomeShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final AccountsStore _accountsStore = AccountsStore();
  final TransactionsStore _transactionsStore = TransactionsStore();
  final PlanningStore _planningStore = PlanningStore();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _accountsStore.loadAccounts(),
      _transactionsStore.loadTransactions(),
      _planningStore.loadBills(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _accountsStore.dispose();
    _transactionsStore.dispose();
    _planningStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        accountsStore: _accountsStore,
        transactionsStore: _transactionsStore,
      ),
      AccountsPage(
        accountsStore: _accountsStore,
        transactionsStore: _transactionsStore,
      ),
      TransactionsPage(
        accountsStore: _accountsStore,
        transactionsStore: _transactionsStore,
      ),
      const PlaceholderPage(
        title: 'Investimentos',
        icon: Icons.trending_up_rounded,
      ),
      PlanningPage(
        planningStore: _planningStore,
        accountsStore: _accountsStore,
        transactionsStore: _transactionsStore,
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
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
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
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Contas',
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
