
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/core/network/api_client.dart';
import 'package:finplan/core/security/secure_storage_service.dart';

class FakeSecureStorage extends SecureStorageService {
  String? accessToken = 'fake-token';
  String? refreshToken;

  @override
  Future<String?> readToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> deleteTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    required this.statusCode,
    this.waitForTwoRequests = false,
  });

  final int statusCode;
  final bool waitForTwoRequests;

  int requestCount = 0;

  final Completer<void> _twoRequestsReceived = Completer<void>();

  Future<void> get twoRequestsReceived => _twoRequestsReceived.future;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;

    if (waitForTwoRequests && requestCount >= 2) {
      if (!_twoRequestsReceived.isCompleted) {
        _twoRequestsReceived.complete();
      }
    }

    if (waitForTwoRequests) {
      await _twoRequestsReceived.future;
    }

    return ResponseBody.fromString(
      '{"message": "Resposta simulada"}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class RefreshTestAdapter implements HttpClientAdapter {
  int refreshRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    refreshRequests++;

    return ResponseBody.fromString(
      '''
      {
        "accessToken": "new-access-token",
        "refreshToken": "new-refresh-token"
      }
      ''',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class BlockingRefreshAdapter implements HttpClientAdapter {
  int refreshRequests = 0;

  final Completer<void> refreshStarted = Completer<void>();
  final Completer<void> allowRefresh = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    refreshRequests++;

    if (!refreshStarted.isCompleted) {
      refreshStarted.complete();
    }

    await allowRefresh.future;

    return ResponseBody.fromString(
      '''
      {
        "accessToken": "new-access-token",
        "refreshToken": "new-refresh-token"
      }
      ''',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class ProtectedRouteAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;

    final authorization = options.headers['Authorization'];

    if (authorization == 'Bearer new-access-token') {
      return ResponseBody.fromString(
        '{"message": "Acesso autorizado"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      '{"message": "Token expirado"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class DelayedProtectedRouteAdapter implements HttpClientAdapter {
  int requestCount = 0;

  final Completer<void> accountsRequestStarted = Completer<void>();
  final Completer<void> releaseAccountsRequest = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;

    final authorization = options.headers['Authorization'];
    final isNewToken = authorization == 'Bearer new-access-token';

    if (options.path.endsWith('/accounts') && !isNewToken) {
      if (!accountsRequestStarted.isCompleted) {
        accountsRequestStarted.complete();
      }

      await releaseAccountsRequest.future;
    }

    if (isNewToken) {
      return ResponseBody.fromString(
        '{"message": "Acesso autorizado"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      '{"message": "Token expirado"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient - tratamento HTTP 401', () {
    late FakeHttpClientAdapter adapter;
    late Dio dio;

    tearDown(() {
      ApiClient.onUnauthorized = null;
    });

    void configureClient({
      required int statusCode,
      bool waitForTwoRequests = false,
    }) {
      adapter = FakeHttpClientAdapter(
        statusCode: statusCode,
        waitForTwoRequests: waitForTwoRequests,
      );

      dio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      dio.httpClientAdapter = adapter;

      ApiClient(
        secureStorage: FakeSecureStorage(),
        dio: dio,
      );
    }

    test('401 em rota protegida aciona logout global', () async {
      configureClient(statusCode: 401);

      var logoutCalls = 0;

      ApiClient.onUnauthorized = () async {
        logoutCalls++;
      };

      await expectLater(
        dio.get('/accounts'),
        throwsA(isA<DioException>()),
      );

      expect(logoutCalls, 1);
    });

    test('401 no login não aciona logout global', () async {
      configureClient(statusCode: 401);

      var logoutCalls = 0;

      ApiClient.onUnauthorized = () async {
        logoutCalls++;
      };

      await expectLater(
        dio.post('/auth/login'),
        throwsA(isA<DioException>()),
      );

      expect(logoutCalls, 0);
    });

    test('401 no cadastro não aciona logout global', () async {
      configureClient(statusCode: 401);

      var logoutCalls = 0;

      ApiClient.onUnauthorized = () async {
        logoutCalls++;
      };

      await expectLater(
        dio.post('/auth/register'),
        throwsA(isA<DioException>()),
      );

      expect(logoutCalls, 0);
    });

    test('401 simultâneos acionam apenas um logout', () async {
      configureClient(
        statusCode: 401,
        waitForTwoRequests: true,
      );

      var logoutCalls = 0;

      final logoutCompleter = Completer<void>();

      ApiClient.onUnauthorized = () async {
        logoutCalls++;
        await logoutCompleter.future;
      };

      final firstRequest = expectLater(
        dio.get('/accounts'),
        throwsA(isA<DioException>()),
      );

      final secondRequest = expectLater(
        dio.get('/transactions'),
        throwsA(isA<DioException>()),
      );

      await adapter.twoRequestsReceived;

      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      expect(logoutCalls, 1);

      logoutCompleter.complete();

      await Future.wait([
        firstRequest,
        secondRequest,
      ]);

      expect(logoutCalls, 1);
    });

    test('HTTP 500 não aciona logout global', () async {
      configureClient(statusCode: 500);

      var logoutCalls = 0;

      ApiClient.onUnauthorized = () async {
        logoutCalls++;
      };

      await expectLater(
        dio.get('/accounts'),
        throwsA(isA<DioException>()),
      );

      expect(logoutCalls, 0);
    });
  });

  group('ApiClient - renovação de tokens', () {
    late FakeSecureStorage storage;
    late Dio dio;
    late RefreshTestAdapter refreshAdapter;
    late ProtectedRouteAdapter protectedAdapter;

    setUp(() {
      storage = FakeSecureStorage()
        ..accessToken = 'old-access-token'
        ..refreshToken = 'old-refresh-token';

      refreshAdapter = RefreshTestAdapter();
      protectedAdapter = ProtectedRouteAdapter();

      dio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      dio.httpClientAdapter = protectedAdapter;

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      refreshDio.httpClientAdapter = refreshAdapter;

      ApiClient(
        secureStorage: storage,
        dio: dio,
        refreshDio: refreshDio,
      );
    });

    tearDown(() {
      ApiClient.onUnauthorized = null;
    });

    test('renova o access token automaticamente após HTTP 401', () async {
      final response = await dio.get('/accounts');

      expect(response.statusCode, 200);
      expect(refreshAdapter.refreshRequests, 1);
      expect(protectedAdapter.requestCount, 2);
      expect(storage.accessToken, 'new-access-token');
      expect(storage.refreshToken, 'new-refresh-token');
    });

    test('utiliza os novos tokens nas próximas requisições', () async {
      await dio.get('/accounts');

      final response = await dio.get('/transactions');

      expect(response.statusCode, 200);
      expect(refreshAdapter.refreshRequests, 1);
      expect(protectedAdapter.requestCount, 3);
      expect(storage.accessToken, 'new-access-token');
    });

    test('duas requisições simultâneas compartilham uma renovação', () async {
      final blockingRefreshAdapter = BlockingRefreshAdapter();

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      refreshDio.httpClientAdapter = blockingRefreshAdapter;

      final concurrentProtectedAdapter = ProtectedRouteAdapter();

      final concurrentDio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      concurrentDio.httpClientAdapter = concurrentProtectedAdapter;

      ApiClient(
        secureStorage: storage,
        dio: concurrentDio,
        refreshDio: refreshDio,
      );

      final firstRequest = concurrentDio.get('/accounts');
      final secondRequest = concurrentDio.get('/transactions');

      await blockingRefreshAdapter.refreshStarted.future;

      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      expect(blockingRefreshAdapter.refreshRequests, 1);

      blockingRefreshAdapter.allowRefresh.complete();

      final responses = await Future.wait([
        firstRequest,
        secondRequest,
      ]);

      expect(responses.length, 2);
      expect(responses.every((response) => response.statusCode == 200), true);
      expect(blockingRefreshAdapter.refreshRequests, 1);
      expect(storage.accessToken, 'new-access-token');
      expect(storage.refreshToken, 'new-refresh-token');
    });

    test('requisição atrasada reutiliza o token já renovado', () async {
      final delayedAdapter = DelayedProtectedRouteAdapter();

      final delayedDio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      delayedDio.httpClientAdapter = delayedAdapter;

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: 'https://finplan.test',
        ),
      );

      final delayedRefreshAdapter = RefreshTestAdapter();
      refreshDio.httpClientAdapter = delayedRefreshAdapter;

      ApiClient(
        secureStorage: storage,
        dio: delayedDio,
        refreshDio: refreshDio,
      );

      // A primeira requisição fica aguardando a resposta antiga.
      final accountsRequest = delayedDio.get('/accounts');

      await delayedAdapter.accountsRequestStarted.future;

      // A segunda requisição recebe 401 e renova os tokens.
      final transactionsResponse = await delayedDio.get('/transactions');

      expect(transactionsResponse.statusCode, 200);
      expect(storage.accessToken, 'new-access-token');
      expect(delayedRefreshAdapter.refreshRequests, 1);

      // Agora liberamos a resposta 401 atrasada.
      delayedAdapter.releaseAccountsRequest.complete();

      final accountsResponse = await accountsRequest;

      expect(accountsResponse.statusCode, 200);
      expect(delayedRefreshAdapter.refreshRequests, 1);
      expect(delayedAdapter.requestCount, 4);
      expect(storage.refreshToken, 'new-refresh-token');
    });
  });
}
