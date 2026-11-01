
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/bank_account.dart';

class AccountsStore extends ChangeNotifier {
  static const String _storageKey = 'finplan_bank_accounts';

  final List<BankAccount> _accounts = [];

  bool _isLoaded = false;

  List<BankAccount> get accounts => List.unmodifiable(_accounts);

  bool get isLoaded => _isLoaded;

  double get totalBalance {
    return _accounts.fold(
      0.0,
      (total, account) => total + account.initialBalance,
    );
  }

  Future<void> loadAccounts() async {
    final preferences = await SharedPreferences.getInstance();

    final storedData = preferences.getString(_storageKey);

    if (storedData != null) {
      try {
        final decodedData = jsonDecode(storedData) as List<dynamic>;

        _accounts
          ..clear()
          ..addAll(
            decodedData.map(
              (item) => BankAccount.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
      } catch (error) {
        debugPrint('Erro ao carregar contas: $error');
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveAccounts() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      _accounts.map((account) => account.toJson()).toList(),
    );

    await preferences.setString(_storageKey, encodedData);
  }

  Future<void> saveAccount(BankAccount account) async {
    final index = _accounts.indexWhere(
      (item) => item.id == account.id,
    );

    if (index >= 0) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }

    notifyListeners();

    await _saveAccounts();
  }

  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((account) => account.id == id);

    notifyListeners();

    await _saveAccounts();
  }
}
