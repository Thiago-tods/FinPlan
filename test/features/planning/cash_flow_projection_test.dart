import 'package:flutter_test/flutter_test.dart';

import 'package:finplan/features/planning/domain/entities/cash_flow_projection.dart';

void main() {
  group('CashFlowProjection', () {
    test('considera o saldo inicial no cálculo do menor saldo', () {
      final projection = CashFlowProjection(
        initialBalance: 500,
        days: [
          CashFlowDay(
            date: DateTime(2026, 11, 2),
            openingBalance: 500,
            income: 1000,
            expenses: 0,
            closingBalance: 1500,
          ),
          CashFlowDay(
            date: DateTime(2026, 11, 3),
            openingBalance: 1500,
            income: 0,
            expenses: 200,
            closingBalance: 1300,
          ),
        ],
      );

      expect(projection.lowestBalance, 500);
    });

    test('identifica saldo negativo inferior ao saldo inicial', () {
      final projection = CashFlowProjection(
        initialBalance: 500,
        days: [
          CashFlowDay(
            date: DateTime(2026, 11, 2),
            openingBalance: 500,
            income: 0,
            expenses: 800,
            closingBalance: -300,
          ),
        ],
      );

      expect(projection.lowestBalance, -300);
    });

    test('retorna saldo inicial quando não existem dias projetados', () {
      const projection = CashFlowProjection(initialBalance: 750, days: []);

      expect(projection.lowestBalance, 750);
    });
  });
}
