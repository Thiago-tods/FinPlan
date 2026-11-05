
import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreatePayableBillDto } from './dto/create-payable-bill.dto.js';
import { UpdatePayableBillDto } from './dto/update-payable-bill.dto.js';
import { PayPayableBillDto } from './dto/pay-payable-bill.dto.js';

@Injectable()
export class PayableBillsService {
  constructor(private readonly prisma: PrismaService) {}

  private async ensureAccountOwnership(
    userId: string,
    accountId: string,
  ): Promise<void> {
    const account = await this.prisma.bankAccount.findFirst({
      where: {
        id: accountId,
        userId,
      },
      select: {
        id: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Conta bancária não encontrada.');
    }
  }

  private async ensurePendingTransaction(
    userId: string,
    transactionId: string,
    billId?: string,
  ) {
    const transaction =
      await this.prisma.financialTransaction.findFirst({
        where: {
          id: transactionId,
          userId,
        },
        select: {
          id: true,
          type: true,
          status: true,
          accountId: true,
        },
      });

    if (!transaction) {
      throw new NotFoundException(
        'Transação financeira não encontrada.',
      );
    }

    if (
      transaction.type !== 'expense' ||
      transaction.status !== 'pending'
    ) {
      throw new ConflictException(
        'A transação vinculada precisa ser uma despesa pendente.',
      );
    }

    const existingLink = await this.prisma.payableBill.findFirst({
      where: {
        linkedPendingTransactionId: transactionId,
        ...(billId && {
          id: {
            not: billId,
          },
        }),
      },
      select: {
        id: true,
      },
    });

    if (existingLink) {
      throw new ConflictException(
        'Esta transação já está vinculada a outra conta a pagar.',
      );
    }

    return transaction;
  }

  private validateDiscount(
    amount: number,
    discountAmount: number | null | undefined,
    discountDeadline: Date | null | undefined,
    dueDate: Date,
  ): void {
    const hasDiscountAmount =
      discountAmount !== undefined && discountAmount !== null;

    const hasDiscountDeadline =
      discountDeadline !== undefined && discountDeadline !== null;

    if (hasDiscountAmount !== hasDiscountDeadline) {
      throw new ConflictException(
        'Informe o valor e o prazo do desconto juntos.',
      );
    }

    if (!hasDiscountAmount || !hasDiscountDeadline) {
      return;
    }

    if (discountAmount <= 0 || discountAmount >= amount) {
      throw new ConflictException(
        'O desconto deve ser maior que zero e menor que o valor da conta.',
      );
    }

    const deadlineDay = Date.UTC(
      discountDeadline.getUTCFullYear(),
      discountDeadline.getUTCMonth(),
      discountDeadline.getUTCDate(),
    );

    const dueDay = Date.UTC(
      dueDate.getUTCFullYear(),
      dueDate.getUTCMonth(),
      dueDate.getUTCDate(),
    );

    if (deadlineDay > dueDay) {
      throw new ConflictException(
        'O prazo do desconto não pode ser posterior ao vencimento.',
      );
    }
  }

  private mapBillCategoryToTransactionCategory(
    category: string,
  ):
    | 'housing'
    | 'bills'
    | 'food'
    | 'transportation'
    | 'health'
    | 'education'
    | 'taxes'
    | 'other' {
    const categories = {
      housing: 'housing',
      utilities: 'bills',
      food: 'food',
      transport: 'transportation',
      health: 'health',
      education: 'education',
      subscriptions: 'other',
      taxes: 'taxes',
      other: 'other',
    } as const;

    return categories[category as keyof typeof categories] ?? 'other';
  }

  private isWithinDiscountDeadline(
    paidAt: Date,
    discountDeadline: Date,
  ): boolean {
    const paymentDay = Date.UTC(
      paidAt.getUTCFullYear(),
      paidAt.getUTCMonth(),
      paidAt.getUTCDate(),
    );

    const deadlineDay = Date.UTC(
      discountDeadline.getUTCFullYear(),
      discountDeadline.getUTCMonth(),
      discountDeadline.getUTCDate(),
    );

    return paymentDay <= deadlineDay;
  }

  async create(userId: string, dto: CreatePayableBillDto) {
    const description = dto.description.trim();
    const amount = dto.amount;
    const dueDate = new Date(dto.dueDate);

    const discountDeadline = dto.discountDeadline
      ? new Date(dto.discountDeadline)
      : null;

    this.validateDiscount(
      amount,
      dto.discountAmount,
      discountDeadline,
      dueDate,
    );

    let linkedTransactionAccountId: string | null = null;

    if (dto.accountId) {
      await this.ensureAccountOwnership(userId, dto.accountId);
    }

    if (dto.linkedPendingTransactionId) {
      const transaction = await this.ensurePendingTransaction(
        userId,
        dto.linkedPendingTransactionId,
      );

      linkedTransactionAccountId = transaction.accountId;

      if (
        dto.accountId &&
        dto.accountId !== transaction.accountId
      ) {
        throw new ConflictException(
          'A conta bancária deve ser a mesma da transação vinculada.',
        );
      }
    }

    return this.prisma.payableBill.create({
      data: {
        id: randomUUID(),
        userId,
        description,
        amount,
        category: dto.category,
        dueDate,
        discountDeadline,
        discountAmount: dto.discountAmount ?? null,
        accountId: dto.accountId ?? linkedTransactionAccountId,
        linkedPendingTransactionId:
          dto.linkedPendingTransactionId ?? null,
        notes: dto.notes?.trim() ?? '',
      },
      select: {
        id: true,
        description: true,
        amount: true,
        category: true,
        dueDate: true,
        discountDeadline: true,
        discountAmount: true,
        status: true,
        paidAt: true,
        accountId: true,
        linkedPendingTransactionId: true,
        linkedTransactionId: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async findAll(userId: string) {
    return this.prisma.payableBill.findMany({
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
      select: {
        id: true,
        description: true,
        amount: true,
        category: true,
        dueDate: true,
        discountDeadline: true,
        discountAmount: true,
        status: true,
        paidAt: true,
        accountId: true,
        linkedPendingTransactionId: true,
        linkedTransactionId: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async findOne(userId: string, billId: string) {
    const bill = await this.prisma.payableBill.findFirst({
      where: {
        id: billId,
        userId,
      },
      select: {
        id: true,
        description: true,
        amount: true,
        category: true,
        dueDate: true,
        discountDeadline: true,
        discountAmount: true,
        status: true,
        paidAt: true,
        accountId: true,
        linkedPendingTransactionId: true,
        linkedTransactionId: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!bill) {
      throw new NotFoundException(
        'Conta a pagar não encontrada.',
      );
    }

    return bill;
  }

  async update(
    userId: string,
    billId: string,
    dto: UpdatePayableBillDto,
  ) {
    const existingBill = await this.findOne(userId, billId);

    if (existingBill.status !== 'pending') {
      throw new ConflictException(
        'Somente contas pendentes podem ser editadas.',
      );
    }

    const amount = dto.amount ?? Number(existingBill.amount);
    const dueDate = dto.dueDate
      ? new Date(dto.dueDate)
      : existingBill.dueDate;

    const discountAmount =
      dto.discountAmount !== undefined
        ? dto.discountAmount
        : existingBill.discountAmount
          ? Number(existingBill.discountAmount)
          : null;

    const discountDeadline =
      dto.discountDeadline !== undefined
        ? dto.discountDeadline
          ? new Date(dto.discountDeadline)
          : null
        : existingBill.discountDeadline;

    this.validateDiscount(
      amount,
      discountAmount,
      discountDeadline,
      dueDate,
    );

    const accountId =
      dto.accountId !== undefined
        ? dto.accountId
        : existingBill.accountId;

    const linkedPendingTransactionId =
      dto.linkedPendingTransactionId !== undefined
        ? dto.linkedPendingTransactionId
        : existingBill.linkedPendingTransactionId;

    if (accountId) {
      await this.ensureAccountOwnership(userId, accountId);
    }

    if (linkedPendingTransactionId) {
      const transaction = await this.ensurePendingTransaction(
        userId,
        linkedPendingTransactionId,
        billId,
      );

      if (
        accountId &&
        accountId !== transaction.accountId
      ) {
        throw new ConflictException(
          'A conta bancária deve ser a mesma da transação vinculada.',
        );
      }
    }

    return this.prisma.payableBill.update({
      where: {
        id: billId,
        userId,
      },
      data: {
        ...(dto.description !== undefined && {
          description: dto.description.trim(),
        }),
        ...(dto.amount !== undefined && {
          amount: dto.amount,
        }),
        ...(dto.category !== undefined && {
          category: dto.category,
        }),
        ...(dto.dueDate !== undefined && {
          dueDate,
        }),
        ...(dto.discountDeadline !== undefined && {
          discountDeadline,
        }),
        ...(dto.discountAmount !== undefined && {
          discountAmount,
        }),
        ...(dto.accountId !== undefined && {
          accountId,
        }),
        ...(dto.linkedPendingTransactionId !== undefined && {
          linkedPendingTransactionId,
        }),
        ...(dto.notes !== undefined && {
          notes: dto.notes.trim(),
        }),
      },
      select: {
        id: true,
        description: true,
        amount: true,
        category: true,
        dueDate: true,
        discountDeadline: true,
        discountAmount: true,
        status: true,
        paidAt: true,
        accountId: true,
        linkedPendingTransactionId: true,
        linkedTransactionId: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async pay(
    userId: string,
    billId: string,
    dto: PayPayableBillDto,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const bill = await tx.payableBill.findFirst({
        where: {
          id: billId,
          userId,
        },
      });

      if (!bill) {
        throw new NotFoundException(
          'Conta a pagar não encontrada.',
        );
      }

      if (bill.status !== 'pending') {
        throw new ConflictException(
          'Esta conta não está pendente e não pode ser paga novamente.',
        );
      }

      const paidAt = dto.paidAt
        ? new Date(dto.paidAt)
        : new Date();

      let pendingTransaction = null;

      if (bill.linkedPendingTransactionId) {
        pendingTransaction =
          await tx.financialTransaction.findFirst({
            where: {
              id: bill.linkedPendingTransactionId,
              userId,
            },
          });

        if (!pendingTransaction) {
          throw new ConflictException(
            'A transação pendente vinculada não foi encontrada.',
          );
        }

        if (
          pendingTransaction.type !== 'expense' ||
          pendingTransaction.status !== 'pending'
        ) {
          throw new ConflictException(
            'A transação vinculada não é mais uma despesa pendente.',
          );
        }
      }

      const accountId =
        dto.accountId ??
        bill.accountId ??
        pendingTransaction?.accountId;

      if (!accountId) {
        throw new ConflictException(
          'Informe uma conta bancária para realizar o pagamento.',
        );
      }

      if (
        pendingTransaction &&
        pendingTransaction.accountId !== accountId
      ) {
        throw new ConflictException(
          'A conta bancária precisa ser a mesma da transação pendente vinculada.',
        );
      }

      const account = await tx.bankAccount.findFirst({
        where: {
          id: accountId,
          userId,
        },
        select: {
          id: true,
        },
      });

      if (!account) {
        throw new NotFoundException(
          'Conta bancária não encontrada.',
        );
      }

      const originalAmountCents = Math.round(
        Number(bill.amount) * 100,
      );

      const discountAmountCents = bill.discountAmount
        ? Math.round(Number(bill.discountAmount) * 100)
        : 0;

      const discountEligible =
        bill.discountDeadline !== null &&
        discountAmountCents > 0 &&
        this.isWithinDiscountDeadline(
          paidAt,
          bill.discountDeadline,
        );

      const paidAmountCents = discountEligible
        ? originalAmountCents - discountAmountCents
        : originalAmountCents;

      const paidAmount = paidAmountCents / 100;

      
      const transactionId =
        pendingTransaction?.id ?? randomUUID();

      const category = this.mapBillCategoryToTransactionCategory(
        dto.category ?? bill.category,
      );

      // Primeiro, registra ou atualiza a transação financeira.
      if (pendingTransaction) {
        const transactionUpdate =
          await tx.financialTransaction.updateMany({
            where: {
              id: pendingTransaction.id,
              userId,
              type: 'expense',
              status: 'pending',
            },
            data: {
              amount: paidAmount,
              category,
              accountId,
              transactionDate: paidAt,
              dueDate: bill.dueDate,
              status: 'completed',
            },
          });

        if (transactionUpdate.count !== 1) {
          throw new ConflictException(
            'A transação pendente foi alterada durante o pagamento.',
          );
        }
      } else {
        await tx.financialTransaction.create({
          data: {
            id: transactionId,
            userId,
            description: bill.description,
            amount: paidAmount,
            type: 'expense',
            category,
            accountId,
            transactionDate: paidAt,
            dueDate: bill.dueDate,
            status: 'completed',
            notes: bill.notes || null,
          },
        });
      }

      // Depois, vincula a transação existente à conta paga.
      const billUpdate = await tx.payableBill.updateMany({
        where: {
          id: billId,
          userId,
          status: 'pending',
        },
        data: {
          status: 'paid',
          paidAt,
          accountId,
          linkedTransactionId: transactionId,
          linkedPendingTransactionId: null,
        },
      });

      if (billUpdate.count !== 1) {
        throw new ConflictException(
          'Esta conta já foi paga ou está sendo processada.',
        );
      }

      const updatedBill = await tx.payableBill.findUnique({
        where: {
          id: billId,
        },
        select: {
          id: true,
          description: true,
          amount: true,
          category: true,
          dueDate: true,
          discountDeadline: true,
          discountAmount: true,
          status: true,
          paidAt: true,
          accountId: true,
          linkedPendingTransactionId: true,
          linkedTransactionId: true,
          notes: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      return {
        message: 'Conta paga com sucesso.',
        bill: updatedBill,
        payment: {
          originalAmount: originalAmountCents / 100,
          discountApplied: discountEligible
            ? discountAmountCents / 100
            : 0,
          paidAmount,
          paidAt,
          transactionId,
        },
      };
    });
  }
  async cancel(userId: string, billId: string) {
    const bill = await this.findOne(userId, billId);

    if (bill.status !== 'pending') {
      throw new ConflictException(
        'Somente contas pendentes podem ser canceladas.',
      );
    }

    const result = await this.prisma.payableBill.updateMany({
      where: {
        id: billId,
        userId,
        status: 'pending',
      },
      data: {
        status: 'cancelled',
        linkedPendingTransactionId: null,
      },
    });

    if (result.count !== 1) {
      throw new ConflictException(
        'Esta conta já foi paga, cancelada ou está sendo processada.',
      );
    }

    return this.findOne(userId, billId);
  }
  async remove(userId: string, billId: string) {
    const bill = await this.findOne(userId, billId);

    if (bill.status === 'paid') {
      throw new ConflictException(
        'Contas pagas não podem ser excluídas para preservar o histórico financeiro.',
      );
    }

    await this.prisma.payableBill.delete({
      where: {
        id: billId,
        userId,
      },
    });

    return {
      message: 'Conta a pagar excluída com sucesso.',
    };
  }
}

