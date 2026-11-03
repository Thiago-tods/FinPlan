
import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateTransactionDto } from './dto/create-transaction.dto.js';
import { UpdateTransactionDto } from './dto/update-transaction.dto.js';

@Injectable()
export class TransactionsService {
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
      throw new NotFoundException(
        'Conta bancária não encontrada.',
      );
    }
  }

  async create(userId: string, dto: CreateTransactionDto) {
    await this.ensureAccountOwnership(userId, dto.accountId);

    const transactionDate = new Date(dto.transactionDate);

    const dueDate = dto.dueDate
      ? new Date(dto.dueDate)
      : transactionDate;

    return this.prisma.financialTransaction.create({
      data: {
        id: randomUUID(),
        userId,
        description: dto.description.trim(),
        amount: dto.amount,
        type: dto.type,
        category: dto.category,
        accountId: dto.accountId,
        transactionDate,
        dueDate,
        status: dto.status ?? 'pending',
        notes: dto.notes?.trim() || null,
      },
      select: {
        id: true,
        description: true,
        amount: true,
        type: true,
        category: true,
        accountId: true,
        transactionDate: true,
        dueDate: true,
        status: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async findAll(userId: string) {
    return this.prisma.financialTransaction.findMany({
      where: {
        userId,
      },
      orderBy: [
        {
          transactionDate: 'desc',
        },
        {
          createdAt: 'desc',
        },
      ],
      select: {
        id: true,
        description: true,
        amount: true,
        type: true,
        category: true,
        accountId: true,
        transactionDate: true,
        dueDate: true,
        status: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async findOne(userId: string, transactionId: string) {
    const transaction =
      await this.prisma.financialTransaction.findFirst({
        where: {
          id: transactionId,
          userId,
        },
        select: {
          id: true,
          description: true,
          amount: true,
          type: true,
          category: true,
          accountId: true,
          transactionDate: true,
          dueDate: true,
          status: true,
          notes: true,
          createdAt: true,
          updatedAt: true,
          linkedAsPending: {
            select: {
              id: true,
              description: true,
            },
          },
          linkedAsPaid: {
            select: {
              id: true,
              description: true,
            },
          },
        },
      });

    if (!transaction) {
      throw new NotFoundException(
        'Transação financeira não encontrada.',
      );
    }

    return transaction;
  }

  async update(
    userId: string,
    transactionId: string,
    dto: UpdateTransactionDto,
  ) {
    const existingTransaction = await this.findOne(
      userId,
      transactionId,
    );

    if (
      existingTransaction.linkedAsPending ||
      existingTransaction.linkedAsPaid
    ) {
      throw new ConflictException(
        'Esta transação está vinculada a uma conta a pagar e não pode ser alterada diretamente.',
      );
    }

    if (dto.accountId !== undefined) {
      await this.ensureAccountOwnership(userId, dto.accountId);
    }

    return this.prisma.financialTransaction.update({
      where: {
        id: transactionId,
        userId,
      },
      data: {
        ...(dto.description !== undefined && {
          description: dto.description.trim(),
        }),
        ...(dto.amount !== undefined && {
          amount: dto.amount,
        }),
        ...(dto.type !== undefined && {
          type: dto.type,
        }),
        ...(dto.category !== undefined && {
          category: dto.category,
        }),
        ...(dto.accountId !== undefined && {
          accountId: dto.accountId,
        }),
        ...(dto.transactionDate !== undefined && {
          transactionDate: new Date(dto.transactionDate),
        }),
        ...(dto.dueDate !== undefined && {
          dueDate: new Date(dto.dueDate),
        }),
        ...(dto.status !== undefined && {
          status: dto.status,
        }),
        ...(dto.notes !== undefined && {
          notes: dto.notes.trim() || null,
        }),
      },
      select: {
        id: true,
        description: true,
        amount: true,
        type: true,
        category: true,
        accountId: true,
        transactionDate: true,
        dueDate: true,
        status: true,
        notes: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async remove(userId: string, transactionId: string) {
    const transaction = await this.findOne(
      userId,
      transactionId,
    );

    if (
      transaction.linkedAsPending ||
      transaction.linkedAsPaid
    ) {
      throw new ConflictException(
        'Esta transação está vinculada a uma conta a pagar e não pode ser excluída.',
      );
    }

    try {
      await this.prisma.financialTransaction.delete({
        where: {
          id: transactionId,
          userId,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2003'
      ) {
        throw new ConflictException(
          'Não foi possível excluir a transação porque existem registros financeiros vinculados.',
        );
      }

      throw error;
    }

    return {
      message: 'Transação excluída com sucesso.',
    };
  }
}
