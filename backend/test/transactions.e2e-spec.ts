
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('Transações financeiras (e2e)', () => {
  let app: INestApplication;

  let tokenA: string;
  let tokenB: string;

  let accountAId: string;
  let accountBId: string;
  let transactionId: string;

  const emailA = `transacao-a-${Date.now()}@finplan.com`;
  const emailB = `transacao-b-${Date.now()}@finplan.com`;
  const password = 'SenhaSegura123!';

  const transactionDate = '2026-11-03T12:00:00.000Z';

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );

    await app.init();

    const registerAndLogin = async (email: string, name: string) => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          name,
          email,
          password,
        })
        .expect(201);

      const response = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email,
          password,
        })
        .expect(201);

      return response.body.accessToken as string;
    };

    tokenA = await registerAndLogin(emailA, 'Usuário A');
    tokenB = await registerAndLogin(emailB, 'Usuário B');

    const accountA = await request(app.getHttpServer())
      .post('/accounts')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        bankName: 'Banco de Testes A',
        nickname: 'Conta A',
        type: 'checking',
        initialBalance: 1000,
      })
      .expect(201);

    accountAId = accountA.body.id;

    const accountB = await request(app.getHttpServer())
      .post('/accounts')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        bankName: 'Banco de Testes B',
        nickname: 'Conta B',
        type: 'checking',
        initialBalance: 500,
      })
      .expect(201);

    accountBId = accountB.body.id;
  });

  afterAll(async () => {
    if (!app) {
      return;
    }

    try {
      const prisma = app.get(PrismaService);

      const users = await prisma.user.findMany({
        where: {
          email: {
            in: [emailA, emailB],
          },
        },
        select: {
          id: true,
        },
      });

      const userIds = users.map((user) => user.id);

      if (userIds.length > 0) {
        await prisma.payableBill.deleteMany({
          where: { userId: { in: userIds } },
        });

        await prisma.financialTransaction.deleteMany({
          where: { userId: { in: userIds } },
        });

        await prisma.bankAccount.deleteMany({
          where: { userId: { in: userIds } },
        });

        await prisma.user.deleteMany({
          where: { id: { in: userIds } },
        });
      }
    } finally {
      await app.close();
    }
  });

  it('deve criar uma despesa vinculada à conta do usuário', async () => {
    const response = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Compra de supermercado',
        amount: 150.75,
        type: 'expense',
        category: 'food',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
        notes: 'Compra para o mês',
      })
      .expect(201);

    expect(response.body.id).toBeDefined();
    expect(response.body.description).toBe('Compra de supermercado');
    expect(Number(response.body.amount)).toBe(150.75);
    expect(response.body.type).toBe('expense');
    expect(response.body.category).toBe('food');
    expect(response.body.accountId).toBe(accountAId);
    expect(response.body.status).toBe('pending');

    transactionId = response.body.id;
  });

  it('deve listar somente as transações do usuário autenticado', async () => {
    const response = await request(app.getHttpServer())
      .get('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].id).toBe(transactionId);
  });

  it('deve consultar uma transação pelo ID', async () => {
    const response = await request(app.getHttpServer())
      .get(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body.id).toBe(transactionId);
    expect(response.body.description).toBe('Compra de supermercado');
  });

  it('deve atualizar uma transação', async () => {
    const response = await request(app.getHttpServer())
      .patch(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Compra atualizada',
        amount: 175.50,
        category: 'shopping',
        status: 'completed',
        notes: 'Valor atualizado',
      })
      .expect(200);

    expect(response.body.description).toBe('Compra atualizada');
    expect(Number(response.body.amount)).toBe(175.50);
    expect(response.body.category).toBe('shopping');
    expect(response.body.status).toBe('completed');
    expect(response.body.notes).toBe('Valor atualizado');
  });

  it('não deve permitir transações com conta de outro usuário', async () => {
    await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Tentativa de usar conta alheia',
        amount: 100,
        type: 'expense',
        category: 'other',
        accountId: accountBId,
        transactionDate,
      })
      .expect(404);
  });

  it('não deve permitir que outro usuário consulte a transação', async () => {
    await request(app.getHttpServer())
      .get(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve permitir que outro usuário atualize a transação', async () => {
    await request(app.getHttpServer())
      .patch(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        description: 'Tentativa de alteração',
      })
      .expect(404);
  });

  it('não deve permitir que outro usuário exclua a transação', async () => {
    await request(app.getHttpServer())
      .delete(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve permitir acesso sem autenticação', async () => {
    await request(app.getHttpServer())
      .get('/transactions')
      .expect(401);
  });

  it('não deve permitir excluir uma conta que possui transações', async () => {
    await request(app.getHttpServer())
      .delete(`/accounts/${accountAId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(409);
  });

  it('deve excluir uma transação do próprio usuário', async () => {
    await request(app.getHttpServer())
      .delete(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    await request(app.getHttpServer())
      .get(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);
  });

  it('deve permitir excluir a conta depois que a transação for excluída', async () => {
    await request(app.getHttpServer())
      .delete(`/accounts/${accountAId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);
  });

  it('não deve aceitar valores de transação inválidos', async () => {
    await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Transação inválida',
        amount: -10,
        type: 'expense',
        category: 'food',
        accountId: accountAId,
        transactionDate,
      })
      .expect(400);
  });
});
