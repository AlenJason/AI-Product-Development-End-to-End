import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, type Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import type { AuthResponseDto } from './dto/auth-response.dto.js';
import type { ChangePasswordDto } from './dto/change-password.dto.js';
import type { LoginDto } from './dto/login.dto.js';
import type { RegisterDto } from './dto/register.dto.js';
import { IdTokenVerifier, type VerifiedIdentity } from './id-token-verifier.js';
import { hashPassword, verifyPassword } from './password.util.js';

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

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const email = dto.email.trim().toLowerCase();
    const name = dto.name.trim();
    if (!name) throw new BadRequestException('Họ tên không được để trống.');

    const existing = await this.users.findOneBy({ email });
    if (existing) throw new ConflictException('Email này đã được đăng ký.');

    try {
      const user = await this.users.save(
        this.users.create({
          email,
          name,
          password_hash: hashPassword(dto.password),
        }),
      );
      return this.buildAuthResponse(user);
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictException('Email này đã được đăng ký.');
      }
      throw error;
    }
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const email = dto.email.trim().toLowerCase();
    const user = await this.users.findOneBy({ email });
    if (!user?.password_hash || !verifyPassword(dto.password, user.password_hash)) {
      throw new UnauthorizedException('Email hoặc mật khẩu không đúng.');
    }
    return this.buildAuthResponse(user);
  }

  async changePassword(userId: string, dto: ChangePasswordDto): Promise<{ message: string }> {
    const user = await this.users.findOneBy({ id: userId });
    if (!user) throw new UnauthorizedException('Tài khoản không tồn tại.');
    if (!user.password_hash) {
      throw new BadRequestException('Tài khoản này chưa thiết lập mật khẩu.');
    }
    if (!verifyPassword(dto.current_password, user.password_hash)) {
      throw new UnauthorizedException('Mật khẩu hiện tại không đúng.');
    }
    await this.users.update({ id: user.id }, { password_hash: hashPassword(dto.new_password) });
    return { message: 'Đổi mật khẩu thành công.' };
  }

  async loginWithGoogle(idToken: string): Promise<AuthResponseDto> {
    const identity = await this.verifier.verify(idToken);
    const user = await this.findOrCreateUser(identity);
    return this.buildAuthResponse(user);
  }

  private async buildAuthResponse(user: User): Promise<AuthResponseDto> {
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
    const email = identity.email.toLowerCase();
    const existing = await this.users.findOneBy({ email });
    if (existing) return existing;
    try {
      return await this.users.save(
        this.users.create({
          email,
          name: identity.name,
          password_hash: null,
        }),
      );
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // Hai request đăng nhập lần đầu cùng lúc: request kia vừa tạo user này.
      return this.users.findOneByOrFail({ email });
    }
  }
}

// SQLite: SQLITE_CONSTRAINT_UNIQUE; MySQL: ER_DUP_ENTRY; Postgres (nếu sau này đổi DB, #11): 23505.
function isUniqueViolation(error: unknown): boolean {
  if (!(error instanceof QueryFailedError)) return false;
  const code = (error.driverError as { code?: string } | undefined)?.code;
  return code === 'SQLITE_CONSTRAINT_UNIQUE' || code === 'ER_DUP_ENTRY' || code === '23505';
}
