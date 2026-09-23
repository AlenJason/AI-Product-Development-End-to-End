import { Logger, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client, type TokenPayload } from 'google-auth-library';

export interface VerifiedIdentity {
  sub: string;
  email: string;
  name: string;
}

// Token DI: AuthModule chọn bản mock hoặc google theo AUTH_MODE; test thay được bằng bản giả (#17).
export abstract class IdTokenVerifier {
  // Token không hợp lệ → UnauthorizedException.
  abstract verify(idToken: string): Promise<VerifiedIdentity>;
}

const MOCK_TOKEN_PATTERN = /^mock:([^\s@]{1,64}@[^\s@]+\.[^\s@]+)$/;
const MAX_EMAIL_LENGTH = 254;

// AUTH_MODE=mock: id_token là "mock:<email>", không gọi Google.
export class MockIdTokenVerifier extends IdTokenVerifier {
  async verify(idToken: string): Promise<VerifiedIdentity> {
    const match = MOCK_TOKEN_PATTERN.exec(idToken.trim());
    if (!match || match[1].length > MAX_EMAIL_LENGTH) {
      throw new UnauthorizedException('Chế độ đăng nhập giả lập: id_token phải có dạng "mock:<email>".');
    }
    const email = match[1].toLowerCase();
    return { sub: `mock:${email}`, email, name: email.split('@')[0] };
  }
}

// AUTH_MODE=google: kiểm chữ ký, hạn dùng, issuer và audience của Google ID Token.
export class GoogleIdTokenVerifier extends IdTokenVerifier {
  private readonly logger = new Logger(GoogleIdTokenVerifier.name);

  constructor(
    private readonly clientIds: string[],
    private readonly client = new OAuth2Client(),
  ) {
    super();
    // Thiếu audience, thư viện chấp nhận cả token Google cấp cho app khác.
    if (clientIds.length === 0) throw new Error('GoogleIdTokenVerifier cần ít nhất một Client ID.');
  }

  async verify(idToken: string): Promise<VerifiedIdentity> {
    let payload: TokenPayload | undefined;
    try {
      const ticket = await this.client.verifyIdToken({ idToken, audience: this.clientIds });
      payload = ticket.getPayload();
    } catch (error) {
      this.logger.warn(`Từ chối Google ID Token: ${safeReason(error)}`);
      throw new UnauthorizedException('Không xác minh được tài khoản Google.');
    }
    if (!payload?.sub || !payload.email || payload.email_verified !== true) {
      throw new UnauthorizedException('Tài khoản Google chưa xác minh email.');
    }
    const email = payload.email.toLowerCase();
    return { sub: payload.sub, email, name: payload.name?.trim() || email.split('@')[0] };
  }
}

// Thông báo lỗi của google-auth-library chép nguyên token và payload (có email) sau dấu ":" —
// chỉ giữ phần trước đó (NFR-7).
function safeReason(error: unknown): string {
  if (!(error instanceof Error)) return 'lỗi không xác định';
  return error.message.split(':')[0].slice(0, 120);
}
