import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, type Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import type { AuthResponseDto } from './dto/auth-response.dto.js';
import { IdTokenVerifier, type VerifiedIdentity } from './id-token-verifier.js';

// JWT chỉ chứa id người dùng — không email, không dữ liệu sức khoẻ.
interface AccessTokenPayload {
  sub: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly verifier: IdTokenVerifier,
    private readonly jwt: JwtService,
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  async loginWithGoogle(idToken: string): Promise<AuthResponseDto> {
    const identity = await this.verifier.verify(idToken);
    const user = await this.findOrCreateUser(identity);
    const payload: AccessTokenPayload = { sub: user.id };
    return {
      access_token: await this.jwt.signAsync(payload),
      user: { id: user.id, email: user.email, name: user.name },
    };
  }

  // Token sai, hết hạn, hoặc người dùng không còn trong DB (đã xoá tài khoản, DB bị làm mới) → 401.
  async authenticate(accessToken: string): Promise<User> {
    let payload: Partial<AccessTokenPayload>;
    try {
      payload = await this.jwt.verifyAsync<Partial<AccessTokenPayload>>(accessToken);
    } catch {
      throw new UnauthorizedException('Phiên đăng nhập không hợp lệ hoặc đã hết hạn, vui lòng đăng nhập lại.');
    }
    const user = typeof payload.sub === 'string' ? await this.users.findOneBy({ id: payload.sub }) : null;
    if (!user) {
      throw new UnauthorizedException('Tài khoản không còn tồn tại, vui lòng đăng nhập lại.');
    }
    return user;
  }

  // Xoá user; khoá ngoại ON DELETE CASCADE xoá luôn toàn bộ lịch sử.
  async deleteAccount(userId: string): Promise<void> {
    await this.users.delete({ id: userId });
  }

  private async findOrCreateUser(identity: VerifiedIdentity): Promise<User> {
    const existing = await this.users.findOneBy({ google_sub: identity.sub });
    if (existing) return existing;
    try {
      return await this.users.save(
        this.users.create({ google_sub: identity.sub, email: identity.email, name: identity.name }),
      );
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // Hai request đăng nhập lần đầu cùng lúc: request kia vừa tạo user này.
      return this.users.findOneByOrFail({ google_sub: identity.sub });
    }
  }
}

// SQLite: SQLITE_CONSTRAINT_UNIQUE; Postgres (nếu sau này đổi DB, #11): 23505.
function isUniqueViolation(error: unknown): boolean {
  if (!(error instanceof QueryFailedError)) return false;
  const code = (error.driverError as { code?: string } | undefined)?.code;
  return code === 'SQLITE_CONSTRAINT_UNIQUE' || code === '23505';
}
