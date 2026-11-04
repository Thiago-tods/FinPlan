
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
    final token = data['accessToken'] as String;
    final userData = Map<String, dynamic>.from(data['user'] as Map);

    await _secureStorage.saveToken(token);

    return AuthUser.fromJson(userData);
  }

  Future<AuthUser> getCurrentUser() async {
    final response = await _apiClient.dio.get('/auth/me');

    final data = Map<String, dynamic>.from(response.data as Map);
    final userData = Map<String, dynamic>.from(data['user'] as Map);

    return AuthUser.fromJson(userData);
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
  }
}
