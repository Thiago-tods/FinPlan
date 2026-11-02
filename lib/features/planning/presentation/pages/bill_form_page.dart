
import 'package:flutter/material.dart';

import '../../../transactions/application/transactions_store.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../application/planning_store.dart';
import '../../domain/entities/payable_bill.dart';

class BillFormPage extends StatefulWidget {
  final PayableBill? bill;
  final TransactionsStore? transactionsStore;
  final PlanningStore? planningStore;

  const BillFormPage({
    super.key,
    this.bill,
    this.transactionsStore,
    this.planningStore,
  });

  @override
  State<BillFormPage> createState() => _BillFormPageState();
}

class _BillFormPageState extends State<BillFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  late BillCategory _category;
  late DateTime _dueDate;
  DateTime? _discountDeadline;

  late String _selectedPendingTransactionId;

  bool get _isEditing => widget.bill != null;

  List<FinancialTransaction> get _availablePendingExpenses {
    final transactions = widget.transactionsStore?.transactions ?? [];
    final bills = widget.planningStore?.bills ?? [];

    final linkedByOtherBills = bills
        .where((bill) => bill.id != widget.bill?.id)
        .map((bill) => bill.linkedPendingTransactionId)
        .whereType<String>()
        .toSet();

    return transactions.where((transaction) {
      return transaction.status == TransactionStatus.pending &&
          transaction.type == TransactionType.expense &&
          (!linkedByOtherBills.contains(transaction.id) ||
              transaction.id == _selectedPendingTransactionId);
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  void initState() {
    super.initState();

    final bill = widget.bill;

    _descriptionController = TextEditingController(
      text: bill?.description ?? '',
    );

    _amountController = TextEditingController(
      text: bill == null
          ? ''
          : bill.amount.toStringAsFixed(2).replaceAll('.', ','),
    );

    _discountController = TextEditingController(
      text: bill?.discountAmount == null
          ? ''
          : bill!.discountAmount!.toStringAsFixed(2).replaceAll('.', ','),
    );

    _notesController = TextEditingController(
      text: bill?.notes ?? '',
    );

    _category = bill?.category ?? BillCategory.other;
    _dueDate = bill?.dueDate ?? DateTime.now();
    _discountDeadline = bill?.discountDeadline;

    _selectedPendingTransactionId =
        bill?.linkedPendingTransactionId ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _discountController.dispose();
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

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _selectDate({required bool isDiscountDate}) async {
    final currentDate = isDiscountDate
        ? _discountDeadline ?? _dueDate
        : _dueDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isDiscountDate
          ? 'Data limite do desconto'
          : 'Data de vencimento',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      if (isDiscountDate) {
        _discountDeadline = selectedDate;
      } else {
        _dueDate = selectedDate;
      }
    });
  }

  void _saveBill() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);
    final discountText = _discountController.text.trim();
    final discount = discountText.isEmpty
        ? null
        : _parseAmount(discountText);

    if (amount == null || !amount.isFinite || amount <= 0) return;

    if (discountText.isNotEmpty &&
        (discount == null ||
            !discount.isFinite ||
            discount <= 0 ||
            discount >= amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um desconto válido.'),
        ),
      );
      return;
    }

    if (discount != null && _discountDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a data limite do desconto.'),
        ),
      );
      return;
    }

    if (_discountDeadline != null &&
        _discountDeadline!.isAfter(_dueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O desconto não pode terminar depois do vencimento.',
          ),
        ),
      );
      return;
    }

    final bill = PayableBill(
      id: widget.bill?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _category,
      dueDate: _dueDate,
      discountDeadline: discount == null ? null : _discountDeadline,
      discountAmount: discount,
      status: widget.bill?.status ?? BillStatus.pending,
      paidAt: widget.bill?.paidAt,
      accountId: widget.bill?.accountId,
      linkedTransactionId: widget.bill?.linkedTransactionId,
      linkedPendingTransactionId:
          _selectedPendingTransactionId.isEmpty
              ? null
              : _selectedPendingTransactionId,
      notes: _notesController.text.trim(),
    );

    Navigator.pop(context, bill);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableTransactions = _availablePendingExpenses;

    final selectedTransactionExists = availableTransactions.any(
      (transaction) =>
          transaction.id == _selectedPendingTransactionId,
    );

    final hasUnavailableLink =
        _selectedPendingTransactionId.isNotEmpty &&
        !selectedTransactionExists;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar conta' : 'Nova conta a pagar'),
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
                    Icons.event_note_rounded,
                    size: 48,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing
                        ? 'Atualize os dados da conta'
                        : 'Cadastre uma nova conta',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ex.: Aluguel, internet, energia',
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
                      labelText: 'Valor da conta',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = _parseAmount(value ?? '');

                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0) {
                        return 'Informe um valor válido.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<BillCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: BillCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(isDiscountDate: false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Vencimento: ${_formatDate(_dueDate)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vincular despesa pendente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecione uma despesa já cadastrada para representar '
                    'esta mesma obrigação financeira.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPendingTransactionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Transação existente (opcional)',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Não vincular'),
                      ),
                      ...availableTransactions.map((transaction) {
                        return DropdownMenuItem(
                          value: transaction.id,
                          child: Text(
                            '${transaction.description} — '
                            '${_currency(transaction.amount)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      if (hasUnavailableLink)
                        DropdownMenuItem(
                          value: _selectedPendingTransactionId,
                          enabled: false,
                          child: const Text(
                            'Vínculo indisponível — selecione outro',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPendingTransactionId = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Desconto por antecipação',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor do desconto (opcional)',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.discount_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final discount = _parseAmount(value);
                      final amount = _parseAmount(_amountController.text);

                      if (discount == null ||
                          !discount.isFinite ||
                          amount == null ||
                          discount <= 0 ||
                          discount >= amount) {
                        return 'Informe um desconto válido.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(isDiscountDate: true),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      _discountDeadline == null
                          ? 'Selecionar data limite do desconto'
                          : 'Desconto até: ${_formatDate(_discountDeadline!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saveBill,
                    icon: Icon(
                      _isEditing ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    label: Text(
                      _isEditing ? 'Salvar alterações' : 'Cadastrar conta',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
