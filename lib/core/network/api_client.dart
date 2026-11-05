
import 'package:dio/dio.dart';

import '../security/secure_storage_service.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({
    SecureStorageService? secureStorage,
    Dio? dio,
    bool enableAuthInterceptor = true,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: ApiConfig.sendTimeout,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    if (enableAuthInterceptor) {
      this.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (_isPublicRoute(options.path)) {
              options.headers.remove('Authorization');
              handler.next(options);
              return;
            }

            try {
              final token = await _secureStorage.readToken();

              if (token != null && token.trim().isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              handler.next(options);
            } catch (error) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: error,
                  message: 'Não foi possível acessar o token de autenticação.',
                ),
              );
            }
          },
          onError: (error, handler) async {
            final isUnauthorized =
                error.response?.statusCode == 401 &&
                !_isPublicRoute(error.requestOptions.path);

            if (isUnauthorized) {
              final callback = onUnauthorized;

              if (callback != null) {
                try {
                  await _handleUnauthorized(callback);
                } catch (_) {
                  // A falha no encerramento da sessão não deve
                  // impedir que o erro original seja propagado.
                }
              }
            }

            handler.next(error);
          },
        ),
      );
    }
  }

  static Future<void> Function()? onUnauthorized;

  static Future<void>? _unauthorizedFuture;

  static bool _isPublicRoute(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return normalizedPath == '/auth/login' ||
        normalizedPath == '/auth/register';
  }

  static Future<void> _handleUnauthorized(
    Future<void> Function() callback,
  ) async {
    if (_unauthorizedFuture != null) {
      await _unauthorizedFuture;
      return;
    }

    final future = Future<void>.sync(callback);
    _unauthorizedFuture = future;

    try {
      await future;
    } finally {
      if (identical(_unauthorizedFuture, future)) {
        _unauthorizedFuture = null;
      }
    }
  }

  final SecureStorageService _secureStorage;
  final Dio dio;
}
