
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finplan/core/network/api_client.dart';
import 'package:finplan/features/planning/application/planning_store.dart';
import 'package:finplan/features/planning/domain/entities/payable_bill.dart';

class FakePlanningApi extends Interceptor {
  final List<Map<String, dynamic>> bills = [];

  int _nextId = 1;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final method = options.method;
    final path = options.path;
    final requestOptions = options;

    if (method == 'GET' && path == '/payable-bills') {
      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: List<Map<String, dynamic>>.from(bills),
        ),
      );
      return;
    }

    if (method == 'POST' && path == '/payable-bills') {
      final data = Map<String, dynamic>.from(options.data as Map);

      final savedBill = {
        ...data,
        'id': 'server-${_nextId++}',
        'status': 'pending',
        'paidAt': null,
        'linkedTransactionId': null,
      };

      bills.insert(0, savedBill);

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 201,
          data: savedBill,
        ),
      );
      return;
    }

    final parts = path.split('/');
    final id = parts.length > 2 ? parts[2] : '';
    final index = bills.indexWhere(
      (bill) => bill['id'] == id,
    );

    if (method == 'PATCH' &&
        parts.length == 3 &&
        index >= 0) {
      final data = Map<String, dynamic>.from(options.data as Map);

      bills[index] = {
        ...bills[index],
        ...data,
      };

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: bills[index],
        ),
      );
      return;
    }

    if (method == 'DELETE' &&
        parts.length == 3 &&
        index >= 0) {
      bills.removeAt(index);

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'message': 'Conta excluída.'},
        ),
      );
      return;
    }

    if (method == 'POST' &&
        parts.length == 4 &&
        parts[3] == 'cancel' &&
        index >= 0) {
      if (bills[index]['status'] != 'pending') {
        _reject(handler, requestOptions, 409, 'Conta não está pendente.');
        return;
      }

      bills[index] = {
        ...bills[index],
        'status': 'cancelled',
        'linkedPendingTransactionId': null,
      };

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: bills[index],
        ),
      );
      return;
    }

    if (method == 'POST' &&
        parts.length == 4 &&
        parts[3] == 'pay' &&
        index >= 0) {
      if (bills[index]['status'] != 'pending') {
        _reject(handler, requestOptions, 409, 'Conta não está pendente.');
        return;
      }

      final data = Map<String, dynamic>.from(options.data as Map);

      bills[index] = {
        ...bills[index],
        'status': 'paid',
        'paidAt': data['paidAt'],
        'accountId': data['accountId'],
        'linkedTransactionId': 'payment-${bills[index]['id']}',
        'linkedPendingTransactionId': null,
      };

      handler.resolve(
        Response(
          requestOptions: requestOptions,
          statusCode: 201,
          data: {
            'message': 'Conta paga com sucesso.',
            'bill': bills[index],
            'payment': {
              'transactionId': bills[index]['linkedTransactionId'],
            },
          },
        ),
      );
      return;
    }

    _reject(handler, requestOptions, 404, 'Conta não encontrada.');
  }

  void _reject(
    RequestInterceptorHandler handler,
    RequestOptions requestOptions,
    int statusCode,
    String message,
  ) {
    handler.reject(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: statusCode,
          data: {'message': message},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

void main() {
  late PlanningStore store;
  late FakePlanningApi fakeApi;
  late Dio dio;

  setUp(() async {
    fakeApi = FakePlanningApi();

    dio = Dio(
      BaseOptions(baseUrl: 'http://localhost'),
    );

    dio.interceptors.add(fakeApi);

    store = PlanningStore(
      apiClient: ApiClient(
        dio: dio,
        enableAuthInterceptor: false,
      ),
    );

    await store.loadBills();
  });

  tearDown(() {
    store.dispose();
    dio.close();
  });

  PayableBill createBill({
    String id = 'local-1',
    String description = 'Conta de luz',
    double amount = 150,
    String? linkedPendingTransactionId,
  }) {
    return PayableBill(
      id: id,
      description: description,
      amount: amount,
      category: BillCategory.utilities,
      dueDate: DateTime(2026, 12, 10),
      linkedPendingTransactionId: linkedPendingTransactionId,
    );
  }

  group('PlanningStore', () {
    test('deve carregar contas retornadas pela API', () async {
      await store.saveBill(createBill(amount: 350));

      final newStore = PlanningStore(
        apiClient: ApiClient(
          dio: dio,
          enableAuthInterceptor: false,
        ),
      );

      await newStore.loadBills();

      expect(newStore.bills.length, 1);
      expect(newStore.totalPending, 350);

      newStore.dispose();
    });

    test('deve cadastrar uma conta e utilizar o ID do servidor', () async {
      final savedBill = await store.saveBill(createBill());

      expect(savedBill.id, 'server-1');
      expect(store.bills.length, 1);
      expect(store.totalPending, 150);
    });

    test('deve editar uma conta existente', () async {
      final savedBill = await store.saveBill(createBill());

      await store.saveBill(
        createBill(
          id: savedBill.id,
          description: 'Conta atualizada',
          amount: 200,
        ),
      );

      expect(store.bills.length, 1);
      expect(store.bills.first.description, 'Conta atualizada');
      expect(store.totalPending, 200);
    });

    test('não deve permitir vincular a mesma transação a duas contas',
        () async {
      await store.saveBill(
        createBill(linkedPendingTransactionId: 'transaction-1'),
      );

      await expectLater(
        store.saveBill(
          createBill(
            id: 'local-2',
            linkedPendingTransactionId: 'transaction-1',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(store.bills.length, 1);
    });

    test('deve permitir editar uma conta mantendo seu próprio vínculo',
        () async {
      final savedBill = await store.saveBill(
        createBill(linkedPendingTransactionId: 'transaction-1'),
      );

      await store.saveBill(
        createBill(
          id: savedBill.id,
          description: 'Conta atualizada',
          linkedPendingTransactionId: 'transaction-1',
        ),
      );

      expect(store.bills.length, 1);
      expect(
        store.bills.first.linkedPendingTransactionId,
        'transaction-1',
      );
    });

    test('deve cancelar uma conta e remover seu vínculo pendente',
        () async {
      final savedBill = await store.saveBill(
        createBill(linkedPendingTransactionId: 'transaction-1'),
      );

      final cancelledBill = await store.cancelBill(savedBill.id);

      expect(cancelledBill.status, BillStatus.cancelled);
      expect(cancelledBill.linkedPendingTransactionId, isNull);
      expect(store.bills.first.status, BillStatus.cancelled);
    });

    test('deve registrar o pagamento pelo endpoint específico', () async {
      final savedBill = await store.saveBill(createBill());

      final paidBill = await store.payBill(
        savedBill.id,
        accountId: 'account-1',
        paidAt: DateTime(2026, 12, 5),
        category: BillCategory.utilities,
      );

      expect(paidBill.status, BillStatus.paid);
      expect(paidBill.accountId, 'account-1');
      expect(paidBill.linkedTransactionId, isNotNull);
      expect(store.totalPaid, 150);
      expect(store.totalPending, 0);
    });

    test('deve excluir uma conta', () async {
      final savedBill = await store.saveBill(createBill());

      await store.deleteBill(savedBill.id);

      expect(store.bills, isEmpty);
    });

    test('não deve aceitar valores iguais ou inferiores a zero', () async {
      await expectLater(
        store.saveBill(createBill(amount: 0)),
        throwsArgumentError,
      );

      expect(store.bills, isEmpty);
    });
  });
}
