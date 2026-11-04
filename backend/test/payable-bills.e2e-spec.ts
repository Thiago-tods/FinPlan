
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('Contas a pagar (e2e)', () => {
  let app: INestApplication;

  let tokenA: string;
  let tokenB: string;

  let accountAId: string;
  let accountBId: string;

  let transactionId: string;
  let billId: string;
  let deletableBillId: string;

  const emailA = `contas-a-${Date.now()}@finplan.com`;
  const emailB = `contas-b-${Date.now()}@finplan.com`;
  const password = 'SenhaSegura123!';

  const transactionDate = '2026-11-03T12:00:00.000Z';

  const dueDate = '2026-11-10T12:00:00.000Z';
  const discountDeadline = '2026-11-05T12:00:00.000Z';
  const paidAt = '2026-11-04T12:00:00.000Z';

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
        nickname: 'Conta Principal',
        type: 'checking',
        initialBalance: 2000,
      })
      .expect(201);

    accountAId = accountA.body.id;

    const accountB = await request(app.getHttpServer())
      .post('/accounts')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        bankName: 'Banco de Testes B',
        nickname: 'Conta Secundária',
        type: 'checking',
        initialBalance: 1000,
      })
      .expect(201);

    accountBId = accountB.body.id;

    const transaction = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Despesa pendente vinculada',
        amount: 200,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    transactionId = transaction.body.id;
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

  it('deve cadastrar uma conta a pagar vinculada a uma conta e transação pendente', async () => {
    const response = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta de energia',
        amount: 200,
        category: 'utilities',
        dueDate,
        discountDeadline,
        discountAmount: 20,
        accountId: accountAId,
        linkedPendingTransactionId: transactionId,
        notes: 'Pagamento com desconto',
      })
      .expect(201);

    expect(response.body.id).toBeDefined();
    expect(response.body.description).toBe('Conta de energia');
    expect(Number(response.body.amount)).toBe(200);
    expect(response.body.category).toBe('utilities');
    expect(response.body.status).toBe('pending');
    expect(response.body.accountId).toBe(accountAId);
    expect(response.body.linkedPendingTransactionId).toBe(transactionId);

    billId = response.body.id;
  });

  it('deve listar somente as contas a pagar do usuário', async () => {
    const response = await request(app.getHttpServer())
      .get('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].id).toBe(billId);
  });

  it('deve consultar uma conta a pagar pelo ID', async () => {
    const response = await request(app.getHttpServer())
      .get(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body.id).toBe(billId);
    expect(response.body.description).toBe('Conta de energia');
  });

  it('deve atualizar uma conta a pagar', async () => {
    const response = await request(app.getHttpServer())
      .patch(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta de energia atualizada',
        notes: 'Desconto disponível até a data limite',
      })
      .expect(200);

    expect(response.body.description).toBe(
      'Conta de energia atualizada',
    );

    expect(response.body.notes).toBe(
      'Desconto disponível até a data limite',
    );
  });

  it('não deve permitir consultar uma conta de outro usuário', async () => {
    await request(app.getHttpServer())
      .get(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve permitir atualizar uma conta de outro usuário', async () => {
    await request(app.getHttpServer())
      .patch(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        description: 'Tentativa de alteração',
      })
      .expect(404);
  });

  it('não deve permitir excluir uma conta de outro usuário', async () => {
    await request(app.getHttpServer())
      .delete(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve permitir vincular uma conta bancária de outro usuário', async () => {
    await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta com vínculo inválido',
        amount: 100,
        category: 'utilities',
        dueDate,
        accountId: accountBId,
      })
      .expect(404);
  });

  it('não deve permitir acesso sem autenticação', async () => {
    await request(app.getHttpServer())
      .get('/payable-bills')
      .expect(401);
  });

  it('deve pagar a conta aplicando o desconto e reaproveitando a transação pendente', async () => {
    await request(app.getHttpServer())
      .post(`/payable-bills/${billId}/pay`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        paidAt,
      })
      .expect(201);

    const billResponse = await request(app.getHttpServer())
      .get(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(billResponse.body.status).toBe('paid');
    expect(billResponse.body.linkedTransactionId).toBe(transactionId);

    const transactionResponse = await request(app.getHttpServer())
      .get(`/transactions/${transactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(transactionResponse.body.status).toBe('completed');
    expect(Number(transactionResponse.body.amount)).toBe(180);
  });

  it('não deve permitir pagar a mesma conta duas vezes', async () => {
    await request(app.getHttpServer())
      .post(`/payable-bills/${billId}/pay`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        paidAt,
      })
      .expect(409);
  });

  it('não deve permitir excluir uma conta já paga', async () => {
    await request(app.getHttpServer())
      .delete(`/payable-bills/${billId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(409);
  });

  it('não deve permitir pagar uma conta de outro usuário', async () => {
    await request(app.getHttpServer())
      .post(`/payable-bills/${billId}/pay`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        paidAt,
      })
      .expect(404);
  });

  it('deve permitir cadastrar e excluir uma conta ainda pendente', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta temporária',
        amount: 75,
        category: 'subscriptions',
        dueDate,
      })
      .expect(201);

    deletableBillId = createResponse.body.id;

    await request(app.getHttpServer())
      .delete(`/payable-bills/${deletableBillId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    await request(app.getHttpServer())
      .get(`/payable-bills/${deletableBillId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);
  });

  it('não deve aceitar uma conta com valor negativo', async () => {
    await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta inválida',
        amount: -50,
        category: 'utilities',
        dueDate,
      })
      .expect(400);
  });

  it('não deve aceitar desconto sem prazo de validade', async () => {
    await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Conta com desconto inválido',
        amount: 100,
        category: 'utilities',
        dueDate,
        discountAmount: 10,
      })
      .expect(409);
  });
});
