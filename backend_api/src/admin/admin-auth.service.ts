import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AUTH_CONFIG, type AuthConfig } from '../auth/auth-config.js';
import { StatsService } from '../stats/stats.service.js';
import { ADMIN_CONFIG, type AdminConfig } from './admin-config.js';
import { verifyAdminPassword } from './admin-password.js';
import type { AdminLoginResponseDto } from './dto/admin-login.dto.js';

const ADMIN_AUDIENCE = 'smartfit-admin';
export const ADMIN_LOGIN_FAILED = 'Tên đăng nhập hoặc mật khẩu không đúng.';
export const ADMIN_SESSION_INVALID = 'Phiên quản trị không hợp lệ hoặc đã hết hạn, vui lòng đăng nhập lại.';
export const ADMIN_DISABLED = 'Trang quản trị chưa được bật trên máy chủ này.';

// Khoá ký token Admin riêng, sinh từ JWT_SECRET và mã băm mật khẩu Admin: token người dùng và token Admin không
// dùng thay nhau được (sai chữ ký → 401, không bao giờ tới bước tra user — trên Postgres id lạ sẽ thành lỗi 500);
// đổi mật khẩu Admin thì mọi phiên Admin cũ mất hiệu lực ngay.
export function adminSigningKey(jwtSecret: string, passwordHashText: string): string {
  return createHmac('sha256', jwtSecret).update(`smartfit-admin:${passwordHashText}`).digest('base64url');
}

const digest = (value: string) => createHash('sha256').update(value, 'utf8').digest();

@Injectable()
export class AdminAuthService {
  private readonly jwt: JwtService | null;

  constructor(
    @Inject(ADMIN_CONFIG) private readonly config: AdminConfig | null,
    @Inject(AUTH_CONFIG) auth: AuthConfig,
    private readonly stats: StatsService,
  ) {
    this.jwt = config
      ? new JwtService({
          secret: adminSigningKey(auth.jwtSecret, config.passwordHashText),
          signOptions: { algorithm: 'HS256', expiresIn: config.tokenTtlSeconds, audience: ADMIN_AUDIENCE, subject: config.username },
          verifyOptions: { algorithms: ['HS256'], audience: ADMIN_AUDIENCE },
        })
      : null;
  }

  get enabled(): boolean {
    return this.config !== null;
  }

  // Một câu lỗi cho cả sai tên lẫn sai mật khẩu; scrypt luôn chạy để thời gian trả lời không lộ tên đúng.
  // Không log tên hay mật khẩu đã nhập. Chống dò mật khẩu: RateLimitGuard (hạn mức `admin`) ở controller.
  async login(username: string, password: string): Promise<AdminLoginResponseDto> {
    const { config, jwt } = this.requireEnabled();
    const usernameOk = timingSafeEqual(digest(username), digest(config.username));
    const passwordOk = await verifyAdminPassword(password, config.passwordHash);
    if (!usernameOk || !passwordOk) {
      await this.stats.count('admin.login.failed');
      throw new UnauthorizedException(ADMIN_LOGIN_FAILED);
    }
    await this.stats.count('admin.login.ok');
    return { access_token: await jwt.signAsync({}), expires_in: config.tokenTtlSeconds };
  }

  // Trả tên Admin; token sai, hết hạn, ký bằng khoá khác (token người dùng, mật khẩu đã đổi) → 401.
  async authenticate(token: string): Promise<string> {
    const { config, jwt } = this.requireEnabled();
    try {
      const payload = await jwt.verifyAsync<{ sub?: unknown }>(token);
      if (payload.sub === config.username) return config.username;
    } catch {
      // rơi xuống câu lỗi chung
    }
    throw new UnauthorizedException(ADMIN_SESSION_INVALID);
  }

  private requireEnabled(): { config: AdminConfig; jwt: JwtService } {
    if (!this.config || !this.jwt) throw new NotFoundException(ADMIN_DISABLED);
    return { config: this.config, jwt: this.jwt };
  }
}
