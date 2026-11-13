
import 'package:flutter/material.dart';

import '../../application/accounts_store.dart';
import '../../domain/entities/bank_account.dart';
import '../../../transactions/application/transactions_store.dart';
import 'account_form_page.dart';

class AccountsPage extends StatefulWidget {
  final AccountsStore accountsStore;
  final TransactionsStore transactionsStore;

  const AccountsPage({
    super.key,
    required this.accountsStore,
    required this.transactionsStore,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<BankAccount> get _accounts {
    return widget.accountsStore.accounts;
  }

  double _balanceFor(BankAccount account) {
    return widget.transactionsStore.balanceForAccount(
      accountId: account.id,
      initialBalance: account.initialBalance,
    );
  }

  double get _totalBalance {
    return _accounts.fold(
      0.0,
      (total, account) => total + _balanceFor(account),
    );
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $whole,${parts[1]}';
  }

  IconData _accountIcon(BankAccountType type) {
    switch (type) {
      case BankAccountType.checking:
        return Icons.account_balance_rounded;
      case BankAccountType.savings:
        return Icons.savings_rounded;
      case BankAccountType.payment:
        return Icons.account_balance_wallet_rounded;
      case BankAccountType.investment:
        return Icons.trending_up_rounded;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAccountForm({BankAccount? account}) async {
    final result = await Navigator.push<BankAccount>(
      context,
      MaterialPageRoute(
        builder: (context) => AccountFormPage(
          account: account,
        ),
      ),
    );

    if (!mounted || result == null) return;

    try {
      await widget.accountsStore.saveAccount(result);

      if (!mounted) return;

      _showMessage(
        account == null
            ? 'Conta cadastrada com sucesso.'
            : 'Conta atualizada com sucesso.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        widget.accountsStore.errorMessage ??
            'Não foi possível salvar a conta.',
      );
    }
  }

  Future<void> _deleteAccount(BankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta'),
          content: Text(
            'Deseja realmente excluir a conta '
            '"${account.nickname}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.accountsStore.deleteAccount(account.id);

      if (!mounted) return;

      _showMessage('Conta excluída com sucesso.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        widget.accountsStore.errorMessage ??
            'Não foi possível excluir a conta.',
      );
    }
  }

  Future<void> _reloadAccounts() async {
    await Future.wait([
      widget.accountsStore.loadAccounts(force: true),
      widget.transactionsStore.loadTransactions(force: true),
    ]);
  }

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2457D6),
            Color(0xFF15358F),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo total consolidado',
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
              _formatCurrency(_totalBalance),
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
              Text(
                '${_accounts.length} '
                '${_accounts.length == 1 ? 'conta cadastrada' : 'contas cadastradas'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    BankAccount account,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _openAccountForm(account: account),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(
            _accountIcon(account.type),
            color: colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          account.nickname,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${account.bankName}\n${account.type.label}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCurrency(_balanceFor(account)),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openAccountForm(account: account);
                } else if (value == 'delete') {
                  _deleteAccount(account);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conta cadastrada',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione sua primeira conta bancária '
            'para começar a organizar suas finanças.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.accountsStore,
        widget.transactionsStore,
      ]),
      builder: (context, child) {
        final accountsError = widget.accountsStore.errorMessage;
        final transactionsError = widget.transactionsStore.errorMessage;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAccountForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar conta'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: _reloadAccounts,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Minhas contas',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gerencie suas instituições financeiras '
                        'em um único lugar.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildBalanceCard(context),
                      const SizedBox(height: 28),
                      Text(
                        'Contas cadastradas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.accountsStore.isLoading && _accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (accountsError != null && _accounts.isEmpty)
                        Column(
                          children: [
                            Text(accountsError),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _reloadAccounts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        )
                      else if (_accounts.isEmpty)
                        _buildEmptyState(context)
                      else ...[
                        if (accountsError != null || transactionsError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Alguns dados podem estar desatualizados. '
                              'Puxe a tela para baixo para atualizar.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ..._accounts.map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAccountTile(context, account),
                          ),
                        ),
                      ],
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
