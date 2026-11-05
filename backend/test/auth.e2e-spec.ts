
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';

describe('Autenticação (e2e)', () => {
  let app: INestApplication;
  let accessToken: string;
  let refreshToken: string;
  let rotatedRefreshToken: string;
  let registeredEmail: string;

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

    registeredEmail = `teste-${Date.now()}@finplan.com`;
  });

  afterAll(async () => {
    await app?.close();
  });

  it('deve cadastrar um usuário no PostgreSQL', async () => {
    const response = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'Usuário de Teste',
        email: registeredEmail,
        password: 'SenhaSegura123!',
      })
      .expect(201);

    expect(response.body.user).toHaveProperty('id');
    expect(response.body.user.name).toBe('Usuário de Teste');
    expect(response.body.user.email).toBe(registeredEmail);
    expect(response.body.user).not.toHaveProperty('password');
    expect(response.body.user).not.toHaveProperty('passwordHash');
  });

  it('deve autenticar o usuário e retornar os dois tokens', async () => {
    const response = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: registeredEmail,
        password: 'SenhaSegura123!',
      })
      .expect(201);

    expect(response.body.accessToken).toBeDefined();
    expect(response.body.refreshToken).toBeDefined();
    expect(response.body.tokenType).toBe('Bearer');
    expect(response.body.expiresIn).toBe('15m');
    expect(response.body.refreshExpiresAt).toBeDefined();
    expect(response.body.user.email).toBe(registeredEmail);

    accessToken = response.body.accessToken;
    refreshToken = response.body.refreshToken;
  });

  it('deve retornar os dados do usuário autenticado', async () => {
    const response = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(response.body.user.email).toBe(registeredEmail);
    expect(response.body.user.userId).toBeDefined();
    expect(response.body.message).toBeDefined();
  });

  it('não deve permitir acesso sem autenticação', async () => {
    await request(app.getHttpServer())
      .get('/auth/me')
      .expect(401);
  });

  it('deve renovar os tokens e invalidar o refresh token anterior', async () => {
    const response = await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({
        refreshToken,
      })
      .expect(201);

    expect(response.body.accessToken).toBeDefined();
    expect(response.body.refreshToken).toBeDefined();
    expect(response.body.refreshToken).not.toBe(refreshToken);
    expect(response.body.tokenType).toBe('Bearer');
    expect(response.body.expiresIn).toBe('15m');
    expect(response.body.user.email).toBe(registeredEmail);

    rotatedRefreshToken = response.body.refreshToken;
  });

  it('deve rejeitar a reutilização do refresh token anterior', async () => {
    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({
        refreshToken,
      })
      .expect(401);
  });

  it('deve revogar o novo token quando detectar reutilização do anterior', async () => {
    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({
        refreshToken: rotatedRefreshToken,
      })
      .expect(401);
  });

  it('não deve aceitar um refresh token inexistente', async () => {
    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({
        refreshToken: 'token-invalido-com-tamanho-suficiente-123456789',
      })
      .expect(401);
  });

  it('deve encerrar a sessão e revogar seu refresh token', async () => {
    const loginResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: registeredEmail,
        password: 'SenhaSegura123!',
      })
      .expect(201);

    const logoutRefreshToken = loginResponse.body.refreshToken;

    const logoutResponse = await request(app.getHttpServer())
      .post('/auth/logout')
      .send({
        refreshToken: logoutRefreshToken,
      })
      .expect(201);

    expect(logoutResponse.body.message).toBe(
      'Sessão encerrada com sucesso.',
    );

    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({
        refreshToken: logoutRefreshToken,
      })
      .expect(401);
  });
});
