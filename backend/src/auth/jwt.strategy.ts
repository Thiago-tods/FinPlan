
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

interface JwtPayload {
  sub: string;
  email: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    const secret = process.env.JWT_SECRET;

    if (!secret || Buffer.byteLength(secret, 'utf8') < 32) {
      throw new Error(
        'JWT_SECRET deve possuir pelo menos 32 bytes.',
      );
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
      algorithms: ['HS256'],
      issuer: 'finplan-api',
      audience: 'finplan-clients',
    });
  }

  validate(payload: JwtPayload) {
    if (
      typeof payload.sub !== 'string' ||
      !payload.sub ||
      typeof payload.email !== 'string' ||
      !payload.email
    ) {
      throw new UnauthorizedException('Token inválido.');
    }

    return {
      userId: payload.sub,
      email: payload.email,
    };
  }
}
