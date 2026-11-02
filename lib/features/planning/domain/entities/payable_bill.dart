
enum BillCategory {
  housing,
  utilities,
  food,
  transport,
  health,
  education,
  subscriptions,
  taxes,
  other,
}

extension BillCategoryLabel on BillCategory {
  String get label {
    switch (this) {
      case BillCategory.housing:
        return 'Moradia';
      case BillCategory.utilities:
        return 'Contas de consumo';
      case BillCategory.food:
        return 'Alimentação';
      case BillCategory.transport:
        return 'Transporte';
      case BillCategory.health:
        return 'Saúde';
      case BillCategory.education:
        return 'Educação';
      case BillCategory.subscriptions:
        return 'Assinaturas';
      case BillCategory.taxes:
        return 'Impostos';
      case BillCategory.other:
        return 'Outros';
    }
  }
}

enum BillStatus {
  pending,
  paid,
  cancelled,
}

extension BillStatusLabel on BillStatus {
  String get label {
    switch (this) {
      case BillStatus.pending:
        return 'Pendente';
      case BillStatus.paid:
        return 'Paga';
      case BillStatus.cancelled:
        return 'Cancelada';
    }
  }
}

class PayableBill {
  final String id;
  final String description;
  final double amount;
  final BillCategory category;
  final DateTime dueDate;
  final DateTime? discountDeadline;
  final double? discountAmount;
  final BillStatus status;
  final DateTime? paidAt;
  final String? accountId;

  // Transação pendente que representa esta obrigação.
  final String? linkedPendingTransactionId;

  // Transação efetivamente registrada após o pagamento.
  final String? linkedTransactionId;

  final String notes;

  const PayableBill({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.dueDate,
    this.discountDeadline,
    this.discountAmount,
    this.status = BillStatus.pending,
    this.paidAt,
    this.accountId,
    this.linkedPendingTransactionId,
    this.linkedTransactionId,
    this.notes = '',
  });

  bool get isOverdue {
    if (status != BillStatus.pending) return false;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final deadline = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    return deadline.isBefore(todayDate);
  }

  double get discountedAmount {
    if (discountAmount == null) return amount;

    return amount - discountAmount!;
  }

  bool get hasDiscount {
    return discountAmount != null &&
        discountAmount! > 0 &&
        discountDeadline != null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category.name,
      'dueDate': dueDate.toIso8601String(),
      'discountDeadline': discountDeadline?.toIso8601String(),
      'discountAmount': discountAmount,
      'status': status.name,
      'paidAt': paidAt?.toIso8601String(),
      'accountId': accountId,
      'linkedPendingTransactionId': linkedPendingTransactionId,
      'linkedTransactionId': linkedTransactionId,
      'notes': notes,
    };
  }

  factory PayableBill.fromJson(Map<String, dynamic> json) {
    return PayableBill(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: BillCategory.values.firstWhere(
        (item) => item.name == json['category'],
        orElse: () => BillCategory.other,
      ),
      dueDate: DateTime.parse(json['dueDate'] as String),
      discountDeadline: json['discountDeadline'] == null
          ? null
          : DateTime.parse(json['discountDeadline'] as String),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      status: BillStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => BillStatus.pending,
      ),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      accountId: json['accountId'] as String?,
      linkedPendingTransactionId:
          json['linkedPendingTransactionId'] as String?,
      linkedTransactionId: json['linkedTransactionId'] as String?,
      notes: json['notes'] as String? ?? '',
    );
  }
}
