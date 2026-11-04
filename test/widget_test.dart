
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/features/auth/application/auth_store.dart';
import 'package:finplan/features/auth/presentation/pages/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FinPlan login page starts', (tester) async {
    final authStore = AuthStore();

    addTearDown(authStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authStore: authStore),
      ),
    );

    expect(find.text('FinPlan'), findsOneWidget);
    expect(find.text('Entre na sua conta para continuar.'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
