
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../domain/entities/payable_bill.dart';

class PlanningStore extends ChangeNotifier {
  PlanningStore({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final List<PayableBill> _bills = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<PayableBill> get bills => List.unmodifiable(_bills);

  bool get isLoaded => _isLoaded;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  double get totalPending {
    return _bills
        .where((bill) => bill.status == BillStatus.pending)
        .fold(0.0, (total, bill) => total + bill.amount);
  }

  double get totalOverdue {
    return _bills
        .where((bill) => bill.isOverdue)
        .fold(0.0, (total, bill) => total + bill.amount);
  }

  double get totalPaid {
    return _bills
        .where((bill) => bill.status == BillStatus.paid)
        .fold(0.0, (total, bill) => total + bill.amount);
  }

  int get pendingCount {
    return _bills
        .where((bill) => bill.status == BillStatus.pending)
        .length;
  }

  int get overdueCount {
    return _bills.where((bill) => bill.isOverdue).length;
  }

  Future<void> loadBills({bool force = false}) async {
    if (_isLoading || (_isLoaded && !force)) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/payable-bills');

      final data = response.data as List<dynamic>;

      _bills
        ..clear()
        ..addAll(
          data.map(
            (item) => PayableBill.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível carregar suas contas a pagar.',
      );

      debugPrint('Erro ao carregar contas a pagar: ${error.message}');
      rethrow;
    } catch (error) {
      _errorMessage = 'Ocorreu um erro ao carregar suas contas a pagar.';
      debugPrint('Erro inesperado ao carregar contas: $error');
      rethrow;
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<PayableBill> saveBill(PayableBill bill) async {
    _validateBill(bill);
    _validateLinkedTransaction(bill);

    _errorMessage = null;

    try {
      final index = _bills.indexWhere(
        (item) => item.id == bill.id,
      );

      final Response<dynamic> response;

      if (index >= 0) {
        response = await _apiClient.dio.patch(
          '/payable-bills/${bill.id}',
          data: bill.toApiJson(),
        );
      } else {
        response = await _apiClient.dio.post(
          '/payable-bills',
          data: bill.toApiJson(),
        );
      }

      final savedBill = PayableBill.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (index >= 0) {
        _bills[index] = savedBill;
      } else {
        _bills.insert(0, savedBill);
      }

      notifyListeners();

      return savedBill;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível salvar a conta.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBill(String id) async {
    _errorMessage = null;

    try {
      await _apiClient.dio.delete('/payable-bills/$id');

      _bills.removeWhere((bill) => bill.id == id);

      notifyListeners();
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível excluir a conta.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<PayableBill> cancelBill(String id) async {
    _errorMessage = null;

    try {
      final response = await _apiClient.dio.post(
        '/payable-bills/$id/cancel',
      );

      final cancelledBill = PayableBill.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      _replaceBill(cancelledBill);

      return cancelledBill;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível cancelar a conta.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<PayableBill> payBill(
    String id, {
    required String accountId,
    required DateTime paidAt,
    required BillCategory category,
  }) async {
    _errorMessage = null;

    try {
      final response = await _apiClient.dio.post(
        '/payable-bills/$id/pay',
        data: {
          'accountId': accountId,
          'paidAt': paidAt.toIso8601String(),
          'category': category.name,
        },
      );

      final responseData = Map<String, dynamic>.from(
        response.data as Map,
      );

      final billData = Map<String, dynamic>.from(
        responseData['bill'] as Map,
      );

      final paidBill = PayableBill.fromJson(billData);

      _replaceBill(paidBill);

      return paidBill;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível registrar o pagamento.',
      );

      notifyListeners();
      rethrow;
    }
  }

  void _replaceBill(PayableBill bill) {
    final index = _bills.indexWhere(
      (item) => item.id == bill.id,
    );

    if (index >= 0) {
      _bills[index] = bill;
    } else {
      _bills.insert(0, bill);
    }

    notifyListeners();
  }

  void _validateBill(PayableBill bill) {
    if (bill.description.trim().length < 2) {
      throw ArgumentError(
        'A descrição deve possuir pelo menos dois caracteres.',
      );
    }

    if (!bill.amount.isFinite ||
        bill.amount <= 0 ||
        bill.amount > 9999999999999.99) {
      throw ArgumentError('O valor informado é inválido.');
    }

    if (bill.discountAmount != null) {
      if (!bill.discountAmount!.isFinite ||
          bill.discountAmount! <= 0 ||
          bill.discountAmount! >= bill.amount) {
        throw ArgumentError(
          'O desconto deve ser positivo e menor que a conta.',
        );
      }

      if (bill.discountDeadline == null) {
        throw ArgumentError('Informe a data limite do desconto.');
      }

      if (bill.discountDeadline!.isAfter(bill.dueDate)) {
        throw ArgumentError(
          'A data limite do desconto não pode ser posterior ao vencimento.',
        );
      }
    }
  }

  void _validateLinkedTransaction(PayableBill bill) {
    final linkedId = bill.linkedPendingTransactionId;

    if (linkedId == null) return;

    final alreadyLinked = _bills.any((existingBill) {
      return existingBill.id != bill.id &&
          existingBill.linkedPendingTransactionId == linkedId;
    });

    if (alreadyLinked) {
      throw ArgumentError(
        'Esta transação já está vinculada a outra conta a pagar.',
      );
    }
  }

  String _getErrorMessage(
    DioException error,
    String fallback,
  ) {
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];

      if (message is String) return message;

      if (message is List) return message.join('\n');
    }

    return fallback;
  }

  List<PayableBill> billsForMonth(int year, int month) {
    return _bills.where((bill) {
      return bill.dueDate.year == year &&
          bill.dueDate.month == month;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
}
