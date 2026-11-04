
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { PrismaModule } from '../prisma/prisma.module.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { JwtStrategy } from './jwt.strategy.js';

@Module({
  imports: [
    PrismaModule,
    PassportModule.register({
      defaultStrategy: 'jwt',
    }),
    JwtModule.registerAsync({
      useFactory: () => {
        const secret = process.env.JWT_SECRET;

        if (!secret || Buffer.byteLength(secret, 'utf8') < 32) {
          throw new Error(
            'JWT_SECRET deve possuir pelo menos 32 bytes.',
          );
        }

        return {
          secret,
          signOptions: {
            algorithm: 'HS256',
            expiresIn: '15m',
            issuer: 'finplan-api',
            audience: 'finplan-clients',
          },
        };
      },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
})
export class AuthModule {}
