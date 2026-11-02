class EarlyPaymentRecommendation {
  final String billId;
  final String billDescription;
  final DateTime discountDeadline;
  final double originalAmount;
  final double discountAmount;
  final double paymentAmount;
  final double projectedBalanceBeforePayment;
  final double projectedBalanceAfterPayment;
  final double minimumReserve;

  const EarlyPaymentRecommendation({
    required this.billId,
    required this.billDescription,
    required this.discountDeadline,
    required this.originalAmount,
    required this.discountAmount,
    required this.paymentAmount,
    required this.projectedBalanceBeforePayment,
    required this.projectedBalanceAfterPayment,
    required this.minimumReserve,
  });

  double get savings => discountAmount;
}