import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finplan/core/network/api_client.dart';
import 'package:finplan/features/transactions/application/transactions_store.dart';
import 'package:finplan/features/transactions/domain/entities/transaction.dart';

class FakeTransactionsApi extends Interceptor {
  final List<Map<String, dynamic>> transactions = [];

  int _nextId = 1;
  int getRequestCount = 0;

  bool failNextGet = false;

  Completer<void>? getRequestStarted;
  Completer<void>? getRequestGate;

  void _resolveGet(RequestOptions options, RequestInterceptorHandler handler) {
    if (failNextGet) {
      failNextGet = false;

      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Falha de conexão simulada.',
        ),
      );
      return;
    }

    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: List<Map<String, dynamic>>.from(transactions),
      ),
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method;
    final path = options.path;
    final requestOptions = options;

    if (method == 'GET' && path == '/transactions') {
      getRequestCount++;

      final gate = getRequestGate;

      if (gate != null && !gate.isCompleted) {
        final started = getRequestStarted;

        if (started != null && !started.isCompleted) {
          started.complete();
        }

        gate.future.then((_) {
          _resolveGet(requestOptions, handler);
        });

        return;
      }

      _resolveGet(requestOptions, handler);
      return;
    }

    if (method == 'POST' && path == '/transactions') {
      final data = Map<String, dynamic>.from(options.data as Map);

      final savedTransaction = {...data, 'id': 'server-${_nextId++}'};

      transactions.insert(0, savedTransaction);

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 201,
          data: savedTransaction,
        ),
      );
      return;
    }

    final id = path.split('/').last;
    final index = transactions.indexWhere(
      (transaction) => transaction['id'] == id,
    );

    if (method == 'PATCH' && index >= 0) {
      final data = Map<String, dynamic>.from(options.data as Map);

      transactions[index] = {...transactions[index], ...data};

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: transactions[index],
        ),
      );
      return;
    }

    if (method == 'DELETE' && index >= 0) {
      transactions.removeAt(index);

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'message': 'Movimentação excluída.'},
        ),
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {'message': 'Movimentação não encontrada.'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

void main() {
  late TransactionsStore store;
  late FakeTransactionsApi fakeApi;
  late Dio dio;

  setUp(() async {
    fakeApi = FakeTransactionsApi();

    dio = Dio(BaseOptions(baseUrl: 'http://localhost'));

    dio.interceptors.add(fakeApi);

    final apiClient = ApiClient(dio: dio, enableAuthInterceptor: false);

    store = TransactionsStore(apiClient: apiClient);

    await store.loadTransactions();
  });

  tearDown(() {
    store.dispose();
    dio.close();
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
        createTransaction(id: '1', type: TransactionType.income, amount: 4000),
      );

      await store.saveTransaction(
        createTransaction(id: '2', type: TransactionType.expense, amount: 1500),
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

      final savedTransaction = await store.saveTransaction(transaction);

      await store.saveTransaction(savedTransaction.copyWith(amount: 2500));

      expect(store.transactions.length, 1);
      expect(store.totalIncome, 2500);
    });

    test('deve excluir uma movimentação', () async {
      final savedTransaction = await store.saveTransaction(
        createTransaction(id: '1', type: TransactionType.income, amount: 1000),
      );

      await store.deleteTransaction(savedTransaction.id);

      expect(store.transactions, isEmpty);
      expect(store.totalIncome, 0);
    });

    test('deve carregar movimentações retornadas pela API', () async {
      await store.saveTransaction(
        createTransaction(id: '1', type: TransactionType.income, amount: 3500),
      );

      final newStore = TransactionsStore(
        apiClient: ApiClient(dio: dio, enableAuthInterceptor: false),
      );

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

    test('deve permitir nova tentativa após falha no carregamento', () async {
      final newStore = TransactionsStore(
        apiClient: ApiClient(dio: dio, enableAuthInterceptor: false),
      );

      final initialRequestCount = fakeApi.getRequestCount;
      fakeApi.failNextGet = true;

      await newStore.loadTransactions();

      expect(newStore.isLoaded, isFalse);
      expect(newStore.isLoading, isFalse);
      expect(newStore.errorMessage, isNotNull);
      expect(fakeApi.getRequestCount, initialRequestCount + 1);

      await newStore.loadTransactions();

      expect(newStore.isLoaded, isTrue);
      expect(newStore.errorMessage, isNull);
      expect(fakeApi.getRequestCount, initialRequestCount + 2);

      newStore.dispose();
    });

    test(
      'deve executar atualização forçada solicitada durante carregamento',
      () async {
        final newStore = TransactionsStore(
          apiClient: ApiClient(dio: dio, enableAuthInterceptor: false),
        );

        final initialRequestCount = fakeApi.getRequestCount;

        fakeApi.getRequestStarted = Completer<void>();
        fakeApi.getRequestGate = Completer<void>();

        final initialLoad = newStore.loadTransactions();

        await fakeApi.getRequestStarted!.future;

        final firstForcedLoad = newStore.loadTransactions(force: true);
        final secondForcedLoad = newStore.loadTransactions(force: true);

        fakeApi.getRequestGate!.complete();

        await Future.wait([initialLoad, firstForcedLoad, secondForcedLoad]);

        expect(fakeApi.getRequestCount, initialRequestCount + 2);
        expect(newStore.isLoaded, isTrue);
        expect(newStore.isLoading, isFalse);

        newStore.dispose();
      },
    );
  });
}
