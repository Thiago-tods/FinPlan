import '../entities/cash_flow_projection.dart';
import '../entities/payable_bill.dart';
import '../../../transactions/domain/entities/transaction.dart';

class CashFlowService {
  CashFlowProjection project({
    required double currentBalance,
    required List<FinancialTransaction> transactions,
    required List<PayableBill> bills,
    required int days,
    DateTime? referenceDate,
  }) {
    if (!currentBalance.isFinite) {
      throw ArgumentError('O saldo inicial deve ser um valor válido.');
    }

    if (days <= 0) {
      throw ArgumentError('O período deve ser maior que zero.');
    }

    final reference = referenceDate ?? DateTime.now();

    final startDate = DateTime(reference.year, reference.month, reference.day);

    final endDate = startDate.add(Duration(days: days - 1));

    final dailyIncome = <DateTime, double>{};
    final dailyExpenses = <DateTime, double>{};

    // Identifica transações já representadas por contas pendentes.
    final linkedPendingTransactionIds = bills
        .where((bill) => bill.status == BillStatus.pending)
        .map((bill) => bill.linkedPendingTransactionId)
        .whereType<String>()
        .toSet();

    void addEvent({
      required DateTime date,
      required double amount,
      required bool isIncome,
    }) {
      var eventDate = DateTime(date.year, date.month, date.day);

      // Compromissos vencidos continuam pendentes:
      // serão considerados no primeiro dia da projeção.
      if (eventDate.isBefore(startDate)) {
        eventDate = startDate;
      }

      if (eventDate.isAfter(endDate)) {
        return;
      }

      final destination = isIncome ? dailyIncome : dailyExpenses;

      destination[eventDate] = (destination[eventDate] ?? 0.0) + amount;
    }

    for (final transaction in transactions) {
      if (transaction.status != TransactionStatus.pending) {
        continue;
      }

      // A conta a pagar já representa esta obrigação.
      if (linkedPendingTransactionIds.contains(transaction.id)) {
        continue;
      }

      if (transaction.amount <= 0 || !transaction.amount.isFinite) {
        continue;
      }

      addEvent(
        date: transaction.dueDate,
        amount: transaction.amount,
        isIncome: transaction.type == TransactionType.income,
      );
    }

    for (final bill in bills) {
      if (bill.status != BillStatus.pending) {
        continue;
      }

      if (bill.amount <= 0 || !bill.amount.isFinite) {
        continue;
      }

      addEvent(date: bill.dueDate, amount: bill.amount, isIncome: false);
    }

    final projectedDays = <CashFlowDay>[];

    var balance = currentBalance;

    for (var index = 0; index < days; index++) {
      final date = startDate.add(Duration(days: index));

      final income = dailyIncome[date] ?? 0.0;
      final expenses = dailyExpenses[date] ?? 0.0;

      final openingBalance = balance;

      balance += income;
      balance -= expenses;

      projectedDays.add(
        CashFlowDay(
          date: date,
          openingBalance: openingBalance,
          income: income,
          expenses: expenses,
          closingBalance: balance,
        ),
      );
    }

    return CashFlowProjection(
      initialBalance: currentBalance,
      days: projectedDays,
    );
  }
}
