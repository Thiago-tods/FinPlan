import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types.js';
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
} from 'vitest';

import { AppModule } from '../src/app.module.js';
import { configureHttp } from '../src/configure-http.js';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;
  let originalCorsOrigins: string | undefined;

  const allowedOrigin = 'http://localhost:5173';
  const deniedOrigin = 'https://site-nao-autorizado.com';

  beforeEach(async () => {
    originalCorsOrigins = process.env.CORS_ORIGINS;
    process.env.CORS_ORIGINS = allowedOrigin;

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    configureHttp(app);

    await app.init();
  });

  it('deve responder a rota principal', async () => {
    await request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect('Hello World!');
  });

  it('deve enviar os cabeçalhos HTTP de segurança do Helmet', async () => {
    const response = await request(app.getHttpServer())
      .get('/')
      .expect(200);

    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(response.headers['content-security-policy']).toBeDefined();
  });

  it('deve permitir uma origem autorizada pelo CORS', async () => {
    const response = await request(app.getHttpServer())
      .get('/')
      .set('Origin', allowedOrigin)
      .expect(200);

    expect(response.headers['access-control-allow-origin']).toBe(
      allowedOrigin,
    );
  });

  it('não deve autorizar uma origem não cadastrada no CORS', async () => {
    const response = await request(app.getHttpServer())
      .get('/')
      .set('Origin', deniedOrigin)
      .expect(200);

    expect(response.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('deve permitir preflight OPTIONS para uma origem autorizada', async () => {
    const response = await request(app.getHttpServer())
      .options('/')
      .set('Origin', allowedOrigin)
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'authorization,content-type')
      .expect(204);

    expect(response.headers['access-control-allow-origin']).toBe(
      allowedOrigin,
    );

    expect(response.headers['access-control-allow-methods']).toContain(
      'POST',
    );
  });

  afterEach(async () => {
    await app.close();

    if (originalCorsOrigins === undefined) {
      delete process.env.CORS_ORIGINS;
    } else {
      process.env.CORS_ORIGINS = originalCorsOrigins;
    }
  });
});
