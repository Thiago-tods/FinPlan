class CashFlowDay {
  final DateTime date;
  final double openingBalance;
  final double income;
  final double expenses;
  final double closingBalance;

  const CashFlowDay({
    required this.date,
    required this.openingBalance,
    required this.income,
    required this.expenses,
    required this.closingBalance,
  });

  bool get isNegative => closingBalance < 0;

  double get netChange => income - expenses;
}

class CashFlowProjection {
  final double initialBalance;
  final List<CashFlowDay> days;

  const CashFlowProjection({required this.initialBalance, required this.days});

  double get totalIncome {
    return days.fold(0.0, (total, day) => total + day.income);
  }

  double get totalExpenses {
    return days.fold(0.0, (total, day) => total + day.expenses);
  }

  double get projectedBalance {
    if (days.isEmpty) return initialBalance;

    return days.last.closingBalance;
  }

  double get lowestBalance {
    return days.fold(initialBalance, (lowest, day) {
      return day.closingBalance < lowest ? day.closingBalance : lowest;
    });
  }

  int get negativeDaysCount {
    return days.where((day) => day.isNegative).length;
  }

  List<CashFlowDay> get negativeDays {
    return days.where((day) => day.isNegative).toList();
  }

  bool get hasNegativeBalance => negativeDaysCount > 0;
}
