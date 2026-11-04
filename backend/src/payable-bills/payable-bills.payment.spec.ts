
import { ConflictException, NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { PrismaService } from '../prisma/prisma.service.js';
import { PayableBillsService } from './payable-bills.service.js';

describe('PayableBillsService - pay', () => {
  let service: PayableBillsService;

  const userId = 'user-test-123';
  const billId = 'bill-test-123';
  const accountId = '602cd750-e31a-4d23-b986-e09fbc8446f8';
  const anotherAccountId = '702cd750-e31a-4d23-b986-e09fbc8446f8';

  const bill = {
    id: billId,
    userId,
    description: 'Conta de energia',
    amount: 200,
    category: 'utilities',
    dueDate: new Date('2026-11-20T00:00:00.000Z'),
    discountDeadline: new Date('2026-11-10T00:00:00.000Z'),
    discountAmount: 20,
    status: 'pending',
    paidAt: null,
    accountId,
    linkedPendingTransactionId: null,
    linkedTransactionId: null,
    notes: 'Teste de pagamento',
  };

  const txMock = {
    payableBill: {
      findFirst: vi.fn(),
      updateMany: vi.fn(),
      findUnique: vi.fn(),
    },
    financialTransaction: {
      findFirst: vi.fn(),
      updateMany: vi.fn(),
      create: vi.fn(),
    },
    bankAccount: {
      findFirst: vi.fn(),
    },
  };

  const prismaMock = {
    $transaction: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();

    prismaMock.$transaction.mockImplementation(
      async (callback) => callback(txMock),
    );

    service = new PayableBillsService(
      prismaMock as unknown as PrismaService,
    );

    txMock.payableBill.findFirst.mockResolvedValue({ ...bill });

    txMock.bankAccount.findFirst.mockResolvedValue({
      id: accountId,
    });

    txMock.financialTransaction.findFirst.mockResolvedValue(null);

    txMock.financialTransaction.create.mockResolvedValue({
      id: 'transaction-test-123',
    });

    txMock.payableBill.updateMany.mockResolvedValue({
      count: 1,
    });

    txMock.financialTransaction.updateMany.mockResolvedValue({
      count: 1,
    });

    txMock.payableBill.findUnique.mockResolvedValue({
      ...bill,
      status: 'paid',
      paidAt: new Date('2026-11-05T12:00:00.000Z'),
      linkedTransactionId: 'transaction-test-123',
    });
  });

  it('deve realizar pagamento aplicando o desconto dentro do prazo', async () => {
    const result = await service.pay(userId, billId, {
      paidAt: '2026-11-05T12:00:00.000Z',
    });

    expect(result.payment.originalAmount).toBe(200);
    expect(result.payment.discountApplied).toBe(20);
    expect(result.payment.paidAmount).toBe(180);

    expect(result.bill.status).toBe('paid');

    expect(txMock.financialTransaction.create).toHaveBeenCalledOnce();

    const transactionCall =
      txMock.financialTransaction.create.mock.calls[0][0];

    expect(transactionCall.data.amount).toBe(180);
    expect(transactionCall.data.type).toBe('expense');
    expect(transactionCall.data.category).toBe('bills');
    expect(transactionCall.data.status).toBe('completed');

    expect(txMock.payableBill.updateMany).toHaveBeenCalledOnce();

    expect(prismaMock.$transaction).toHaveBeenCalledOnce();
  });

  it('não deve pagar uma conta que já foi paga', async () => {
    txMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
      status: 'paid',
    });

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(ConflictException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
    expect(txMock.payableBill.updateMany).not.toHaveBeenCalled();
  });

  it('deve rejeitar pagamento quando a conta bancária não pertence ao usuário', async () => {
    txMock.bankAccount.findFirst.mockResolvedValue(null);

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(NotFoundException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
  });

  it('deve realizar pagamento sem desconto quando o prazo expirou', async () => {
    const result = await service.pay(userId, billId, {
      paidAt: '2026-11-15T12:00:00.000Z',
    });

    expect(result.payment.originalAmount).toBe(200);
    expect(result.payment.discountApplied).toBe(0);
    expect(result.payment.paidAmount).toBe(200);

    const transactionCall =
      txMock.financialTransaction.create.mock.calls[0][0];

    expect(transactionCall.data.amount).toBe(200);
  });

  it('deve reutilizar a transação pendente sem criar outra', async () => {
    const pendingTransaction = {
      id: 'pending-transaction-123',
      userId,
      type: 'expense',
      status: 'pending',
      accountId,
    };

    txMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
      linkedPendingTransactionId: pendingTransaction.id,
    });

    txMock.financialTransaction.findFirst.mockResolvedValue(
      pendingTransaction,
    );

    const result = await service.pay(userId, billId, {
      paidAt: '2026-11-05T12:00:00.000Z',
    });

    expect(result.payment.transactionId).toBe(
      pendingTransaction.id,
    );

    expect(
      txMock.financialTransaction.updateMany,
    ).toHaveBeenCalledOnce();

    const updateCall =
      txMock.financialTransaction.updateMany.mock.calls[0][0];

    expect(updateCall.data.amount).toBe(180);
    expect(updateCall.data.status).toBe('completed');
    expect(updateCall.data.category).toBe('bills');

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();

    expect(txMock.payableBill.updateMany).toHaveBeenCalledOnce();
  });

  it('deve rejeitar o pagamento de uma conta inexistente', async () => {
    txMock.payableBill.findFirst.mockResolvedValue(null);

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(NotFoundException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
    expect(txMock.payableBill.updateMany).not.toHaveBeenCalled();
  });

  it('não deve pagar uma conta sem conta bancária selecionada', async () => {
    txMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
      accountId: null,
    });

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(ConflictException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
    expect(txMock.payableBill.updateMany).not.toHaveBeenCalled();
  });

  it('deve rejeitar pagamento quando a transação pendente vinculada não existe', async () => {
    txMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
      linkedPendingTransactionId: 'pending-transaction-123',
    });

    txMock.financialTransaction.findFirst.mockResolvedValue(null);

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(ConflictException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
    expect(txMock.payableBill.updateMany).not.toHaveBeenCalled();
  });

  it('não deve pagar quando a transação pendente pertence a outra conta bancária', async () => {
    const pendingTransaction = {
      id: 'pending-transaction-123',
      userId,
      type: 'expense',
      status: 'pending',
      accountId: anotherAccountId,
    };

    txMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
      linkedPendingTransactionId: pendingTransaction.id,
    });

    txMock.financialTransaction.findFirst.mockResolvedValue(
      pendingTransaction,
    );

    await expect(
      service.pay(userId, billId, {}),
    ).rejects.toThrow(ConflictException);

    expect(txMock.financialTransaction.create).not.toHaveBeenCalled();
    expect(txMock.payableBill.updateMany).not.toHaveBeenCalled();
  });
});