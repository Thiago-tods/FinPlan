
import 'package:flutter/material.dart';

import '../../domain/entities/bank_account.dart';

class AccountFormPage extends StatefulWidget {
  final BankAccount? account;

  const AccountFormPage({
    super.key,
    this.account,
  });

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bankController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _balanceController;

  BankAccountType _selectedType = BankAccountType.checking;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    _bankController = TextEditingController(
      text: account?.bankName ?? '',
    );

    _nicknameController = TextEditingController(
      text: account?.nickname ?? '',
    );

    _balanceController = TextEditingController(
      text: account == null
          ? ''
          : account.initialBalance.toStringAsFixed(2).replaceAll('.', ','),
    );

    if (account != null) {
      _selectedType = account.type;
    }
  }

  @override
  void dispose() {
    _bankController.dispose();
    _nicknameController.dispose();
    _balanceController.dispose();

    super.dispose();
  }

  
double? _parseBalance(String value) {
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

  void _saveAccount() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final balance = _parseBalance(_balanceController.text);

    if (balance == null) {
      return;
    }

    final account = BankAccount(
      id: widget.account?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      bankName: _bankController.text.trim(),
      nickname: _nicknameController.text.trim(),
      type: _selectedType,
      initialBalance: balance,
    );

    Navigator.pop(context, account);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar conta' : 'Nova conta',
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
                    Icons.account_balance_rounded,
                    size: 48,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing
                        ? 'Atualize os dados da sua conta'
                        : 'Cadastre uma conta bancária',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Informe os dados para acompanhar seu dinheiro '
                    'em um único lugar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _bankController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Instituição financeira',
                      hintText: 'Ex.: Nubank, Itaú, Banco do Brasil',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe a instituição financeira.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nicknameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Apelido da conta',
                      hintText: 'Ex.: Conta principal',
                      prefixIcon: Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe um apelido para a conta.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  DropdownButtonFormField<BankAccountType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de conta',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: BankAccountType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedType = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Saldo inicial',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o saldo inicial.';
                      }

                      final balance = _parseBalance(value);

                      if (balance == null) {
                        return 'Informe um valor válido.';
                      }

                      if (!balance.isFinite) {
                        return 'Informe um valor válido.';
                      }

                      if (balance < 0) {
                        return 'O saldo não pode ser negativo.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  FilledButton.icon(
                    onPressed: _saveAccount,
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
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
