
import 'package:flutter/material.dart';

class FinancialSummary extends StatelessWidget {
  const FinancialSummary({super.key});

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
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
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            title: 'Receitas',
            value: 'R\$ 8.500,00',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF16A36A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            title: 'Despesas',
            value: 'R\$ 3.250,00',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFE05252),
          ),
        ),
      ],
    );
  }
}
