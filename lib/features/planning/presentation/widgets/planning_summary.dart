import 'package:flutter/material.dart';

import '../../application/planning_store.dart';

class PlanningSummary extends StatelessWidget {
  final PlanningStore planningStore;

  const PlanningSummary({
    super.key,
    required this.planningStore,
  });

  String _currency(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $integer,${parts[1]}';
  }

  Widget _summaryCard({
    required BuildContext context,
    required String title,
    required double value,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(
                  '$count',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currency(value),
                style: theme.textTheme.titleLarge?.copyWith(
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
    return ListenableBuilder(
      listenable: planningStore,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _summaryCard(
                    context: context,
                    title: 'Total pendente',
                    value: planningStore.totalPending,
                    count: planningStore.pendingCount,
                    icon: Icons.pending_actions_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _summaryCard(
                    context: context,
                    title: 'Total vencido',
                    value: planningStore.totalOverdue,
                    count: planningStore.overdueCount,
                    icon: Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _summaryCard(
                    context: context,
                    title: 'Total pago',
                    value: planningStore.totalPaid,
                    count: planningStore.bills
                        .where((bill) => bill.status.name == 'paid')
                        .length,
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}