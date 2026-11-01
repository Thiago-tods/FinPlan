
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finplan/features/transactions/application/transactions_store.dart';
import 'package:finplan/features/transactions/domain/entities/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TransactionsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    store = TransactionsStore();

    await store.loadTransactions();
  });

  tearDown(() {
    store.dispose();
  });

  FinancialTransaction createTransaction({
    required String id,
    required TransactionType type,
    required double amount,
    TransactionStatus status = TransactionStatus.completed,
    String accountId = 'account-1',
  }) {
    return FinancialTransaction(
      id: id,
      description: 'Movimentação de teste',
      amount: amount,
      type: type,
      category: type == TransactionType.income
          ? TransactionCategory.salary
          : TransactionCategory.bills,
      accountId: accountId,
      transactionDate: DateTime(2026, 11, 1),
      dueDate: DateTime(2026, 11, 5),
      status: status,
    );
  }

  group('TransactionsStore', () {
    test('deve cadastrar uma receita', () async {
      final transaction = createTransaction(
        id: '1',
        type: TransactionType.income,
        amount: 3000,
      );

      await store.saveTransaction(transaction);

      expect(store.transactions.length, 1);
      expect(store.totalIncome, 3000);
    });

    test('deve cadastrar uma despesa', () async {
      final transaction = createTransaction(
        id: '2',
        type: TransactionType.expense,
        amount: 500,
      );

      await store.saveTransaction(transaction);

      expect(store.transactions.length, 1);
      expect(store.totalExpenses, 500);
    });

    test('deve calcular corretamente o saldo da conta', () async {
      await store.saveTransaction(
        createTransaction(
          id: '1',
          type: TransactionType.income,
          amount: 4000,
        ),
      );

      await store.saveTransaction(
        createTransaction(
          id: '2',
          type: TransactionType.expense,
          amount: 1500,
        ),
      );

      final balance = store.balanceForAccount(
        accountId: 'account-1',
        initialBalance: 2000,
      );

      expect(balance, 4500);
    });

    test('movimentação pendente não deve alterar o saldo', () async {
      await store.saveTransaction(
        createTransaction(
          id: '1',
          type: TransactionType.expense,
          amount: 300,
          status: TransactionStatus.pending,
        ),
      );

      final balance = store.balanceForAccount(
        accountId: 'account-1',
        initialBalance: 1000,
      );

      expect(balance, 1000);
      expect(store.pendingAmount, 300);
    });

    test('movimentação cancelada não deve alterar o saldo', () async {
      await store.saveTransaction(
        createTransaction(
          id: '1',
          type: TransactionType.expense,
          amount: 500,
          status: TransactionStatus.cancelled,
        ),
      );

      final balance = store.balanceForAccount(
        accountId: 'account-1',
        initialBalance: 1000,
      );

      expect(balance, 1000);
      expect(store.totalExpenses, 0);
    });

    test('deve editar uma movimentação existente', () async {
      final transaction = createTransaction(
        id: '1',
        type: TransactionType.income,
        amount: 1000,
      );

      await store.saveTransaction(transaction);

      await store.saveTransaction(
        transaction.copyWith(amount: 2500),
      );

      expect(store.transactions.length, 1);
      expect(store.totalIncome, 2500);
    });

    test('deve excluir uma movimentação', () async {
      await store.saveTransaction(
        createTransaction(
          id: '1',
          type: TransactionType.income,
          amount: 1000,
        ),
      );

      await store.deleteTransaction('1');

      expect(store.transactions, isEmpty);
      expect(store.totalIncome, 0);
    });

    test('deve persistir movimentações localmente', () async {
      await store.saveTransaction(
        createTransaction(
          id: '1',
          type: TransactionType.income,
          amount: 3500,
        ),
      );

      final newStore = TransactionsStore();

      await newStore.loadTransactions();

      expect(newStore.transactions.length, 1);
      expect(newStore.totalIncome, 3500);

      newStore.dispose();
    });

    test('não deve aceitar valores iguais ou inferiores a zero', () async {
      final transaction = createTransaction(
        id: '1',
        type: TransactionType.expense,
        amount: 0,
      );

      await expectLater(
        store.saveTransaction(transaction),
        throwsArgumentError,
      );

      expect(store.transactions, isEmpty);
    });
  });
}
