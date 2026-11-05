
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/features/auth/application/auth_store.dart';
import 'package:finplan/features/auth/data/auth_service.dart';
import 'package:finplan/features/auth/domain/entities/auth_user.dart';

class FakeAuthService extends AuthService {
  int logoutCalls = 0;

  Completer<void>? logoutCompleter;

  @override
  Future<AuthUser> getCurrentUser() async {
    return const AuthUser(
      id: 'user-123',
      email: 'teste@finplan.com',
      name: 'Usuário de teste',
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;

    if (logoutCompleter != null) {
      await logoutCompleter!.future;
    }
  }
}

void main() {
  group('AuthStore - expiração de sessão', () {
    late FakeAuthService authService;
    late AuthStore authStore;

    setUp(() {
      authService = FakeAuthService();
      authStore = AuthStore(authService: authService);
    });

    tearDown(() {
      authStore.dispose();
    });

    test('restaura uma sessão autenticada', () async {
      await authStore.restoreSession();

      expect(authStore.isAuthenticated, isTrue);
      expect(authStore.user?.email, 'teste@finplan.com');
      expect(authStore.isCheckingSession, isFalse);
    });

    test('encerra a sessão quando o JWT expira', () async {
      await authStore.restoreSession();

      await authStore.handleSessionExpired();

      expect(authStore.isAuthenticated, isFalse);
      expect(authStore.user, isNull);
      expect(authStore.errorMessage,
          'Sua sessão expirou. Entre novamente para continuar.');
      expect(authService.logoutCalls, 1);
    });

    test('executa apenas um logout para chamadas simultâneas', () async {
      await authStore.restoreSession();

      authService.logoutCompleter = Completer<void>();

      final firstRequest = authStore.handleSessionExpired();
      final secondRequest = authStore.handleSessionExpired();

      expect(authService.logoutCalls, 1);

      authService.logoutCompleter!.complete();

      await Future.wait([
        firstRequest,
        secondRequest,
      ]);

      expect(authService.logoutCalls, 1);
      expect(authStore.isAuthenticated, isFalse);
    });

    test('mantém a mensagem de expiração até ser limpa', () async {
      await authStore.restoreSession();

      await authStore.handleSessionExpired();

      expect(authStore.errorMessage, isNotNull);

      authStore.clearError();

      expect(authStore.errorMessage, isNull);
    });
  });
}
