
import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';
import '../../../accounts/domain/entities/bank_account.dart';
import '../../domain/entities/transaction.dart';

class TransactionFormPage extends StatefulWidget {
  final AccountsStore accountsStore;
  final FinancialTransaction? transaction;

  const TransactionFormPage({
    super.key,
    required this.accountsStore,
    this.transaction,
  });

  @override
  State<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late TransactionType _selectedType;
  late TransactionCategory _selectedCategory;
  late TransactionStatus _selectedStatus;
  late DateTime _transactionDate;
  late DateTime _dueDate;

  String? _selectedAccountId;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );

    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : transaction.amount.toStringAsFixed(2).replaceAll('.', ','),
    );

    _notesController = TextEditingController(
      text: transaction?.notes ?? '',
    );

    _selectedType = transaction?.type ?? TransactionType.expense;

    _selectedCategory =
        transaction?.category ?? TransactionCategory.other;

    _selectedStatus =
        transaction?.status ?? TransactionStatus.completed;

    _transactionDate = transaction?.transactionDate ?? DateTime.now();

    _dueDate = transaction?.dueDate ?? DateTime.now();

    _selectedAccountId = transaction?.accountId;

    final accounts = widget.accountsStore.accounts;

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  double? _parseAmount(String value) {
    var normalized = value
        .trim()
        .replaceAll('R\$', '')
        .replaceAll(' ', '');

    if (normalized.contains(',')) {
      normalized = normalized
          .replaceAll('.', '')
          .replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _selectDate({
    required bool isDueDate,
  }) async {
    final currentDate = isDueDate ? _dueDate : _transactionDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isDueDate
          ? 'Selecione o vencimento'
          : 'Selecione a data da movimentação',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      if (isDueDate) {
        _dueDate = selectedDate;
      } else {
        _transactionDate = selectedDate;
      }
    });
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _parseAmount(_amountController.text);

    if (amount == null || !amount.isFinite || amount <= 0) {
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre ou selecione uma conta bancária.'),
        ),
      );
      return;
    }

    final transaction = FinancialTransaction(
      id: widget.transaction?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      description: _descriptionController.text.trim(),
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      accountId: _selectedAccountId!,
      transactionDate: _transactionDate,
      dueDate: _dueDate,
      status: _selectedStatus,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accounts = widget.accountsStore.accounts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar movimentação' : 'Nova movimentação',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing
                        ? 'Atualize sua movimentação'
                        : 'Registre uma movimentação',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Informe os dados da receita ou despesa.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Receita'),
                        icon: Icon(Icons.trending_up_rounded),
                      ),
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Despesa'),
                        icon: Icon(Icons.trending_down_rounded),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedType = selection.first;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ex.: Salário, aluguel, supermercado',
                      prefixIcon: Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe uma descrição.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o valor.';
                      }

                      final amount = _parseAmount(value);

                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0) {
                        return 'Informe um valor válido.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  DropdownButtonFormField<TransactionCategory>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: TransactionCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Conta bancária',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Selecione uma conta'),
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
                      setState(() {
                        _selectedAccountId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione uma conta bancária.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: () => _selectDate(isDueDate: false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Data da movimentação: '
                      '${_formatDate(_transactionDate)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () => _selectDate(isDueDate: true),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      'Data de vencimento: ${_formatDate(_dueDate)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),

                  const SizedBox(height: 20),

                  DropdownButtonFormField<TransactionStatus>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: TransactionStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      hintText: 'Informações adicionais...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 32),

                  FilledButton.icon(
                    onPressed: accounts.isEmpty
                        ? null
                        : _saveTransaction,
                    icon: Icon(
                      _isEditing
                          ? Icons.save_rounded
                          : Icons.add_rounded,
                    ),
                    label: Text(
                      _isEditing
                          ? 'Salvar alterações'
                          : 'Cadastrar movimentação',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),

                  if (accounts.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Você precisa cadastrar uma conta antes de '
                      'registrar movimentações.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Cancelar'),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
