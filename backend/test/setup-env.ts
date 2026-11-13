import { resolve } from 'node:path';
import { config } from 'dotenv';

// E2E tests must only use .env.test and never touch the development database.
const result = config({
  path: resolve(process.cwd(), '.env.test'),
  override: true,
  quiet: true,
});

if (result.error) {
  throw new Error('Arquivo .env.test não encontrado em backend/.');
}

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error('DATABASE_URL ausente em .env.test.');
}

const databaseName = new URL(databaseUrl).pathname.replace(/^\//, '');
if (!databaseName.endsWith('_test')) {
  throw new Error(
    `Os testes E2E exigem um banco terminado em "_test" (encontrado: "${databaseName}").`,
  );
}

if (!process.env.JWT_SECRET || Buffer.byteLength(process.env.JWT_SECRET) < 32) {
  throw new Error('JWT_SECRET em .env.test deve ter ao menos 32 bytes.');
}

process.env.NODE_ENV = 'test';
