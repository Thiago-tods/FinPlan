import 'package:flutter_test/flutter_test.dart';

import 'package:finplan/features/planning/domain/entities/payable_bill.dart';
import 'package:finplan/features/planning/domain/services/cash_flow_service.dart';
import 'package:finplan/features/transactions/domain/entities/transaction.dart';

void main() {
  late CashFlowService service;

  final referenceDate = DateTime(2026, 11, 2);

  setUp(() {
    service = CashFlowService();
  });

  FinancialTransaction createTransaction({
    required String id,
    required double amount,
    required TransactionType type,
    required TransactionStatus status,
    required DateTime dueDate,
  }) {
    return FinancialTransaction(
      id: id,
      description: 'Movimentação de teste',
      amount: amount,
      type: type,
      category: TransactionCategory.other,
      accountId: 'account-1',
      transactionDate: referenceDate,
      dueDate: dueDate,
      status: status,
    );
  }

  PayableBill createBill({
    required String id,
    required double amount,
    required BillStatus status,
    required DateTime dueDate,
    String? linkedPendingTransactionId,
  }) {
    return PayableBill(
      id: id,
      description: 'Conta de teste',
      amount: amount,
      category: BillCategory.other,
      dueDate: dueDate,
      status: status,
      linkedPendingTransactionId: linkedPendingTransactionId,
    );
  }

  group('CashFlowService', () {
    test('calcula saldo projetado com receitas e despesas pendentes', () {
      final projection = service.project(
        currentBalance: 3000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [
          createTransaction(
            id: '1',
            amount: 2000,
            type: TransactionType.income,
            status: TransactionStatus.pending,
            dueDate: DateTime(2026, 11, 3),
          ),
          createTransaction(
            id: '2',
            amount: 500,
            type: TransactionType.expense,
            status: TransactionStatus.pending,
            dueDate: DateTime(2026, 11, 4),
          ),
        ],
        bills: [
          createBill(
            id: '3',
            amount: 300,
            status: BillStatus.pending,
            dueDate: DateTime(2026, 11, 5),
          ),
        ],
      );

      expect(projection.initialBalance, 3000);
      expect(projection.totalIncome, 2000);
      expect(projection.totalExpenses, 800);
      expect(projection.projectedBalance, 4200);
    });

    test('ignora movimentações já concluídas', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [
          createTransaction(
            id: '1',
            amount: 500,
            type: TransactionType.expense,
            status: TransactionStatus.completed,
            dueDate: DateTime(2026, 11, 3),
          ),
        ],
        bills: [],
      );

      expect(projection.totalExpenses, 0);
      expect(projection.projectedBalance, 1000);
    });

    test('ignora contas já pagas e canceladas', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [],
        bills: [
          createBill(
            id: '1',
            amount: 300,
            status: BillStatus.paid,
            dueDate: DateTime(2026, 11, 3),
          ),
          createBill(
            id: '2',
            amount: 200,
            status: BillStatus.cancelled,
            dueDate: DateTime(2026, 11, 4),
          ),
        ],
      );

      expect(projection.totalExpenses, 0);
      expect(projection.projectedBalance, 1000);
    });

    test('identifica dias com saldo negativo', () {
      final projection = service.project(
        currentBalance: 500,
        referenceDate: referenceDate,
        days: 7,
        transactions: [],
        bills: [
          createBill(
            id: '1',
            amount: 800,
            status: BillStatus.pending,
            dueDate: DateTime(2026, 11, 4),
          ),
        ],
      );

      expect(projection.hasNegativeBalance, isTrue);
      expect(projection.negativeDaysCount, 5);
      expect(projection.lowestBalance, -300);
    });

    test('ignora eventos fora do período projetado', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [
          createTransaction(
            id: '1',
            amount: 500,
            type: TransactionType.income,
            status: TransactionStatus.pending,
            dueDate: DateTime(2026, 11, 10),
          ),
        ],
        bills: [
          createBill(
            id: '2',
            amount: 200,
            status: BillStatus.pending,
            dueDate: DateTime(2026, 11, 1),
          ),
        ],
      );

      expect(projection.totalIncome, 0);
      expect(projection.totalExpenses, 200);
      expect(projection.projectedBalance, 800);
      expect(projection.days.first.expenses, 200);
    });

    test('gera exatamente a quantidade de dias solicitada', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 15,
        transactions: [],
        bills: [],
      );

      expect(projection.days.length, 15);
      expect(projection.days.first.date, DateTime(2026, 11, 2));
      expect(projection.days.last.date, DateTime(2026, 11, 16));
    });

    test('rejeita períodos inválidos', () {
      expect(
        () => service.project(
          currentBalance: 1000,
          referenceDate: referenceDate,
          days: 0,
          transactions: [],
          bills: [],
        ),
        throwsArgumentError,
      );
    });

    test('não contabiliza duas vezes uma despesa vinculada', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [
          createTransaction(
            id: 'transaction-1',
            amount: 180,
            type: TransactionType.expense,
            status: TransactionStatus.pending,
            dueDate: DateTime(2026, 11, 4),
          ),
        ],
        bills: [
          createBill(
            id: 'bill-1',
            amount: 180,
            status: BillStatus.pending,
            dueDate: DateTime(2026, 11, 5),
            linkedPendingTransactionId: 'transaction-1',
          ),
        ],
      );

      expect(projection.totalExpenses, 180);
      expect(projection.projectedBalance, 820);
    });

    test('contabiliza transação quando a conta vinculada não está pendente', () {
      final projection = service.project(
        currentBalance: 1000,
        referenceDate: referenceDate,
        days: 7,
        transactions: [
          createTransaction(
            id: 'transaction-1',
            amount: 180,
            type: TransactionType.expense,
            status: TransactionStatus.pending,
            dueDate: DateTime(2026, 11, 4),
          ),
        ],
        bills: [
          createBill(
            id: 'bill-1',
            amount: 180,
            status: BillStatus.cancelled,
            dueDate: DateTime(2026, 11, 5),
            linkedPendingTransactionId: 'transaction-1',
          ),
        ],
      );

      expect(projection.totalExpenses, 180);
      expect(projection.projectedBalance, 820);
    });
  });
}
