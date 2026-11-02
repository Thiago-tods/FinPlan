import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/payable_bill.dart';

class PlanningStore extends ChangeNotifier {
  static const String _storageKey = 'finplan_payable_bills';

  final List<PayableBill> _bills = [];

  bool _isLoaded = false;
  bool _isLoading = false;

  List<PayableBill> get bills => List.unmodifiable(_bills);

  bool get isLoaded => _isLoaded;

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

  Future<void> loadBills() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final storedData = preferences.getString(_storageKey);

      if (storedData != null) {
        try {
          final decodedData = jsonDecode(storedData) as List<dynamic>;

          _bills
            ..clear()
            ..addAll(
              decodedData.map(
                (item) => PayableBill.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              ),
            );
        } catch (error) {
          debugPrint('Erro ao carregar contas a pagar: $error');
          _bills.clear();
        }
      }
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveBills() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      _bills.map((bill) => bill.toJson()).toList(),
    );

    await preferences.setString(_storageKey, encodedData);
  }

  Future<void> saveBill(PayableBill bill) async {
    if (bill.description.trim().isEmpty) {
      throw ArgumentError('A descrição não pode estar vazia.');
    }

    if (!bill.amount.isFinite || bill.amount <= 0) {
      throw ArgumentError('O valor deve ser maior que zero.');
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

    final index = _bills.indexWhere(
      (item) => item.id == bill.id,
    );

    if (index >= 0) {
      _bills[index] = bill;
    } else {
      _bills.add(bill);
    }

    notifyListeners();

    await _saveBills();
  }

  Future<void> deleteBill(String id) async {
    _bills.removeWhere((bill) => bill.id == id);

    notifyListeners();

    await _saveBills();
  }

  Future<void> updateBillStatus(
    String id,
    BillStatus status, {
    DateTime? paidAt,
    String? accountId,
    String? linkedTransactionId,
  }) async {
    final index = _bills.indexWhere(
      (bill) => bill.id == id,
    );

    if (index == -1) return;

    final currentBill = _bills[index];

    _bills[index] = PayableBill(
      id: currentBill.id,
      description: currentBill.description,
      amount: currentBill.amount,
      category: currentBill.category,
      dueDate: currentBill.dueDate,
      discountDeadline: currentBill.discountDeadline,
      discountAmount: currentBill.discountAmount,
      status: status,
      paidAt: status == BillStatus.paid
          ? paidAt ?? DateTime.now()
          : null,
      accountId: status == BillStatus.paid
          ? accountId ?? currentBill.accountId
          : null,
      linkedTransactionId: status == BillStatus.paid
          ? linkedTransactionId ?? currentBill.linkedTransactionId
          : null,
      notes: currentBill.notes,
    );

    notifyListeners();

    await _saveBills();
  }

  List<PayableBill> billsForMonth(int year, int month) {
    return _bills.where((bill) {
      return bill.dueDate.year == year &&
          bill.dueDate.month == month;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
}