
import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';
import '../widgets/balance_card.dart';
import '../widgets/financial_summary.dart';
import '../widgets/planning_card.dart';
import '../widgets/upcoming_bills.dart';

class DashboardPage extends StatelessWidget {
  final AccountsStore accountsStore;

  const DashboardPage({
    super.key,
    required this.accountsStore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, seja bem-vindo!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Aqui está o resumo das suas finanças.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  BalanceCard(
                    accountsStore: accountsStore,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Resumo financeiro',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const FinancialSummary(),

                  const SizedBox(height: 28),

                  Text(
                    'Próximas contas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const UpcomingBills(),

                  const SizedBox(height: 28),

                  Text(
                    'Planejamento inteligente',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const PlanningCard(),

                  const SizedBox(height: 30),

                  Center(
                    child: Text(
                      'FinPlan • Versão de desenvolvimento',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
