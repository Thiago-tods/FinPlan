
import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';

class BalanceCard extends StatelessWidget {
  final AccountsStore accountsStore;

  const BalanceCard({
    super.key,
    required this.accountsStore,
  });

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $whole,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: accountsStore,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2457D6),
                Color(0xFF15358F),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo total disponível',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatCurrency(accountsStore.totalBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Todas as contas',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  Text(
                    '${accountsStore.accounts.length} '
                    '${accountsStore.accounts.length == 1 ? 'conta' : 'contas'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
