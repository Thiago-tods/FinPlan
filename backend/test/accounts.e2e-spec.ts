
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('Contas bancárias (e2e)', () => {
  let app: INestApplication;

  let tokenA: string;
  let tokenB: string;

  let accountId: string;

  const emailA = `conta-a-${Date.now()}@finplan.com`;
  const emailB = `conta-b-${Date.now()}@finplan.com`;
  const password = 'SenhaSegura123!';

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

  it('deve criar uma conta bancária', async () => {
    const response = await request(app.getHttpServer())
      .post('/accounts')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        bankName: 'Banco de Testes',
        nickname: 'Conta Principal',
        type: 'checking',
        initialBalance: 1500.50,
      })
      .expect(201);

    expect(response.body.id).toBeDefined();
    expect(response.body.bankName).toBe('Banco de Testes');
    expect(response.body.nickname).toBe('Conta Principal');
    expect(response.body.type).toBe('checking');
    expect(Number(response.body.initialBalance)).toBe(1500.50);

    accountId = response.body.id;
  });

  it('deve listar somente as contas do usuário autenticado', async () => {
    const response = await request(app.getHttpServer())
      .get('/accounts')
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].id).toBe(accountId);
  });

  it('deve consultar uma conta pelo ID', async () => {
    const response = await request(app.getHttpServer())
      .get(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body.id).toBe(accountId);
    expect(response.body.bankName).toBe('Banco de Testes');
  });

  it('deve atualizar os dados da conta', async () => {
    const response = await request(app.getHttpServer())
      .patch(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        bankName: 'Banco Atualizado',
        nickname: 'Conta Principal Atualizada',
        type: 'savings',
        initialBalance: 2500,
      })
      .expect(200);

    expect(response.body.bankName).toBe('Banco Atualizado');
    expect(response.body.nickname).toBe('Conta Principal Atualizada');
    expect(response.body.type).toBe('savings');
    expect(Number(response.body.initialBalance)).toBe(2500);
  });

  it('não deve permitir que outro usuário consulte a conta', async () => {
    await request(app.getHttpServer())
      .get(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve permitir que outro usuário atualize a conta', async () => {
    await request(app.getHttpServer())
      .patch(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        nickname: 'Tentativa de invasão',
      })
      .expect(404);
  });

  it('não deve permitir que outro usuário exclua a conta', async () => {
    await request(app.getHttpServer())
      .delete(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(404);
  });

  it('não deve listar contas pertencentes a outro usuário', async () => {
    const response = await request(app.getHttpServer())
      .get('/accounts')
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(200);

    expect(response.body).toHaveLength(0);
  });

  it('não deve permitir acesso sem autenticação', async () => {
    await request(app.getHttpServer())
      .get('/accounts')
      .expect(401);
  });

  it('deve excluir a conta do próprio usuário', async () => {
    const response = await request(app.getHttpServer())
      .delete(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200);

    expect(response.body.message).toBe(
      'Conta bancária excluída com sucesso.',
    );

    await request(app.getHttpServer())
      .get(`/accounts/${accountId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);
  });
});
