import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/features/planning/domain/entities/payable_bill.dart';
import 'package:finplan/features/planning/domain/services/early_payment_service.dart';
import 'package:finplan/features/transactions/domain/entities/transaction.dart';

void main() {
  late EarlyPaymentService service;

  final referenceDate = DateTime(2026, 11, 2);

  setUp(() {
    service = EarlyPaymentService();
  });

  PayableBill createBill({
    String id = 'bill-1',
    double amount = 300,
    double discountAmount = 30,
    DateTime? dueDate,
    DateTime? discountDeadline,
    BillStatus status = BillStatus.pending,
    String? linkedPendingTransactionId,
  }) {
    return PayableBill(
      id: id,
      description: 'Conta de teste',
      amount: amount,
      category: BillCategory.utilities,
      dueDate: dueDate ?? DateTime(2026, 11, 10),
      discountDeadline: discountDeadline ?? DateTime(2026, 11, 5),
      discountAmount: discountAmount,
      status: status,
      linkedPendingTransactionId: linkedPendingTransactionId,
    );
  }

  FinancialTransaction createTransaction({
    required String id,
    required double amount,
    required TransactionType type,
    DateTime? dueDate,
  }) {
    return FinancialTransaction(
      id: id,
      description: 'Movimentação de teste',
      amount: amount,
      type: type,
      category: TransactionCategory.other,
      accountId: 'account-1',
      transactionDate: referenceDate,
      dueDate: dueDate ?? DateTime(2026, 11, 4),
      status: TransactionStatus.pending,
    );
  }

  group('EarlyPaymentService', () {
    test('recomenda pagamento quando a reserva mínima é preservada', () {
      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [],
        bills: [createBill()],
        referenceDate: referenceDate,
      );

      expect(recommendations, hasLength(1));
      expect(recommendations.first.paymentAmount, 270);
      expect(recommendations.first.savings, 30);
      expect(recommendations.first.projectedBalanceAfterPayment, 730);
      expect(recommendations.first.minimumReserve, 200);
    });

    test('não recomenda pagamento quando compromete a reserva', () {
      final recommendations = service.recommend(
        currentBalance: 300,
        transactions: [],
        bills: [createBill()],
        referenceDate: referenceDate,
      );

      expect(recommendations, isEmpty);
    });

    test('considera receitas e despesas pendentes', () {
      final transactions = [
        createTransaction(
          id: 'income-1',
          amount: 200,
          type: TransactionType.income,
        ),
        createTransaction(
          id: 'expense-1',
          amount: 50,
          type: TransactionType.expense,
        ),
      ];

      final otherBill = createBill(
        id: 'bill-2',
        amount: 100,
        discountAmount: 0,
        discountDeadline: null,
        dueDate: DateTime(2026, 11, 4),
      );

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: transactions,
        bills: [createBill(), otherBill],
        referenceDate: referenceDate,
      );

      expect(recommendations, hasLength(1));
      expect(recommendations.first.projectedBalanceBeforePayment, 1050);
      expect(recommendations.first.projectedBalanceAfterPayment, 780);
    });

    test('considera compromissos vencidos como pendentes hoje', () {
      final overdueTransaction = createTransaction(
        id: 'expense-overdue',
        amount: 100,
        type: TransactionType.expense,
        dueDate: DateTime(2026, 10, 30),
      );

      final overdueBill = createBill(
        id: 'bill-overdue',
        amount: 200,
        discountAmount: 0,
        discountDeadline: null,
        dueDate: DateTime(2026, 10, 30),
      );

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [overdueTransaction],
        bills: [createBill(), overdueBill],
        referenceDate: referenceDate,
      );

      expect(recommendations, hasLength(1));
      expect(recommendations.first.projectedBalanceBeforePayment, 700);
    });

    test('não recomenda contas sem desconto', () {
      final bill = createBill(discountAmount: 0, discountDeadline: null);

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [],
        bills: [bill],
        referenceDate: referenceDate,
      );

      expect(recommendations, isEmpty);
    });

    test('não recomenda contas com prazo de desconto vencido', () {
      final bill = createBill(discountDeadline: DateTime(2026, 11, 1));

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [],
        bills: [bill],
        referenceDate: referenceDate,
      );

      expect(recommendations, isEmpty);
    });

    test('não recomenda contas já pagas', () {
      final bill = createBill(status: BillStatus.paid);

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [],
        bills: [bill],
        referenceDate: referenceDate,
      );

      expect(recommendations, isEmpty);
    });

    test('permite configurar outro percentual de reserva', () {
      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [],
        bills: [createBill()],
        referenceDate: referenceDate,
        reservePercentage: 0.50,
      );

      expect(recommendations, hasLength(1));
      expect(recommendations.first.minimumReserve, 500);
    });

    test('rejeita percentual de reserva inválido', () {
      expect(
        () => service.recommend(
          currentBalance: 1000,
          transactions: [],
          bills: [],
          referenceDate: referenceDate,
          reservePercentage: 1,
        ),
        throwsArgumentError,
      );
    });

    test('não desconta novamente transação vinculada à conta analisada', () {
      final linkedBill = createBill(
        linkedPendingTransactionId: 'expense-linked',
      );

      final linkedTransaction = createTransaction(
        id: 'expense-linked',
        amount: 300,
        type: TransactionType.expense,
        dueDate: DateTime(2026, 11, 4),
      );

      final recommendations = service.recommend(
        currentBalance: 1000,
        transactions: [linkedTransaction],
        bills: [linkedBill],
        referenceDate: referenceDate,
      );

      expect(recommendations, hasLength(1));
      expect(recommendations.first.projectedBalanceBeforePayment, 1000);
      expect(recommendations.first.projectedBalanceAfterPayment, 730);
    });
  });
}
