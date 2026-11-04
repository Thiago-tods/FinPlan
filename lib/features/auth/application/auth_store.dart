
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../domain/entities/auth_user.dart';

class AuthStore extends ChangeNotifier {
  AuthStore({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  AuthUser? _user;
  bool _isLoading = false;
  bool _isCheckingSession = true;
  String? _errorMessage;

  AuthUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isCheckingSession => _isCheckingSession;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    _isCheckingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.getCurrentUser();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _authService.logout();
        _user = null;
      }
    } catch (_) {
      // Uma falha inesperada não deve apagar um token válido.
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      _user = await _authService.login(
        email: email,
        password: password,
      );
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Não foi possível realizar o login. Verifique seus dados.';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Não foi possível realizar o cadastro.';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _user = null;
    _errorMessage = null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
