
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finplan/core/network/api_client.dart';
import 'package:finplan/features/accounts/application/accounts_store.dart';
import 'package:finplan/features/accounts/domain/entities/bank_account.dart';

class FakeAccountsApi extends Interceptor {
  final List<Map<String, dynamic>> accounts = [];

  int _nextId = 1;
  int getRequestCount = 0;

  bool failNextGet = false;
  bool failNextPost = false;
  bool failNextPatch = false;
  bool failNextDelete = false;

  Completer<void>? getRequestStarted;
  Completer<void>? getRequestGate;

  Map<String, dynamic> _accountData(
    RequestOptions options,
  ) {
    return Map<String, dynamic>.from(options.data as Map);
  }

  void _reject(
    RequestOptions options,
    RequestInterceptorHandler handler,
    String message,
  ) {
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 409,
          data: {'message': message},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }

  void _resolveGet(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
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
        data: List<Map<String, dynamic>>.from(accounts),
      ),
    );
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final method = options.method;
    final path = options.path;

    if (method == 'GET' && path == '/accounts') {
      getRequestCount++;

      final gate = getRequestGate;

      if (gate != null && !gate.isCompleted) {
        final started = getRequestStarted;

        if (started != null && !started.isCompleted) {
          started.complete();
        }

        gate.future.then((_) {
          _resolveGet(options, handler);
        });

        return;
      }

      _resolveGet(options, handler);
      return;
    }

    if (method == 'POST' && path == '/accounts') {
      if (failNextPost) {
        failNextPost = false;
        _reject(options, handler, 'Não foi possível cadastrar a conta.');
        return;
      }

      final data = _accountData(options);

      final savedAccount = {
        ...data,
        'id': 'server-${_nextId++}',
      };

      accounts.insert(0, savedAccount);

      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: savedAccount,
        ),
      );

      return;
    }

    final id = path.split('/').last;

    final index = accounts.indexWhere(
      (account) => account['id'] == id,
    );

    if (method == 'PATCH' && index >= 0) {
      if (failNextPatch) {
        failNextPatch = false;
        _reject(options, handler, 'Não foi possível editar a conta.');
        return;
      }

      final data = _accountData(options);

      accounts[index] = {
        ...accounts[index],
        ...data,
      };

      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: accounts[index],
        ),
      );

      return;
    }

    if (method == 'DELETE' && index >= 0) {
      if (failNextDelete) {
        failNextDelete = false;
        _reject(options, handler, 'Não foi possível excluir a conta.');
        return;
      }

      accounts.removeAt(index);

      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'message': 'Conta excluída.'},
        ),
      );

      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          data: {'message': 'Conta não encontrada.'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

void main() {
  late AccountsStore store;
  late FakeAccountsApi fakeApi;
  late Dio dio;

  setUp(() async {
    fakeApi = FakeAccountsApi();

    dio = Dio(
      BaseOptions(baseUrl: 'http://localhost'),
    );

    dio.interceptors.add(fakeApi);

    final apiClient = ApiClient(
      dio: dio,
      enableAuthInterceptor: false,
    );

    store = AccountsStore(apiClient: apiClient);

    await store.loadAccounts();
  });

  tearDown(() {
    store.dispose();
    dio.close();
  });

  BankAccount createAccount({
    required String id,
    String bankName = 'Banco de Teste',
    String nickname = 'Minha conta',
    BankAccountType type = BankAccountType.checking,
    double initialBalance = 1000,
  }) {
    return BankAccount(
      id: id,
      bankName: bankName,
      nickname: nickname,
      type: type,
      initialBalance: initialBalance,
    );
  }

  group('AccountsStore', () {
    test('deve cadastrar uma conta', () async {
      final account = createAccount(
        id: '1',
        initialBalance: 2500,
      );

      final savedAccount = await store.saveAccount(account);

      expect(store.accounts.length, 1);
      expect(savedAccount.id, 'server-1');
      expect(savedAccount.initialBalance, 2500);
      expect(store.accounts.first.nickname, 'Minha conta');
    });

    test('deve editar uma conta existente', () async {
      final savedAccount = await store.saveAccount(
        createAccount(
          id: '1',
          initialBalance: 1000,
        ),
      );

      await store.saveAccount(
        savedAccount.copyWith(
          nickname: 'Conta principal',
          initialBalance: 3500,
        ),
      );

      expect(store.accounts.length, 1);
      expect(store.accounts.first.nickname, 'Conta principal');
      expect(store.accounts.first.initialBalance, 3500);
    });

    test('deve excluir uma conta', () async {
      final savedAccount = await store.saveAccount(
        createAccount(id: '1'),
      );

      await store.deleteAccount(savedAccount.id);

      expect(store.accounts, isEmpty);
    });

    test('deve carregar contas retornadas pela API', () async {
      fakeApi.accounts.add({
        'id': 'account-1',
        'bankName': 'Banco A',
        'nickname': 'Conta principal',
        'type': 'checking',
        'initialBalance': 2000,
      });

      final newStore = AccountsStore(
        apiClient: ApiClient(
          dio: dio,
          enableAuthInterceptor: false,
        ),
      );

      await newStore.loadAccounts();

      expect(newStore.accounts.length, 1);
      expect(newStore.accounts.first.id, 'account-1');
      expect(newStore.accounts.first.initialBalance, 2000);
      expect(newStore.isLoaded, isTrue);

      newStore.dispose();
    });

    test('deve converter saldo numérico da API para double', () async {
      fakeApi.accounts.add({
        'id': 'account-1',
        'bankName': 'Banco A',
        'nickname': 'Conta principal',
        'type': 'checking',
        'initialBalance': 2500,
      });

      final newStore = AccountsStore(
        apiClient: ApiClient(
          dio: dio,
          enableAuthInterceptor: false,
        ),
      );

      await newStore.loadAccounts();

      expect(
        newStore.accounts.first.initialBalance,
        isA<double>(),
      );

      newStore.dispose();
    });

    test('deve permitir nova tentativa após falha no carregamento', () async {
      final newStore = AccountsStore(
        apiClient: ApiClient(
          dio: dio,
          enableAuthInterceptor: false,
        ),
      );

      final initialRequestCount = fakeApi.getRequestCount;

      fakeApi.failNextGet = true;

      await newStore.loadAccounts();

      expect(newStore.isLoaded, isFalse);
      expect(newStore.errorMessage, isNotNull);
      expect(fakeApi.getRequestCount, initialRequestCount + 1);

      await newStore.loadAccounts();

      expect(newStore.isLoaded, isTrue);
      expect(newStore.errorMessage, isNull);
      expect(fakeApi.getRequestCount, initialRequestCount + 2);

      newStore.dispose();
    });

    test('deve preservar contas existentes após falha no carregamento', () async {
      await store.saveAccount(
        createAccount(id: '1'),
      );

      final previousAccounts = store.accounts;

      fakeApi.failNextGet = true;

      await store.loadAccounts(force: true);

      expect(store.accounts, previousAccounts);
      expect(store.errorMessage, isNotNull);
    });

    test('deve informar erro ao falhar no cadastro', () async {
      fakeApi.failNextPost = true;

      await expectLater(
        store.saveAccount(createAccount(id: '1')),
        throwsA(isA<DioException>()),
      );

      expect(store.accounts, isEmpty);
      expect(store.errorMessage, 'Não foi possível cadastrar a conta.');
    });

    test('deve informar erro ao falhar na edição', () async {
      final savedAccount = await store.saveAccount(
        createAccount(id: '1'),
      );

      fakeApi.failNextPatch = true;

      await expectLater(
        store.saveAccount(
          savedAccount.copyWith(nickname: 'Novo nome'),
        ),
        throwsA(isA<DioException>()),
      );

      expect(store.accounts.first.nickname, 'Minha conta');
      expect(store.errorMessage, 'Não foi possível editar a conta.');
    });

    test('deve informar erro ao falhar na exclusão', () async {
      final savedAccount = await store.saveAccount(
        createAccount(id: '1'),
      );

      fakeApi.failNextDelete = true;

      await expectLater(
        store.deleteAccount(savedAccount.id),
        throwsA(isA<DioException>()),
      );

      expect(store.accounts.length, 1);
      expect(store.errorMessage, 'Não foi possível excluir a conta.');
    });

    test(
      'deve executar atualização forçada solicitada durante carregamento',
      () async {
        final newStore = AccountsStore(
          apiClient: ApiClient(
            dio: dio,
            enableAuthInterceptor: false,
          ),
        );

        final initialRequestCount = fakeApi.getRequestCount;

        fakeApi.getRequestStarted = Completer<void>();
        fakeApi.getRequestGate = Completer<void>();

        final initialLoad = newStore.loadAccounts();

        await fakeApi.getRequestStarted!.future;

        final firstForcedLoad = newStore.loadAccounts(force: true);
        final secondForcedLoad = newStore.loadAccounts(force: true);

        fakeApi.getRequestGate!.complete();

        await Future.wait([
          initialLoad,
          firstForcedLoad,
          secondForcedLoad,
        ]);

        expect(fakeApi.getRequestCount, initialRequestCount + 2);
        expect(newStore.isLoaded, isTrue);

        newStore.dispose();
      },
    );
  });
}
