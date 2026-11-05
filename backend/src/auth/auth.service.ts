
import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '../generated/prisma/client.js';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service.js';
import { LoginDto } from './dto/login.dto.js';
import { RefreshTokenDto } from './dto/refresh-token.dto.js';
import { RegisterDto } from './dto/register.dto.js';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  private readonly refreshTokenLifetime = 30 * 24 * 60 * 60 * 1000;

  private generateRefreshToken(): string {
    return randomBytes(32).toString('base64url');
  }

  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async generateAccessToken(user: {
    id: string;
    email: string;
  }): Promise<string> {
    return this.jwtService.signAsync({
      sub: user.id,
      email: user.email,
    });
  }

  private getRefreshExpiration(): Date {
    return new Date(Date.now() + this.refreshTokenLifetime);
  }

  async register(registerDto: RegisterDto) {
    const name = registerDto.name.trim();
    const email = registerDto.email.trim().toLowerCase();

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      throw new ConflictException('Este e-mail já está cadastrado.');
    }

    const passwordHash = await argon2.hash(registerDto.password, {
      type: argon2.argon2id,
    });

    try {
      const user = await this.prisma.user.create({
        data: {
          name,
          email,
          passwordHash,
        },
        select: {
          id: true,
          name: true,
          email: true,
          createdAt: true,
        },
      });

      return {
        message: 'Usuário cadastrado com sucesso.',
        user,
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Este e-mail já está cadastrado.');
      }

      throw new InternalServerErrorException(
        'Não foi possível realizar o cadastro.',
      );
    }
  }

  async login(loginDto: LoginDto) {
    const email = loginDto.email.trim().toLowerCase();

    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw new UnauthorizedException('E-mail ou senha incorretos.');
    }

    const passwordIsValid = await argon2.verify(
      user.passwordHash,
      loginDto.password,
    );

    if (!passwordIsValid) {
      throw new UnauthorizedException('E-mail ou senha incorretos.');
    }

    const accessToken = await this.generateAccessToken(user);
    const refreshToken = this.generateRefreshToken();
    const refreshExpiresAt = this.getRefreshExpiration();

    await this.prisma.authSession.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        tokenHash: this.hashRefreshToken(refreshToken),
        expiresAt: refreshExpiresAt,
      },
    });

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: '15m',
      refreshExpiresAt: refreshExpiresAt.toISOString(),
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
    };
  }

  async refresh(refreshTokenDto: RefreshTokenDto) {
    const tokenHash = this.hashRefreshToken(
      refreshTokenDto.refreshToken,
    );

    const session = await this.prisma.authSession.findUnique({
      where: { tokenHash },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    if (!session) {
      throw new UnauthorizedException('Refresh token inválido.');
    }

    if (session.revokedAt || session.expiresAt <= new Date()) {
      await this.prisma.authSession.updateMany({
        where: {
          familyId: session.familyId,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });

      throw new UnauthorizedException(
        'Sessão inválida ou expirada. Entre novamente.',
      );
    }

    const newRefreshToken = this.generateRefreshToken();
    const newTokenHash = this.hashRefreshToken(newRefreshToken);
    const newSessionId = randomUUID();
    const now = new Date();
    const refreshExpiresAt = this.getRefreshExpiration();
    const accessToken = await this.generateAccessToken(session.user);

    const rotation = await this.prisma.$transaction(async (tx) => {
      const updateResult = await tx.authSession.updateMany({
        where: {
          id: session.id,
          revokedAt: null,
          expiresAt: {
            gt: now,
          },
        },
        data: {
          revokedAt: now,
          replacedByTokenId: newSessionId,
        },
      });

      if (updateResult.count !== 1) {
        return false;
      }

      await tx.authSession.create({
        data: {
          id: newSessionId,
          userId: session.userId,
          familyId: session.familyId,
          tokenHash: newTokenHash,
          expiresAt: refreshExpiresAt,
        },
      });

      return true;
    });

    if (!rotation) {
      await this.prisma.authSession.updateMany({
        where: {
          familyId: session.familyId,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });

      throw new UnauthorizedException(
        'Refresh token já utilizado. Entre novamente.',
      );
    }

    return {
      accessToken,
      refreshToken: newRefreshToken,
      tokenType: 'Bearer',
      expiresIn: '15m',
      refreshExpiresAt: refreshExpiresAt.toISOString(),
      user: session.user,
    };
  }

  async logout(refreshTokenDto: RefreshTokenDto) {
    const tokenHash = this.hashRefreshToken(
      refreshTokenDto.refreshToken,
    );

    const session = await this.prisma.authSession.findUnique({
      where: { tokenHash },
      select: {
        familyId: true,
      },
    });

    if (session) {
      await this.prisma.authSession.updateMany({
        where: {
          familyId: session.familyId,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });
    }

    return {
      message: 'Sessão encerrada com sucesso.',
    };
  }
}
