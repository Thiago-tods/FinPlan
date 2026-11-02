import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';
import '../../../accounts/domain/entities/bank_account.dart';
import '../../../transactions/application/transactions_store.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../application/planning_store.dart';
import '../../domain/entities/payable_bill.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/planning_summary.dart';
import 'bill_form_page.dart';
import '../widgets/cash_flow_projection_section.dart';

class PlanningPage extends StatefulWidget {
  final PlanningStore planningStore;
  final AccountsStore accountsStore;
  final TransactionsStore transactionsStore;

  const PlanningPage({
    super.key,
    required this.planningStore,
    required this.accountsStore,
    required this.transactionsStore,
  });

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  BillStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    widget.planningStore.addListener(_refresh);
    widget.accountsStore.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.planningStore.removeListener(_refresh);
    widget.accountsStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<PayableBill> get _filteredBills {
    final bills = widget.planningStore.bills;

    final filtered = bills.where((bill) {
      if (_selectedFilter == null) return true;

      if (_selectedFilter == BillStatus.pending) {
        return bill.status == BillStatus.pending;
      }

      return bill.status == _selectedFilter;
    }).toList();

    filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return filtered;
  }

  Future<void> _openForm({PayableBill? bill}) async {
    final result = await Navigator.push<PayableBill>(
      context,
      MaterialPageRoute(builder: (_) => BillFormPage(bill: bill)),
    );

    if (result == null || !mounted) return;

    try {
      await widget.planningStore.saveBill(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bill == null
                ? 'Conta cadastrada com sucesso.'
                : 'Conta atualizada com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  Future<void> _payBill(PayableBill bill) async {
    if (bill.status != BillStatus.pending) return;

    final accounts = widget.accountsStore.accounts;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma conta bancária antes de pagar.'),
        ),
      );
      return;
    }

    String? selectedAccountId = accounts.first.id;

    final paymentDate = DateTime.now();

    final eligibleForDiscount =
        bill.hasDiscount &&
        !DateTime(paymentDate.year, paymentDate.month, paymentDate.day).isAfter(
          DateTime(
            bill.discountDeadline!.year,
            bill.discountDeadline!.month,
            bill.discountDeadline!.day,
          ),
        );

    final paymentAmount = eligibleForDiscount
        ? bill.discountedAmount
        : bill.amount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar pagamento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conta: ${bill.description}'),
                  const SizedBox(height: 12),
                  Text(
                    'Valor a pagar: ${_currency(paymentAmount)}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (eligibleForDiscount)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Desconto aplicado: ${_currency(bill.discountAmount!)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Conta utilizada',
                      border: OutlineInputBorder(),
                    ),
                    items: accounts.map((BankAccount account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.nickname} (${account.bankName})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedAccountId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A confirmação registrará uma despesa no histórico '
                    'financeiro e atualizará o saldo da conta selecionada.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: selectedAccountId == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Confirmar pagamento'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedAccountId == null || !mounted) return;

    final transactionId = 'bill-${bill.id}';

    try {
      final transaction = FinancialTransaction(
        id: transactionId,
        description: bill.description,
        amount: paymentAmount,
        type: TransactionType.expense,
        category: _mapCategory(bill.category),
        accountId: selectedAccountId!,
        transactionDate: paymentDate,
        dueDate: bill.dueDate,
        status: TransactionStatus.completed,
        notes:
            'Pagamento gerado pelo Planejamento do FinPlan. '
            'Conta: ${bill.id}',
      );

      await widget.transactionsStore.saveTransaction(transaction);

      await widget.planningStore.updateBillStatus(
        bill.id,
        BillStatus.paid,
        paidAt: paymentDate,
        accountId: selectedAccountId,
        linkedTransactionId: transactionId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento registrado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar pagamento: $error')),
      );
    }
  }

  TransactionCategory _mapCategory(BillCategory category) {
    switch (category) {
      case BillCategory.housing:
        return TransactionCategory.housing;
      case BillCategory.utilities:
        return TransactionCategory.bills;
      case BillCategory.food:
        return TransactionCategory.food;
      case BillCategory.transport:
        return TransactionCategory.transportation;
      case BillCategory.health:
        return TransactionCategory.health;
      case BillCategory.education:
        return TransactionCategory.education;
      case BillCategory.subscriptions:
        return TransactionCategory.bills;
      case BillCategory.taxes:
        return TransactionCategory.taxes;
      case BillCategory.other:
        return TransactionCategory.other;
    }
  }

  Future<void> _cancelBill(PayableBill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar conta?'),
          content: Text('Deseja cancelar "${bill.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar conta'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await widget.planningStore.updateBillStatus(bill.id, BillStatus.cancelled);
  }

  Future<void> _deleteBill(PayableBill bill) async {
    if (bill.linkedTransactionId != null || bill.status == BillStatus.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contas com pagamento registrado não podem ser excluídas.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: Text('Deseja excluir "${bill.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await widget.planningStore.deleteBill(bill.id);
  }

  String _currency(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $integer,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bills = _filteredBills;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova conta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planejamento financeiro',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Organize seus compromissos e acompanhe seus pagamentos.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                PlanningSummary(planningStore: widget.planningStore),
                const SizedBox(height: 28),
                CashFlowProjectionSection(
                  accountsStore: widget.accountsStore,
                  transactionsStore: widget.transactionsStore,
                  planningStore: widget.planningStore,
                ),
                const SizedBox(height: 28),
                Text(
                  'Contas a pagar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todas'),
                        selected: _selectedFilter == null,
                        onSelected: (_) {
                          setState(() => _selectedFilter = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pendentes'),
                        selected: _selectedFilter == BillStatus.pending,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = BillStatus.pending;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pagas'),
                        selected: _selectedFilter == BillStatus.paid,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = BillStatus.paid;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Canceladas'),
                        selected: _selectedFilter == BillStatus.cancelled,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = BillStatus.cancelled;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (bills.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma conta encontrada.',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cadastre uma conta para começar seu planejamento.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...bills.map((bill) {
                    final isPending = bill.status == BillStatus.pending;
                    final canEdit = isPending;

                    return BillListTile(
                      bill: bill,
                      onEdit: canEdit ? () => _openForm(bill: bill) : null,
                      onPay: isPending ? () => _payBill(bill) : null,
                      onCancel: isPending ? () => _cancelBill(bill) : null,
                      onDelete: bill.linkedTransactionId == null
                          ? () => _deleteBill(bill)
                          : null,
                    );
                  }),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
