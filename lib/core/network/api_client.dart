
import 'package:dio/dio.dart';

import '../security/secure_storage_service.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService(),
        dio = Dio(
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
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublicRoute = [
            '/auth/login',
            'auth/login',
            '/auth/register',
            'auth/register',
          ].contains(options.path);

          if (isPublicRoute) {
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
      ),
    );
  }

  final SecureStorageService _secureStorage;
  final Dio dio;
}
