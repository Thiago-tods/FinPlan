
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/entities/auth_user.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
    SecureStorageService? secureStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final userData = Map<String, dynamic>.from(data['user'] as Map);

    return AuthUser.fromJson(userData);
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userData = Map<String, dynamic>.from(data['user'] as Map);

    await _secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return AuthUser.fromJson(userData);
  }

  Future<void> refreshTokens() async {
    final refreshToken = await _secureStorage.readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Refresh token não encontrado.');
    }

    final response = await _apiClient.dio.post(
      '/auth/refresh',
      data: {
        'refreshToken': refreshToken,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['accessToken'] as String;
    final newRefreshToken = data['refreshToken'] as String;

    await _secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );
  }

  Future<AuthUser> getCurrentUser() async {
    final response = await _apiClient.dio.get('/auth/me');

    final data = Map<String, dynamic>.from(response.data as Map);
    final userData = Map<String, dynamic>.from(data['user'] as Map);

    return AuthUser.fromJson(userData);
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.readRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.dio.post(
          '/auth/logout',
          data: {
            'refreshToken': refreshToken,
          },
        );
      }
    } on DioException {
      // O logout local deve ocorrer mesmo sem conexão com o servidor.
    } finally {
      await _secureStorage.deleteTokens();
    }
  }
}
