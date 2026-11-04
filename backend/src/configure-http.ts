
import type { INestApplication } from '@nestjs/common';
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';
import helmet from 'helmet';

function getAllowedOrigins(): Set<string> {
  const configuredOrigins = process.env.CORS_ORIGINS ?? '';

  const origins = configuredOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (process.env.NODE_ENV === 'production' && origins.length === 0) {
    throw new Error('CORS_ORIGINS deve ser configurado em produção.');
  }

  const allowedOrigins = new Set<string>();

  for (const origin of origins) {
    if (origin === '*') {
      throw new Error('Não é permitido utilizar * em CORS_ORIGINS.');
    }

    let parsedOrigin: URL;

    try {
      parsedOrigin = new URL(origin);
    } catch {
      throw new Error(`Origem inválida em CORS_ORIGINS: ${origin}`);
    }

    if (
      !['http:', 'https:'].includes(parsedOrigin.protocol) ||
      parsedOrigin.origin !== origin
    ) {
      throw new Error(`Origem inválida em CORS_ORIGINS: ${origin}`);
    }

    allowedOrigins.add(origin);
  }

  return allowedOrigins;
}

export function configureHttp(app: INestApplication): void {
  const allowedOrigins = getAllowedOrigins();

  const corsOptions: CorsOptions = {
    origin: (origin: string | undefined, callback) => {
      if (!origin || allowedOrigins.has(origin)) {
        callback(null, true);
        return;
      }

      callback(null, false);
    },
    methods: ['GET', 'HEAD', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: false,
    optionsSuccessStatus: 204,
    maxAge: 600,
  };

  app.use(helmet());
  app.enableCors(corsOptions);
}
