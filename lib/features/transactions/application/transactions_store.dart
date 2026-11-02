
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/transaction.dart';

class TransactionsStore extends ChangeNotifier {
  static const String _storageKey = 'finplan_transactions';

  final List<FinancialTransaction> _transactions = [];

  bool _isLoaded = false;
  bool _isLoading = false;

  List<FinancialTransaction> get transactions {
    return List.unmodifiable(_transactions);
  }

  bool get isLoaded => _isLoaded;

  double get totalIncome {
    return _transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.income &&
              transaction.status == TransactionStatus.completed,
        )
        .fold(0.0, (total, transaction) => total + transaction.amount);
  }

  double get totalExpenses {
    return _transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.expense &&
              transaction.status == TransactionStatus.completed,
        )
        .fold(0.0, (total, transaction) => total + transaction.amount);
  }

  double get pendingAmount {
    return _transactions
        .where(
          (transaction) =>
              transaction.status == TransactionStatus.pending,
        )
        .fold(0.0, (total, transaction) => total + transaction.amount);
  }

  Future<void> loadTransactions() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final storedData = preferences.getString(_storageKey);

      if (storedData != null) {
        try {
          final decodedData = jsonDecode(storedData) as List<dynamic>;

          _transactions
            ..clear()
            ..addAll(
              decodedData.map(
                (item) => FinancialTransaction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              ),
            );
        } catch (error) {
          debugPrint('Erro ao carregar movimentações: $error');
          _transactions.clear();
        }
      }
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveTransactions() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      _transactions
          .map((transaction) => transaction.toJson())
          .toList(),
    );

    await preferences.setString(_storageKey, encodedData);
  }

  Future<void> saveTransaction(
    FinancialTransaction transaction,
  ) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('O valor deve ser maior que zero.');
    }

    if (transaction.description.trim().isEmpty) {
      throw ArgumentError('A descrição não pode estar vazia.');
    }

    if (transaction.accountId.isEmpty) {
      throw ArgumentError('Uma conta bancária deve ser selecionada.');
    }

    final index = _transactions.indexWhere(
      (item) => item.id == transaction.id,
    );

    if (index >= 0) {
      _transactions[index] = transaction;
    } else {
      _transactions.add(transaction);
    }

    notifyListeners();

    await _saveTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere(
      (transaction) => transaction.id == id,
    );

    notifyListeners();

    await _saveTransactions();
  }

  Future<void> updateTransactionStatus(
    String id,
    TransactionStatus status,
  ) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == id,
    );

    if (index == -1) return;

    final updatedTransaction = FinancialTransaction(
      id: _transactions[index].id,
      description: _transactions[index].description,
      amount: _transactions[index].amount,
      type: _transactions[index].type,
      category: _transactions[index].category,
      accountId: _transactions[index].accountId,
      transactionDate: _transactions[index].transactionDate,
      dueDate: _transactions[index].dueDate,
      status: status,
      notes: _transactions[index].notes,
    );

    _transactions[index] = updatedTransaction;

    notifyListeners();

    await _saveTransactions();
  }

  double balanceForAccount({
    required String accountId,
    required double initialBalance,
  }) {
    final accountTransactions = _transactions.where(
      (transaction) =>
          transaction.accountId == accountId &&
          transaction.status == TransactionStatus.completed,
    );

    return accountTransactions.fold(
      initialBalance,
      (balance, transaction) {
        if (transaction.type == TransactionType.income) {
          return balance + transaction.amount;
        }

        return balance - transaction.amount;
      },
    );
  }
}
