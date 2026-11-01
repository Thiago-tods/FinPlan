
import 'package:flutter_test/flutter_test.dart';
import 'package:finplan/app/finplan_app.dart';

void main() {
  testWidgets('FinPlan application starts', (tester) async {
    await tester.pumpWidget(const FinPlanApp());

    expect(find.text('FinPlan'), findsOneWidget);
    expect(find.text('Olá, seja bem-vindo!'), findsOneWidget);
  });
}
