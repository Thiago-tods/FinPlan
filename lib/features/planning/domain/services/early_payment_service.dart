
import '../entities/early_payment_recommendation.dart';
import '../entities/payable_bill.dart';
import '../../../transactions/domain/entities/transaction.dart';

class EarlyPaymentService {
  static const double defaultReservePercentage = 0.20;

  List<EarlyPaymentRecommendation> recommend({
    required double currentBalance,
    required List<FinancialTransaction> transactions,
    required List<PayableBill> bills,
    DateTime? referenceDate,
    double reservePercentage = defaultReservePercentage,
  }) {
    if (!currentBalance.isFinite) {
      throw ArgumentError('O saldo atual deve ser um valor válido.');
    }

    if (!reservePercentage.isFinite ||
        reservePercentage < 0 ||
        reservePercentage >= 1) {
      throw ArgumentError(
        'A reserva deve ser igual ou superior a 0% e inferior a 100%.',
      );
    }

    final today = referenceDate ?? DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);

    final recommendations = <EarlyPaymentRecommendation>[];

    for (final bill in bills) {
      if (bill.status != BillStatus.pending) continue;

      final discountAmount = bill.discountAmount;
      final discountDeadline = bill.discountDeadline;

      if (discountAmount == null || discountDeadline == null) {
        continue;
      }

      final normalizedDeadline = DateTime(
        discountDeadline.year,
        discountDeadline.month,
        discountDeadline.day,
      );

      final dueDate = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );

      if (normalizedDeadline.isBefore(startDate) ||
          normalizedDeadline.isAfter(dueDate)) {
        continue;
      }

      if (!bill.amount.isFinite ||
          bill.amount <= 0 ||
          !discountAmount.isFinite ||
          discountAmount <= 0 ||
          discountAmount >= bill.amount) {
        continue;
      }

      final balanceBeforePayment = _projectBalanceUntil(
        currentBalance: currentBalance,
        transactions: transactions,
        bills: bills,
        deadline: normalizedDeadline,
        excludedBillId: bill.id,
        startDate: startDate,
      );

      if (balanceBeforePayment <= 0) continue;

      final paymentAmount = bill.amount - discountAmount;
      final minimumReserve = balanceBeforePayment * reservePercentage;
      final balanceAfterPayment = balanceBeforePayment - paymentAmount;

      if (balanceAfterPayment < minimumReserve) continue;

      recommendations.add(
        EarlyPaymentRecommendation(
          billId: bill.id,
          billDescription: bill.description,
          discountDeadline: normalizedDeadline,
          originalAmount: bill.amount,
          discountAmount: discountAmount,
          paymentAmount: paymentAmount,
          projectedBalanceBeforePayment: balanceBeforePayment,
          projectedBalanceAfterPayment: balanceAfterPayment,
          minimumReserve: minimumReserve,
        ),
      );
    }

    recommendations.sort((a, b) {
      return a.discountDeadline.compareTo(b.discountDeadline);
    });

    return recommendations;
  }

  double _projectBalanceUntil({
    required double currentBalance,
    required List<FinancialTransaction> transactions,
    required List<PayableBill> bills,
    required DateTime deadline,
    required String excludedBillId,
    required DateTime startDate,
  }) {
    var balance = currentBalance;

    for (final transaction in transactions) {
      if (transaction.status != TransactionStatus.pending) continue;

      if (!transaction.amount.isFinite || transaction.amount <= 0) {
        continue;
      }

      final eventDate = _adjustEventDate(
        transaction.dueDate,
        startDate,
      );

      if (eventDate.isAfter(deadline)) continue;

      if (transaction.type == TransactionType.income) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }

    for (final bill in bills) {
      if (bill.id == excludedBillId ||
          bill.status != BillStatus.pending) {
        continue;
      }

      if (!bill.amount.isFinite || bill.amount <= 0) continue;

      final eventDate = _adjustEventDate(
        bill.dueDate,
        startDate,
      );

      if (eventDate.isAfter(deadline)) continue;

      balance -= bill.amount;
    }

    return balance;
  }

  DateTime _adjustEventDate(DateTime date, DateTime startDate) {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    if (normalizedDate.isBefore(startDate)) {
      return startDate;
    }

    return normalizedDate;
  }
}
