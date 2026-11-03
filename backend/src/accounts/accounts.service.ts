
import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { UpdateAccountDto } from './dto/update-account.dto.js';

@Injectable()
export class AccountsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateAccountDto) {
    const account = await this.prisma.bankAccount.create({
      data: {
        id: randomUUID(),
        userId,
        bankName: dto.bankName.trim(),
        nickname: dto.nickname.trim(),
        type: dto.type,
        initialBalance: dto.initialBalance,
      },
      select: {
        id: true,
        bankName: true,
        nickname: true,
        type: true,
        initialBalance: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return account;
  }

  async findAll(userId: string) {
    return this.prisma.bankAccount.findMany({
      where: { userId },
      orderBy: {
        createdAt: 'desc',
      },
      select: {
        id: true,
        bankName: true,
        nickname: true,
        type: true,
        initialBalance: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async findOne(userId: string, accountId: string) {
    const account = await this.prisma.bankAccount.findFirst({
      where: {
        id: accountId,
        userId,
      },
      select: {
        id: true,
        bankName: true,
        nickname: true,
        type: true,
        initialBalance: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Conta bancária não encontrada.');
    }

    return account;
  }

  async update(
    userId: string,
    accountId: string,
    dto: UpdateAccountDto,
  ) {
    await this.findOne(userId, accountId);

    return this.prisma.bankAccount.update({
      where: {
        id: accountId,
        userId,
      },
      data: {
        ...(dto.bankName !== undefined && {
          bankName: dto.bankName.trim(),
        }),
        ...(dto.nickname !== undefined && {
          nickname: dto.nickname.trim(),
        }),
        ...(dto.type !== undefined && {
          type: dto.type,
        }),
        ...(dto.initialBalance !== undefined && {
          initialBalance: dto.initialBalance,
        }),
      },
      select: {
        id: true,
        bankName: true,
        nickname: true,
        type: true,
        initialBalance: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async remove(userId: string, accountId: string) {
    await this.findOne(userId, accountId);

    const transactionCount = await this.prisma.financialTransaction.count({
      where: {
        accountId,
        userId,
      },
    });

    if (transactionCount > 0) {
      throw new ConflictException(
        'Esta conta possui transações vinculadas e não pode ser excluída. Preserve seu histórico financeiro.',
      );
    }

    try {
      await this.prisma.bankAccount.delete({
        where: {
          id: accountId,
          userId,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2003'
      ) {
        throw new ConflictException(
          'Não é possível excluir esta conta porque existem registros financeiros vinculados.',
        );
      }

      throw error;
    }

    return {
      message: 'Conta bancária excluída com sucesso.',
    };
  }
}
