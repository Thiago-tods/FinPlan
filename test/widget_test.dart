
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finplan/app/finplan_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FinPlan application starts', (tester) async {
    await tester.pumpWidget(const FinPlanApp());

    await tester.pumpAndSettle();

    expect(find.text('FinPlan'), findsOneWidget);
    expect(find.text('Olá, seja bem-vindo!'), findsOneWidget);
  });
}
