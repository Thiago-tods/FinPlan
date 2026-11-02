
import 'package:flutter/material.dart';

import '../../../transactions/application/transactions_store.dart';
import '../../../transactions/domain/entities/transaction.dart';

class FinancialSummary extends StatelessWidget {
  final TransactionsStore transactionsStore;

  const FinancialSummary({
    super.key,
    required this.transactionsStore,
  });

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $whole,${parts[1]}';
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatCurrency(value),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month);
    final endDate = DateTime(now.year, now.month + 1);

    return ListenableBuilder(
      listenable: transactionsStore,
      builder: (context, child) {
        final transactions = transactionsStore.transactions;

        final monthlyTransactions = transactions.where((transaction) {
          final date = transaction.transactionDate;

          return !date.isBefore(startDate) && date.isBefore(endDate);
        });

        final income = monthlyTransactions
            .where(
              (transaction) =>
                  transaction.type == TransactionType.income &&
                  transaction.status == TransactionStatus.completed,
            )
            .fold(
              0.0,
              (total, transaction) => total + transaction.amount,
            );

        final expenses = monthlyTransactions
            .where(
              (transaction) =>
                  transaction.type == TransactionType.expense &&
                  transaction.status == TransactionStatus.completed,
            )
            .fold(
              0.0,
              (total, transaction) => total + transaction.amount,
            );

        final pendingExpenses = transactions
            .where((transaction) {
              final dueDate = transaction.dueDate;

              return transaction.type == TransactionType.expense &&
                  transaction.status == TransactionStatus.pending &&
                  !dueDate.isBefore(startDate) &&
                  dueDate.isBefore(endDate);
            })
            .fold(
              0.0,
              (total, transaction) => total + transaction.amount,
            );

        final result = income - expenses;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Receitas do mês',
                    value: income,
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF16A36A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Despesas do mês',
                    value: expenses,
                    icon: Icons.arrow_upward_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Resultado mensal',
                    value: result,
                    icon: Icons.account_balance_wallet_outlined,
                    color: result >= 0
                        ? const Color(0xFF16A36A)
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Despesas pendentes',
                    value: pendingExpenses,
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFE5A000),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
