
import { ConflictException, NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { PrismaService } from '../prisma/prisma.service.js';
import { CreatePayableBillDto } from './dto/create-payable-bill.dto.js';
import { UpdatePayableBillDto } from './dto/update-payable-bill.dto.js';
import { PayableBillsService } from './payable-bills.service.js';

describe('PayableBillsService', () => {
  let service: PayableBillsService;

  const userId = 'user-test-123';
  const billId = 'bill-test-123';
  const accountId = '602cd750-e31a-4d23-b986-e09fbc8446f8';

  const bill = {
    id: billId,
    userId,
    description: 'Conta de energia',
    amount: 300,
    category: 'utilities',
    dueDate: new Date('2026-11-20T00:00:00.000Z'),
    discountDeadline: null,
    discountAmount: null,
    status: 'pending',
    paidAt: null,
    accountId,
    linkedPendingTransactionId: null,
    linkedTransactionId: null,
    notes: 'Conta de teste',
    createdAt: new Date('2026-11-01T00:00:00.000Z'),
    updatedAt: new Date('2026-11-01T00:00:00.000Z'),
  };

  const prismaMock = {
    bankAccount: {
      findFirst: vi.fn(),
    },
    financialTransaction: {
      findFirst: vi.fn(),
    },
    payableBill: {
      create: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  };

  const createDto: CreatePayableBillDto = {
    description: '  Conta de energia  ',
    amount: 300,
    category: 'utilities',
    dueDate: '2026-11-20T00:00:00.000Z',
    accountId,
    notes: '  Conta de teste  ',
  };

  beforeEach(() => {
    vi.clearAllMocks();

    service = new PayableBillsService(
      prismaMock as unknown as PrismaService,
    );

    prismaMock.bankAccount.findFirst.mockResolvedValue({
      id: accountId,
    });

    prismaMock.financialTransaction.findFirst.mockResolvedValue(null);

    prismaMock.payableBill.findFirst.mockResolvedValue({
      ...bill,
    });

    prismaMock.payableBill.create.mockImplementation(
      async ({ data }) => ({
        ...data,
        status: 'pending',
        paidAt: null,
        linkedTransactionId: null,
      }),
    );

    prismaMock.payableBill.update.mockImplementation(
      async ({ data }) => ({
        ...bill,
        ...data,
      }),
    );

    prismaMock.payableBill.delete.mockResolvedValue({
      ...bill,
    });
  });

  describe('create', () => {
    it('deve criar uma conta a pagar com dados válidos', async () => {
      const result = await service.create(userId, createDto);

      expect(result.description).toBe('Conta de energia');
      expect(result.amount).toBe(300);
      expect(result.status).toBe('pending');

      expect(prismaMock.bankAccount.findFirst).toHaveBeenCalledWith({
        where: {
          id: accountId,
          userId,
        },
        select: {
          id: true,
        },
      });

      expect(prismaMock.payableBill.create).toHaveBeenCalledOnce();

      const createCall =
        prismaMock.payableBill.create.mock.calls[0][0];

      expect(createCall.data.userId).toBe(userId);
      expect(createCall.data.description).toBe('Conta de energia');
      expect(createCall.data.notes).toBe('Conta de teste');
      expect(createCall.data.accountId).toBe(accountId);
      expect(createCall.data.status).toBeUndefined();
      expect(createCall.data.id).toBeDefined();
    });

    it('não deve criar uma conta com desconto sem prazo definido', async () => {
      const dto: CreatePayableBillDto = {
        ...createDto,
        discountAmount: 20,
      };

      await expect(
        service.create(userId, dto),
      ).rejects.toThrow(ConflictException);

      expect(prismaMock.payableBill.create).not.toHaveBeenCalled();
    });

    it('não deve aceitar desconto maior ou igual ao valor da conta', async () => {
      const dto: CreatePayableBillDto = {
        ...createDto,
        discountAmount: 300,
        discountDeadline: '2026-11-10T00:00:00.000Z',
      };

      await expect(
        service.create(userId, dto),
      ).rejects.toThrow(
        'O desconto deve ser maior que zero e menor que o valor da conta.',
      );

      expect(prismaMock.payableBill.create).not.toHaveBeenCalled();
    });

    it('não deve aceitar prazo de desconto posterior ao vencimento', async () => {
      const dto: CreatePayableBillDto = {
        ...createDto,
        discountAmount: 20,
        discountDeadline: '2026-11-25T00:00:00.000Z',
      };

      await expect(
        service.create(userId, dto),
      ).rejects.toThrow(
        'O prazo do desconto não pode ser posterior ao vencimento.',
      );

      expect(prismaMock.payableBill.create).not.toHaveBeenCalled();
    });

    it('não deve aceitar uma conta bancária pertencente a outro usuário', async () => {
      prismaMock.bankAccount.findFirst.mockResolvedValue(null);

      await expect(
        service.create(userId, createDto),
      ).rejects.toThrow(NotFoundException);

      expect(prismaMock.payableBill.create).not.toHaveBeenCalled();
    });

    it('deve aceitar uma conta sem desconto', async () => {
      prismaMock.payableBill.create.mockResolvedValue({
        id: 'bill-test-123',
        description: 'Conta de energia',
        amount: 300,
        discountAmount: null,
        discountDeadline: null,
        status: 'pending',
      });

      const dto: CreatePayableBillDto = {
        description: 'Conta de energia',
        amount: 300,
        category: 'utilities',
        dueDate: '2026-11-20T00:00:00.000Z',
      };

      const result = await service.create(userId, dto);

      expect(result.discountAmount).toBeNull();
      expect(result.discountDeadline).toBeNull();
      expect(result.status).toBe('pending');
    });
  });

  describe('findAll', () => {
    it('deve listar somente as contas do usuário autenticado', async () => {
      prismaMock.payableBill.findMany.mockResolvedValue([
        { ...bill },
      ]);

      const result = await service.findAll(userId);

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(billId);

      expect(prismaMock.payableBill.findMany).toHaveBeenCalledWith({
        where: {
          userId,
        },
        orderBy: [
          {
            dueDate: 'asc',
          },
          {
            createdAt: 'desc',
          },
        ],
        select: expect.any(Object),
      });
    });

    it('deve retornar uma lista vazia quando o usuário não possui contas', async () => {
      prismaMock.payableBill.findMany.mockResolvedValue([]);

      const result = await service.findAll(userId);

      expect(result).toEqual([]);
      expect(prismaMock.payableBill.findMany).toHaveBeenCalledOnce();
    });
  });

  describe('findOne', () => {
    it('deve encontrar uma conta pertencente ao usuário', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue({
        ...bill,
      });

      const result = await service.findOne(userId, billId);

      expect(result.id).toBe(billId);
      expect(result.description).toBe('Conta de energia');

      expect(prismaMock.payableBill.findFirst).toHaveBeenCalledWith({
        where: {
          id: billId,
          userId,
        },
        select: expect.any(Object),
      });
    });

    it('não deve encontrar uma conta pertencente a outro usuário', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue(null);

      await expect(
        service.findOne(userId, billId),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('update', () => {
    it('deve atualizar uma conta pendente', async () => {
      const dto: UpdatePayableBillDto = {
        description: '  Conta de energia atualizada  ',
        notes: '  Nova observação  ',
      };

      const result = await service.update(userId, billId, dto);

      expect(result.description).toBe('Conta de energia atualizada');

      expect(prismaMock.payableBill.update).toHaveBeenCalledOnce();

      const updateCall =
        prismaMock.payableBill.update.mock.calls[0][0];

      expect(updateCall.where).toEqual({
        id: billId,
        userId,
      });

      expect(updateCall.data.description).toBe(
        'Conta de energia atualizada',
      );

      expect(updateCall.data.notes).toBe('Nova observação');
    });

    it('não deve atualizar uma conta que já foi paga', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue({
        ...bill,
        status: 'paid',
      });

      await expect(
        service.update(userId, billId, {
          description: 'Tentativa de alteração',
        }),
      ).rejects.toThrow(ConflictException);

      expect(prismaMock.payableBill.update).not.toHaveBeenCalled();
    });

    it('não deve atualizar uma conta inexistente', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue(null);

      await expect(
        service.update(userId, billId, {
          description: 'Tentativa de alteração',
        }),
      ).rejects.toThrow(NotFoundException);

      expect(prismaMock.payableBill.update).not.toHaveBeenCalled();
    });

    it('não deve aceitar desconto sem prazo definido durante a atualização', async () => {
      const dto: UpdatePayableBillDto = {
        discountAmount: 20,
      };

      await expect(
        service.update(userId, billId, dto),
      ).rejects.toThrow(ConflictException);

      expect(prismaMock.payableBill.update).not.toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('deve excluir uma conta pendente', async () => {
      const result = await service.remove(userId, billId);

      expect(result).toEqual({
        message: 'Conta a pagar excluída com sucesso.',
      });

      expect(prismaMock.payableBill.delete).toHaveBeenCalledWith({
        where: {
          id: billId,
          userId,
        },
      });
    });

    it('não deve excluir uma conta que já foi paga', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue({
        ...bill,
        status: 'paid',
      });

      await expect(
        service.remove(userId, billId),
      ).rejects.toThrow(ConflictException);

      expect(prismaMock.payableBill.delete).not.toHaveBeenCalled();
    });

    it('não deve excluir uma conta inexistente', async () => {
      prismaMock.payableBill.findFirst.mockResolvedValue(null);

      await expect(
        service.remove(userId, billId),
      ).rejects.toThrow(NotFoundException);

      expect(prismaMock.payableBill.delete).not.toHaveBeenCalled();
    });
  });
});