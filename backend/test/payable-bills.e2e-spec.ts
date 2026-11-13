
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

  it('não deve registrar duas despesas quando o mesmo boleto é pago simultaneamente', async () => {
    const billResponse = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Boleto para teste de concorrência',
        amount: 250,
        category: 'utilities',
        dueDate,
        accountId: accountAId,
      })
      .expect(201);

    const concurrentBillId = billResponse.body.id;

    const paymentRequests = await Promise.all([
      request(app.getHttpServer())
        .post(`/payable-bills/${concurrentBillId}/pay`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ paidAt }),

      request(app.getHttpServer())
        .post(`/payable-bills/${concurrentBillId}/pay`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ paidAt }),
    ]);

    const successfulPayments = paymentRequests.filter(
      (response) => response.status === 201,
    );

    const rejectedPayments = paymentRequests.filter(
      (response) => response.status === 409,
    );

    expect(successfulPayments).toHaveLength(1);
    expect(rejectedPayments).toHaveLength(1);

    const prisma = app.get(PrismaService);

    const user = await prisma.user.findUniqueOrThrow({
      where: { email: emailA },
    });

    const bill = await prisma.payableBill.findUnique({
      where: { id: concurrentBillId },
    });

    expect(bill?.status).toBe('paid');

    const transactions = await prisma.financialTransaction.findMany({
      where: {
        userId: user.id,
        description: 'Boleto para teste de concorrência',
        accountId: accountAId,
        status: 'completed',
        type: 'expense',
      },
    });

    expect(transactions).toHaveLength(1);
    expect(Number(transactions[0].amount)).toBe(250);
  });

  it('não deve duplicar uma transação pendente vinculada em pagamentos simultâneos', async () => {
    const prisma = app.get(PrismaService);

    const user = await prisma.user.findUniqueOrThrow({
      where: { email: emailA },
    });

    const transactionResponse = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Despesa vinculada para teste de concorrência',
        amount: 300,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    const linkedTransactionId = transactionResponse.body.id;

    const billResponse = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Boleto vinculado para teste de concorrência',
        amount: 300,
        category: 'utilities',
        dueDate,
        accountId: accountAId,
        linkedPendingTransactionId: linkedTransactionId,
      })
      .expect(201);

    const concurrentBillId = billResponse.body.id;

    const paymentRequests = await Promise.all([
      request(app.getHttpServer())
        .post(`/payable-bills/${concurrentBillId}/pay`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ paidAt }),

      request(app.getHttpServer())
        .post(`/payable-bills/${concurrentBillId}/pay`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ paidAt }),
    ]);

    const successfulPayments = paymentRequests.filter(
      (response) => response.status === 201,
    );

    const rejectedPayments = paymentRequests.filter(
      (response) => response.status === 409,
    );

    expect(successfulPayments).toHaveLength(1);
    expect(rejectedPayments).toHaveLength(1);

    const bill = await prisma.payableBill.findUnique({
      where: { id: concurrentBillId },
    });

    expect(bill?.status).toBe('paid');
    expect(bill?.linkedTransactionId).toBe(linkedTransactionId);
    expect(bill?.linkedPendingTransactionId).toBeNull();

    const originalTransaction = await prisma.financialTransaction.findUnique({
      where: { id: linkedTransactionId },
    });

    expect(originalTransaction?.status).toBe('completed');
    expect(Number(originalTransaction?.amount)).toBe(300);

    const transactions = await prisma.financialTransaction.findMany({
      where: {
        userId: user.id,
        description: 'Despesa vinculada para teste de concorrência',
        accountId: accountAId,
        status: 'completed',
        type: 'expense',
      },
    });

    expect(transactions).toHaveLength(1);
    expect(transactions[0].id).toBe(linkedTransactionId);
    expect(Number(transactions[0].amount)).toBe(300);
  });

  it('deve manter a transação pendente e desvinculá-la ao cancelar um boleto', async () => {
    const transactionResponse = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Despesa pendente para cancelamento',
        amount: 150,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    const linkedTransactionId = transactionResponse.body.id;

    const billResponse = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Boleto para teste de cancelamento',
        amount: 150,
        category: 'utilities',
        dueDate,
        accountId: accountAId,
        linkedPendingTransactionId: linkedTransactionId,
      })
      .expect(201);

    const createdBillId = billResponse.body.id;

    await request(app.getHttpServer())
      .post(`/payable-bills/${createdBillId}/cancel`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(201);

    const updatedBill = await request(app.getHttpServer())
      .get(`/payable-bills/${createdBillId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(updatedBill.body.status).toBe('cancelled');
    expect(updatedBill.body.linkedPendingTransactionId).toBeNull();

    const updatedTransaction = await request(app.getHttpServer())
      .get(`/transactions/${linkedTransactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(updatedTransaction.body.status).toBe('pending');

    const prisma = app.get(PrismaService);

    const remainingLink = await prisma.payableBill.findFirst({
      where: {
        linkedPendingTransactionId: linkedTransactionId,
      },
    });

    expect(remainingLink).toBeNull();
  });

  it('deve manter a transação pendente e desvinculá-la ao excluir um boleto', async () => {
    const transactionResponse = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Despesa pendente para exclusão',
        amount: 175,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    const linkedTransactionId = transactionResponse.body.id;

    const billResponse = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Boleto para teste de exclusão',
        amount: 175,
        category: 'utilities',
        dueDate,
        accountId: accountAId,
        linkedPendingTransactionId: linkedTransactionId,
      })
      .expect(201);

    const createdBillId = billResponse.body.id;

    await request(app.getHttpServer())
      .delete(`/payable-bills/${createdBillId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    await request(app.getHttpServer())
      .get(`/payable-bills/${createdBillId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);

    const updatedTransaction = await request(app.getHttpServer())
      .get(`/transactions/${linkedTransactionId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(updatedTransaction.body.status).toBe('pending');

    const prisma = app.get(PrismaService);

    const remainingLink = await prisma.payableBill.findFirst({
      where: {
        linkedPendingTransactionId: linkedTransactionId,
      },
    });

    expect(remainingLink).toBeNull();
  });

  it('não deve permitir vincular a mesma transação pendente em duas criações simultâneas', async () => {
    const transactionResponse = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Transação para criação concorrente',
        amount: 200,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    const linkedTransactionId = transactionResponse.body.id;

    const createRequests = await Promise.all([
      request(app.getHttpServer())
        .post('/payable-bills')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          description: 'Primeiro boleto concorrente',
          amount: 200,
          category: 'utilities',
          dueDate,
          accountId: accountAId,
          linkedPendingTransactionId: linkedTransactionId,
        }),

      request(app.getHttpServer())
        .post('/payable-bills')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          description: 'Segundo boleto concorrente',
          amount: 200,
          category: 'utilities',
          dueDate,
          accountId: accountAId,
          linkedPendingTransactionId: linkedTransactionId,
        }),
    ]);

    expect(createRequests.filter((response) => response.status === 201))
      .toHaveLength(1);

    expect(createRequests.filter((response) => response.status === 409))
      .toHaveLength(1);

    const prisma = app.get(PrismaService);

    const linkedBills = await prisma.payableBill.findMany({
      where: {
        linkedPendingTransactionId: linkedTransactionId,
      },
    });

    expect(linkedBills).toHaveLength(1);
  });

  it('não deve permitir vincular a mesma transação pendente em duas atualizações simultâneas', async () => {
    const transactionResponse = await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Transação para atualização concorrente',
        amount: 250,
        type: 'expense',
        category: 'bills',
        accountId: accountAId,
        transactionDate,
        status: 'pending',
      })
      .expect(201);

    const linkedTransactionId = transactionResponse.body.id;

    const firstBill = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Primeiro boleto para atualização',
        amount: 250,
        category: 'utilities',
        dueDate,
      })
      .expect(201);

    const secondBill = await request(app.getHttpServer())
      .post('/payable-bills')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        description: 'Segundo boleto para atualização',
        amount: 250,
        category: 'utilities',
        dueDate,
      })
      .expect(201);

    const updateRequests = await Promise.all([
      request(app.getHttpServer())
        .patch(`/payable-bills/${firstBill.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          accountId: accountAId,
          linkedPendingTransactionId: linkedTransactionId,
        }),

      request(app.getHttpServer())
        .patch(`/payable-bills/${secondBill.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          accountId: accountAId,
          linkedPendingTransactionId: linkedTransactionId,
        }),
    ]);

    expect(updateRequests.filter((response) => response.status === 200))
      .toHaveLength(1);

    expect(updateRequests.filter((response) => response.status === 409))
      .toHaveLength(1);

    const prisma = app.get(PrismaService);

    const linkedBills = await prisma.payableBill.findMany({
      where: {
        linkedPendingTransactionId: linkedTransactionId,
      },
    });

    expect(linkedBills).toHaveLength(1);
  });

});
