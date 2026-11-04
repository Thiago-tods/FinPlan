
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';

describe('Autenticação (e2e)', () => {
  let app: INestApplication;
  let accessToken: string;
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

  it('deve autenticar o usuário e retornar um JWT', async () => {
    const response = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: registeredEmail,
        password: 'SenhaSegura123!',
      })
      .expect(201);

    expect(response.body.accessToken).toBeDefined();
    expect(response.body.tokenType).toBe('Bearer');
    expect(response.body.expiresIn).toBe('15m');
    expect(response.body.user.email).toBe(registeredEmail);

    accessToken = response.body.accessToken;
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
});
