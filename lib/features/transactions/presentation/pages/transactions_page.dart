
import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';
import '../../application/transactions_store.dart';
import '../../domain/entities/transaction.dart';
import 'transaction_form_page.dart';

class TransactionsPage extends StatefulWidget {
  final AccountsStore accountsStore;
  final TransactionsStore transactionsStore;

  const TransactionsPage({
    super.key,
    required this.accountsStore,
    required this.transactionsStore,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  TransactionType? _selectedType;

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedMonth = DateTime(now.year, now.month);
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $whole,${parts[1]}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  void _changeMonth(int amount) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + amount,
      );
    });
  }

  List<FinancialTransaction> get _filteredTransactions {
    final startDate = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final endDate = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    final transactions = widget.transactionsStore.transactions
        .where((transaction) {
          final date = transaction.transactionDate;

          final isInSelectedMonth =
              !date.isBefore(startDate) && date.isBefore(endDate);

          final matchesType = _selectedType == null ||
              transaction.type == _selectedType;

          return isInSelectedMonth && matchesType;
        })
        .toList();

    transactions.sort(
      (a, b) => b.transactionDate.compareTo(a.transactionDate),
    );

    return transactions;
  }

  double _calculateTotal(TransactionType type) {
    return _filteredTransactions
        .where(
          (transaction) =>
              transaction.type == type &&
              transaction.status == TransactionStatus.completed,
        )
        .fold(
          0.0,
          (total, transaction) => total + transaction.amount,
        );
  }

  String _accountNickname(String accountId) {
    for (final account in widget.accountsStore.accounts) {
      if (account.id == accountId) {
        return account.nickname;
      }
    }

    return 'Conta não encontrada';
  }

  Future<void> _openTransactionForm({
    FinancialTransaction? transaction,
  }) async {
    final result = await Navigator.push<FinancialTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormPage(
          accountsStore: widget.accountsStore,
          transaction: transaction,
        ),
      ),
    );

    if (!mounted || result == null) return;

    try {
      await widget.transactionsStore.saveTransaction(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transaction == null
                ? 'Movimentação cadastrada com sucesso.'
                : 'Movimentação atualizada com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: $error'),
        ),
      );
    }
  }

  Future<void> _deleteTransaction(
    FinancialTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir movimentação?'),
          content: Text(
            'Deseja realmente excluir "${transaction.description}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.transactionsStore.deleteTransaction(
        transaction.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimentação excluída.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível excluir: $error'),
        ),
      );
    }
  }

  Future<void> _changeStatus(
    FinancialTransaction transaction,
    TransactionStatus status,
  ) async {
    try {
      await widget.transactionsStore.updateTransactionStatus(
        transaction.id,
        status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status atualizado para ${status.label.toLowerCase()}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar: $error'),
        ),
      );
    }
  }

  void _showTransactionActions(
    FinancialTransaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar movimentação'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTransactionForm(transaction: transaction);
                  },
                ),
                if (transaction.status != TransactionStatus.completed)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Marcar como concluída'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _changeStatus(
                        transaction,
                        TransactionStatus.completed,
                      );
                    },
                  ),
                if (transaction.status != TransactionStatus.pending)
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Marcar como pendente'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _changeStatus(
                        transaction,
                        TransactionStatus.pending,
                      );
                    },
                  ),
                if (transaction.status != TransactionStatus.cancelled)
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined),
                    title: const Text('Cancelar movimentação'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _changeStatus(
                        transaction,
                        TransactionStatus.cancelled,
                      );
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Excluir movimentação',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteTransaction(transaction);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.accountsStore,
        widget.transactionsStore,
      ]),
      builder: (context, child) {
        final transactions = _filteredTransactions;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movimentações',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Acompanhe suas receitas e despesas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildMonthSelector(theme),

                      const SizedBox(height: 20),

                      _buildSummary(theme),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Histórico',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${transactions.length} registros',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SegmentedButton<TransactionType?>(
                        segments: const [
                          ButtonSegment<TransactionType?>(
                            value: null,
                            label: Text('Todas'),
                          ),
                          ButtonSegment<TransactionType?>(
                            value: TransactionType.income,
                            label: Text('Receitas'),
                          ),
                          ButtonSegment<TransactionType?>(
                            value: TransactionType.expense,
                            label: Text('Despesas'),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedType = selection.first;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      if (transactions.isEmpty)
                        _buildEmptyState(theme)
                      else
                        ...transactions.map((transaction) {
                          final accountName = _accountNickname(
                            transaction.accountId,
                          );

                          final isIncome =
                              transaction.type == TransactionType.income;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () {
                                _showTransactionActions(transaction);
                              },
                              leading: CircleAvatar(
                                backgroundColor: isIncome
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : colors.errorContainer,
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isIncome
                                      ? Colors.green
                                      : colors.error,
                                ),
                              ),
                              title: Text(
                                transaction.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${transaction.category.label} • '
                                '$accountName\n'
                                '${transaction.transactionDate.day.toString().padLeft(2, '0')}/'
                                '${transaction.transactionDate.month.toString().padLeft(2, '0')}/'
                                '${transaction.transactionDate.year}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? '+' : '-'}'
                                    '${_formatCurrency(transaction.amount)}',
                                    style: TextStyle(
                                      color: isIncome
                                          ? Colors.green
                                          : colors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    transaction.status.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                onPressed: () => _openTransactionForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nova movimentação'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              _monthLabel(_selectedMonth),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final income = _calculateTotal(TransactionType.income);
    final expenses = _calculateTotal(TransactionType.expense);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: 'Receitas',
                value: income,
                color: Colors.green,
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: 'Despesas',
                value: expenses,
                color: theme.colorScheme.error,
                icon: Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Resultado do período'),
            trailing: Text(
              _formatCurrency(income - expenses),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: income - expenses >= 0
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required ThemeData theme,
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma movimentação neste mês.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Experimente consultar outro período.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
