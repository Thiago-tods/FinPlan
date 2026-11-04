
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AppModule } from '../src/app.module.js';

describe('Proteção contra força bruta (e2e)', () => {
  let app: INestApplication;

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
  });

  afterAll(async () => {
    await app?.close();
  });

  it('deve bloquear a sexta tentativa de login dentro de um minuto', async () => {
    const loginData = {
      email: 'usuario-inexistente@finplan.com',
      password: 'SenhaIncorreta123!',
    };

    for (let attempt = 1; attempt <= 5; attempt++) {
      await request(app.getHttpServer())
        .post('/auth/login')
        .send(loginData)
        .expect(401);
    }

    const blockedResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send(loginData)
      .expect(429);

    expect(blockedResponse.body).toBeDefined();
  });
});
