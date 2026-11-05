
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/core/network/api_client.dart';
import 'package:finplan/core/security/secure_storage_service.dart';

class FakeSecureStorage extends SecureStorageService {
  @override
  Future<String?> readToken() async {
    return 'fake-token';
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

      await adapter._twoRequestsReceived.future;

      // Dá oportunidade para os dois erros chegarem ao interceptor.
      await Future<void>.delayed(const Duration(milliseconds: 50));

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
}
