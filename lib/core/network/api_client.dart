
import 'package:dio/dio.dart';

import '../security/secure_storage_service.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({
    SecureStorageService? secureStorage,
    Dio? dio,
    Dio? refreshDio,
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
            ),
        _refreshDio = refreshDio ??
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
                  message:
                      'Não foi possível acessar o token de autenticação.',
                ),
              );
            }
          },
          onError: (error, handler) async {
            final isUnauthorized =
                error.response?.statusCode == 401 &&
                !_isPublicRoute(error.requestOptions.path);

            if (!isUnauthorized) {
              handler.next(error);
              return;
            }

            final alreadyRetried =
                error.requestOptions.extra['retriedAfterRefresh'] == true;

            if (alreadyRetried) {
              await _notifyUnauthorized();
              handler.next(error);
              return;
            }

            String? accessToken;

            try {
              final currentAccessToken =
                  await _secureStorage.readToken();

              final failedAccessToken = _extractAccessToken(
                error.requestOptions.headers['Authorization'],
              );

              if (currentAccessToken != null &&
                  currentAccessToken.trim().isNotEmpty &&
                  failedAccessToken != null &&
                  failedAccessToken != currentAccessToken) {
                // Outra requisição já renovou o token.
                // Reutilizamos o token atual sem rotacionar novamente.
                accessToken = currentAccessToken;
              }
            } catch (_) {
              accessToken = null;
            }

            accessToken ??= await _refreshAccessToken(
              _secureStorage,
              _refreshDio,
            );

            if (accessToken == null) {
              await _notifyUnauthorized();
              handler.next(error);
              return;
            }

            try {
              final options = error.requestOptions;

              options.headers['Authorization'] =
                  'Bearer $accessToken';

              options.extra['retriedAfterRefresh'] = true;

              final response = await this.dio.fetch<dynamic>(options);

              handler.resolve(response);
            } catch (retryError) {
              // A nova resposta 401 será tratada pelo próprio
              // interceptor da requisição repetida.
              handler.next(
                retryError is DioException ? retryError : error,
              );
            }
          },
        ),
      );
    }
  }

  static Future<void> Function()? onUnauthorized;

  static Future<void>? _unauthorizedFuture;
  static Future<String?>? _refreshFuture;

  static bool _isPublicRoute(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return normalizedPath == '/auth/login' ||
        normalizedPath == '/auth/register' ||
        normalizedPath == '/auth/refresh' ||
        normalizedPath == '/auth/logout';
  }

  static String? _extractAccessToken(dynamic authorization) {
    if (authorization is! String) {
      return null;
    }

    const prefix = 'Bearer ';

    if (!authorization.startsWith(prefix)) {
      return null;
    }

    return authorization.substring(prefix.length);
  }

  static Future<String?> _refreshAccessToken(
    SecureStorageService secureStorage,
    Dio refreshDio,
  ) async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }

    final future = _performTokenRefresh(
      secureStorage,
      refreshDio,
    );

    _refreshFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  static Future<String?> _performTokenRefresh(
    SecureStorageService secureStorage,
    Dio refreshDio,
  ) async {
    try {
      final refreshToken = await secureStorage.readRefreshToken();

      if (refreshToken == null || refreshToken.trim().isEmpty) {
        return null;
      }

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final accessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String;

      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );

      return accessToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _notifyUnauthorized() async {
    final callback = onUnauthorized;

    if (callback == null) {
      return;
    }

    try {
      await _handleUnauthorized(callback);
    } catch (_) {
      // A falha no encerramento da sessão não deve impedir
      // que o erro original seja propagado.
    }
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
  final Dio _refreshDio;
  final Dio dio;
}
