
enum BankAccountType {
  checking,
  savings,
  payment,
  investment,
}

extension BankAccountTypeExtension on BankAccountType {
  String get label {
    switch (this) {
      case BankAccountType.checking:
        return 'Conta corrente';
      case BankAccountType.savings:
        return 'Conta poupança';
      case BankAccountType.payment:
        return 'Conta de pagamento / Carteira digital';
      case BankAccountType.investment:
        return 'Conta de investimentos';
    }
  }
}

class BankAccount {
  final String id;
  final String bankName;
  final String nickname;
  final BankAccountType type;
  final double initialBalance;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.nickname,
    required this.type,
    required this.initialBalance,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankName': bankName,
      'nickname': nickname,
      'type': type.name,
      'initialBalance': initialBalance,
    };
  }

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      bankName: json['bankName'] as String,
      nickname: json['nickname'] as String,
      type: BankAccountType.values.byName(
        json['type'] as String,
      ),
      initialBalance: (json['initialBalance'] as num).toDouble(),
    );
  }

  BankAccount copyWith({
    String? bankName,
    String? nickname,
    BankAccountType? type,
    double? initialBalance,
  }) {
    return BankAccount(
      id: id,
      bankName: bankName ?? this.bankName,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
    );
  }
}
