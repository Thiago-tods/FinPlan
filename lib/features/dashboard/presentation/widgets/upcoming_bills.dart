
import 'package:flutter/material.dart';

class UpcomingBills extends StatelessWidget {
  const UpcomingBills({super.key});

  Widget _buildBillTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBillTile(
          context,
          title: 'Aluguel',
          subtitle: 'Vence em 05/11/2026',
          value: 'R\$ 1.500,00',
          icon: Icons.home_rounded,
        ),
        const SizedBox(height: 10),
        _buildBillTile(
          context,
          title: 'Internet',
          subtitle: 'Vence em 10/11/2026',
          value: 'R\$ 120,00',
          icon: Icons.wifi_rounded,
        ),
        const SizedBox(height: 10),
        _buildBillTile(
          context,
          title: 'Energia elétrica',
          subtitle: 'Vence em 15/11/2026',
          value: 'R\$ 185,00',
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}
