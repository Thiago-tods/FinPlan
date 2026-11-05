
enum TransactionType {
  income,
  expense,
}

enum TransactionStatus {
  pending,
  completed,
  cancelled,
}

enum TransactionCategory {
  salary,
  freelance,
  investment,
  food,
  housing,
  transportation,
  health,
  education,
  entertainment,
  shopping,
  bills,
  taxes,
  other,
}

extension TransactionTypeExtension on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Receita';
      case TransactionType.expense:
        return 'Despesa';
    }
  }
}

extension TransactionStatusExtension on TransactionStatus {
  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pendente';
      case TransactionStatus.completed:
        return 'Concluída';
      case TransactionStatus.cancelled:
        return 'Cancelada';
    }
  }
}

extension TransactionCategoryExtension on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.salary:
        return 'Salário';
      case TransactionCategory.freelance:
        return 'Trabalho autônomo';
      case TransactionCategory.investment:
        return 'Investimentos';
      case TransactionCategory.food:
        return 'Alimentação';
      case TransactionCategory.housing:
        return 'Moradia';
      case TransactionCategory.transportation:
        return 'Transporte';
      case TransactionCategory.health:
        return 'Saúde';
      case TransactionCategory.education:
        return 'Educação';
      case TransactionCategory.entertainment:
        return 'Lazer';
      case TransactionCategory.shopping:
        return 'Compras';
      case TransactionCategory.bills:
        return 'Contas';
      case TransactionCategory.taxes:
        return 'Impostos';
      case TransactionCategory.other:
        return 'Outros';
    }
  }
}

class FinancialTransaction {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final String accountId;
  final DateTime transactionDate;
  final DateTime dueDate;
  final TransactionStatus status;
  final String? notes;

  const FinancialTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.transactionDate,
    required this.dueDate,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'accountId': accountId,
      'transactionDate': transactionDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'description': description,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'accountId': accountId,
      'transactionDate': transactionDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory FinancialTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    final amount = json['amount'];

    return FinancialTransaction(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: amount is num
          ? amount.toDouble()
          : double.parse(amount as String),
      type: TransactionType.values.byName(
        json['type'] as String,
      ),
      category: TransactionCategory.values.byName(
        json['category'] as String,
      ),
      accountId: json['accountId'] as String,
      transactionDate: DateTime.parse(
        json['transactionDate'] as String,
      ),
      dueDate: DateTime.parse(
        json['dueDate'] as String,
      ),
      status: TransactionStatus.values.byName(
        json['status'] as String,
      ),
      notes: json['notes'] as String?,
    );
  }

  FinancialTransaction copyWith({
    String? description,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    String? accountId,
    DateTime? transactionDate,
    DateTime? dueDate,
    TransactionStatus? status,
    String? notes,
  }) {
    return FinancialTransaction(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      transactionDate: transactionDate ?? this.transactionDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
