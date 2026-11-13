
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../domain/entities/bank_account.dart';

class AccountsStore extends ChangeNotifier {
  AccountsStore({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  final List<BankAccount> _accounts = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  bool _forceReloadRequested = false;

  String? _errorMessage;
  Future<void>? _loadFuture;

  List<BankAccount> get accounts => List.unmodifiable(_accounts);

  bool get isLoaded => _isLoaded;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  double get totalBalance {
    return _accounts.fold(
      0.0,
      (total, account) => total + account.initialBalance,
    );
  }

  Future<void> loadAccounts({bool force = false}) {
    final currentLoad = _loadFuture;

    if (currentLoad != null) {
      if (force) {
        _forceReloadRequested = true;
      }

      return currentLoad;
    }

    if (_isLoaded && !force) {
      return Future.value();
    }

    final future = Future<void>.microtask(_performLoad);

    _loadFuture = future;

    return future;
  }

  Future<void> _performLoad() async {
    _isLoading = true;
    notifyListeners();

    try {
      do {
        _forceReloadRequested = false;

        await _loadAccountsFromApi();
      } while (_forceReloadRequested);
    } finally {
      _isLoading = false;
      _loadFuture = null;
      notifyListeners();
    }
  }

  Future<void> _loadAccountsFromApi() async {
    _errorMessage = null;

    try {
      final response = await _apiClient.dio.get('/accounts');

      final data = response.data as List<dynamic>;

      final loadedAccounts = data.map(
        (item) => BankAccount.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
      );

      _accounts
        ..clear()
        ..addAll(loadedAccounts);

      _isLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível carregar suas contas.',
      );

      debugPrint('Erro ao carregar contas: ${error.message}');
    } catch (error) {
      _errorMessage = 'Ocorreu um erro ao carregar suas contas.';
      debugPrint('Erro inesperado ao carregar contas: $error');
    }
  }

  Future<BankAccount> saveAccount(BankAccount account) async {
    _errorMessage = null;

    try {
      final index = _accounts.indexWhere(
        (item) => item.id == account.id,
      );

      final Response<dynamic> response;

      if (index >= 0) {
        response = await _apiClient.dio.patch(
          '/accounts/${account.id}',
          data: account.toApiJson(),
        );
      } else {
        response = await _apiClient.dio.post(
          '/accounts',
          data: account.toApiJson(),
        );
      }

      final savedAccount = BankAccount.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (index >= 0) {
        _accounts[index] = savedAccount;
      } else {
        _accounts.insert(0, savedAccount);
      }

      notifyListeners();

      return savedAccount;
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível salvar a conta.',
      );

      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount(String id) async {
    _errorMessage = null;

    try {
      await _apiClient.dio.delete('/accounts/$id');

      _accounts.removeWhere((account) => account.id == id);

      notifyListeners();
    } on DioException catch (error) {
      _errorMessage = _getErrorMessage(
        error,
        'Não foi possível excluir a conta.',
      );

      notifyListeners();
      rethrow;
    }
  }

  String _getErrorMessage(
    DioException error,
    String fallback,
  ) {
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];

      if (message is String) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
    }

    return fallback;
  }
}
