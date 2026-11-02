
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finplan/features/planning/application/planning_store.dart';
import 'package:finplan/features/planning/domain/entities/payable_bill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlanningStore', () {
    late PlanningStore planningStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      planningStore = PlanningStore();
      await planningStore.loadBills();
    });

    test('deve preservar o vínculo ao alterar o status da conta', () async {
      final bill = PayableBill(
        id: 'bill-1',
        description: 'Conta de luz',
        amount: 150.0,
        category: BillCategory.utilities,
        dueDate: DateTime(2026, 12, 10),
        linkedPendingTransactionId: 'transaction-1',
      );

      await planningStore.saveBill(bill);

      await planningStore.updateBillStatus(
        'bill-1',
        BillStatus.paid,
        accountId: 'account-1',
        linkedTransactionId: 'transaction-1',
      );

      final updatedBill = planningStore.bills.first;

      expect(updatedBill.status, BillStatus.paid);
      expect(
        updatedBill.linkedPendingTransactionId,
        'transaction-1',
      );
      expect(updatedBill.linkedTransactionId, 'transaction-1');
    });

    test('não deve permitir vincular a mesma transação a duas contas', () async {
      final firstBill = PayableBill(
        id: 'bill-1',
        description: 'Conta de luz',
        amount: 150.0,
        category: BillCategory.utilities,
        dueDate: DateTime(2026, 12, 10),
        linkedPendingTransactionId: 'transaction-1',
      );

      final secondBill = PayableBill(
        id: 'bill-2',
        description: 'Conta de água',
        amount: 90.0,
        category: BillCategory.utilities,
        dueDate: DateTime(2026, 12, 15),
        linkedPendingTransactionId: 'transaction-1',
      );

      await planningStore.saveBill(firstBill);

      await expectLater(
        planningStore.saveBill(secondBill),
        throwsA(isA<ArgumentError>()),
      );

      expect(planningStore.bills.length, 1);
    });

    test('deve permitir editar uma conta mantendo seu próprio vínculo', () async {
      final bill = PayableBill(
        id: 'bill-1',
        description: 'Conta de luz',
        amount: 150.0,
        category: BillCategory.utilities,
        dueDate: DateTime(2026, 12, 10),
        linkedPendingTransactionId: 'transaction-1',
      );

      await planningStore.saveBill(bill);

      final editedBill = PayableBill(
        id: 'bill-1',
        description: 'Conta de luz atualizada',
        amount: 160.0,
        category: BillCategory.utilities,
        dueDate: DateTime(2026, 12, 10),
        linkedPendingTransactionId: 'transaction-1',
      );

      await planningStore.saveBill(editedBill);

      expect(planningStore.bills.length, 1);
      expect(
        planningStore.bills.first.description,
        'Conta de luz atualizada',
      );
      expect(
        planningStore.bills.first.linkedPendingTransactionId,
        'transaction-1',
      );
    });
  });
}
