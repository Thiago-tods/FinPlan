
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../domain/entities/transaction.dart';

class TransactionsStore extends ChangeNotifier {
  TransactionsStore({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  final List<FinancialTransaction> _transactions = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<FinancialTransaction> get transactions {
    return List.unmodifiable(_transactions);
  }

  bool get isLoaded => _isLoaded;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

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

  Future<void> loadTransactions({bool force = false}) async {
    if (_isLoading || (_isLoaded && !force)) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/transactions');

      final data = response.data as List<dynamic>;

      _transactions
        ..clear()
        ..addAll(
          data.map(
            (item) => FinancialTransaction.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível carregar suas movimentações.',
      );

      debugPrint('Erro ao carregar movimentações: ${error.message}');
    } catch (error) {
      _errorMessage = 'Ocorreu um erro ao carregar suas movimentações.';
      debugPrint('Erro inesperado ao carregar movimentações: $error');
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<FinancialTransaction> saveTransaction(
    FinancialTransaction transaction,
  ) async {
    if (transaction.amount <= 0 || !transaction.amount.isFinite) {
      throw ArgumentError('O valor deve ser maior que zero.');
    }

    if (transaction.description.trim().isEmpty) {
      throw ArgumentError('A descrição não pode estar vazia.');
    }

    if (transaction.accountId.isEmpty) {
      throw ArgumentError('Uma conta bancária deve ser selecionada.');
    }

    _errorMessage = null;

    try {
      final index = _transactions.indexWhere(
        (item) => item.id == transaction.id,
      );

      final Response<dynamic> response;

      if (index >= 0) {
        response = await _apiClient.dio.patch(
          '/transactions/${transaction.id}',
          data: transaction.toApiJson(),
        );
      } else {
        response = await _apiClient.dio.post(
          '/transactions',
          data: transaction.toApiJson(),
        );
      }

      final savedTransaction = FinancialTransaction.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (index >= 0) {
        _transactions[index] = savedTransaction;
      } else {
        _transactions.insert(0, savedTransaction);
      }

      notifyListeners();

      return savedTransaction;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível salvar a movimentação.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    _errorMessage = null;

    try {
      await _apiClient.dio.delete('/transactions/$id');

      _transactions.removeWhere(
        (transaction) => transaction.id == id,
      );

      notifyListeners();
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível excluir a movimentação.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTransactionStatus(
    String id,
    TransactionStatus status,
  ) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == id,
    );

    if (index == -1) return;

    _errorMessage = null;

    try {
      final response = await _apiClient.dio.patch(
        '/transactions/$id',
        data: {
          'status': status.name,
        },
      );

      final updatedTransaction = FinancialTransaction.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      _transactions[index] = updatedTransaction;

      notifyListeners();
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível atualizar o status da movimentação.',
      );

      notifyListeners();
      rethrow;
    }
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

  String _getErrorMessage(
    DioException error,
    String fallback,
  ) {
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];

      if (message is String) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
    }

    return fallback;
  }
}
