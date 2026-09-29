# F02 — Đăng nhập: `AUTH_MODE=mock|google`, JWT, guard, xoá tài khoản

## Feature

`POST /api/v1/auth/google` đổi ID Token lấy JWT của SmartFit (BRD FR-6, mục 6.3). `DELETE /api/v1/me` xoá tài khoản cùng toàn bộ lịch sử (FR-6.4 mới, quyết định Q4). Kèm theo: hai guard (bắt buộc / tuỳ chọn) cho F03, `/health` báo `auth_mode`, Swagger có nút **Authorize**.

Hai chế độ, chọn bằng `AUTH_MODE` lúc khởi động:

- `mock` (mặc định): `id_token` là `mock:<email>`, không gọi Google. Tạo user, phát JWT, lưu lịch sử vẫn chạy thật.
- `google`: `google-auth-library` kiểm chữ ký, hạn dùng, issuer, `aud` = `GOOGLE_CLIENT_ID` và `email_verified`.

Cấu hình được kiểm lúc khởi động (`resolveAuthConfig()`); sai thì backend không lên và in lý do:

| Điều kiện | Kết quả |
|---|---|
| `AUTH_MODE` khác `mock`/`google` | không khởi động |
| `google` thiếu `GOOGLE_CLIENT_ID` hoặc `JWT_SECRET` < 32 ký tự | không khởi động |
| `mock` + `NODE_ENV=production`, không có `ALLOW_MOCK_AUTH=true` | không khởi động (quyết định Q3) |
| `mock`, không có `JWT_SECRET` | dùng secret mặc định, log cảnh báo |
| `JWT_EXPIRES_IN` không có dạng `<số dương><s|m|h|d>` | không khởi động |

Những điều đã kiểm chứng khi lập plan, bằng `google-auth-library` 11.1.0 thật và khoá RSA tự tạo, không gọi mạng:

- **Không truyền `audience` thì `verifyIdToken()` chấp nhận cả token Google cấp cho app khác.** `GoogleIdTokenVerifier` từ chối được tạo khi danh sách Client ID rỗng, và test khoá hành vi này.
- Thông báo lỗi của thư viện chép nguyên token hoặc payload (có email) sau dấu `:`, ví dụ `Token used too late, … : {"email":…}`. Code chỉ log phần trước dấu `:` (NFR-7).
- Test offline được: thay `getFederatedSignonCertsAsync()` bằng khoá công khai tự tạo. Phần kiểm chữ ký, hạn dùng, issuer, audience vẫn là code thật của thư viện.
- `@nestjs/jwt` 12 khai báo `expiresIn` kiểu `StringValue | number` (kiểu của gói `ms`), nên một `string` đọc từ `.env` không qua được `tsc`. Code tự đổi `7d` ra số giây, và kiểm luôn định dạng lúc khởi động.
- Đăng nhập lần đầu đồng thời → `QueryFailedError`, `driverError.code = 'SQLITE_CONSTRAINT_UNIQUE'` → đọc lại user.

## Scope

API:

- `backend_api/package.json`, `backend_api/package-lock.json` — thêm `@nestjs/jwt`, `google-auth-library`
- `backend_api/src/auth/auth-config.ts` + `auth-config.spec.ts` (mới)
- `backend_api/src/auth/id-token-verifier.ts` + `id-token-verifier.spec.ts` (mới)
- `backend_api/src/auth/auth.service.ts` + `auth.service.spec.ts` (mới)
- `backend_api/src/auth/jwt-auth.guard.ts` + `jwt-auth.guard.spec.ts` (mới)
- `backend_api/src/auth/dto/google-login.dto.ts`, `dto/auth-response.dto.ts` (mới)
- `backend_api/src/auth/auth.controller.ts`, `auth.module.ts` (mới)
- `backend_api/test/auth.e2e-spec.ts` (mới)
- `backend_api/src/app.module.ts`, `app.service.ts`, `app.controller.ts`, `app.controller.spec.ts`, `app.setup.ts`
- `backend_api/test/app.e2e-spec.ts`, `backend_api/.env.example`

## Implementation

### API Routes

| Route | Thành công | Lỗi | Latency |
|---|---|---|---|
| `POST /api/v1/auth/google` `{ id_token }` | 200 `{ access_token, user: { id, email, name } }` | 400 `id_token` thiếu/không phải chuỗi/dài hơn 4096; 401 token không xác minh được | mock: ~2 ms (đo khi lập plan). google: lần đầu tải chứng chỉ Google (~100–300 ms), sau đó thư viện cache theo `Cache-Control` và xác minh tại chỗ < 5 ms. 1–2 truy vấn DB |
| `DELETE /api/v1/me` | 204 | 401 | < 5 ms |
| `GET /health` | 200, thêm `auth_mode` | — | < 1 ms |

**Auth check:** `DELETE /api/v1/me` gắn `@UseGuards(JwtAuthGuard)` ngay tại handler. Guard chạy trước `ValidationPipe`, nên request không đăng nhập luôn nhận 401 trước mọi lỗi 400.

**Token validation (dịch vụ ngoài):**

- ID Token Google: chữ ký (khoá công khai Google), `exp`/`iat`, `iss` ∈ {`accounts.google.com`, `https://accounts.google.com`}, `aud` ∈ `GOOGLE_CLIENT_ID` (luôn truyền), `email_verified === true`. Định danh bằng `sub`, không bằng email — đúng khuyến nghị của Google (developers.google.com/identity/gsi/web/guides/verify-google-id-token).
- JWT của SmartFit: chỉ nhận `HS256`, hết hạn theo `JWT_EXPIRES_IN` (mặc định 7 ngày), payload chỉ có `sub` = id người dùng. Token hợp lệ nhưng user không còn trong DB → 401 (brainstorm F7).

### UI Components

Không có. Swagger UI có nút **Authorize** (`addBearerAuth()`), dán `access_token` vào đó là thử được các API cần đăng nhập.

### DB / KV Changes

Không đổi schema (dùng bảng của F01). Đăng nhập lần đầu thêm một dòng `users`. `DELETE /me` xoá dòng đó, khoá ngoại xoá luôn các dòng `plan_records`.

### Ràng buộc áp dụng

- **#3** `JWT_SECRET`, `GOOGLE_CLIENT_ID` đọc qua `ConfigService` từ `.env`.
- **#4** ESM: đuôi `.js`.
- **#10** chỉ Google Sign-In, không lưu mật khẩu.
- **#12** JWT không chứa email hay dữ liệu sức khoẻ; log không chứa token hay email.
- **#17** test không gọi Google: `MockIdTokenVerifier`, và `GoogleIdTokenVerifier` với khoá RSA tự tạo.
- **#18** `addBearerAuth()` thêm trong `configureApp()`.

## Definition of Done

- [ ] `npm test` → `Test Files  14 passed (14)`, `Tests  120 passed (120)`
- [ ] `npm run test:e2e` → `Test Files  3 passed (3)`, `Tests  24 passed (24)`
- [ ] `NODE_ENV=production node dist/main.js` dừng ngay, in lý do có chữ `ALLOW_MOCK_AUTH`
- [ ] `AUTH_MODE=google JWT_SECRET=short GOOGLE_CLIENT_ID=abc node dist/main.js` dừng ngay, in lý do có chữ `32 ký tự`
- [ ] Không test nào gửi request ra ngoài máy
- [ ] All API routes complete within deployment timeout — mọi route < 5 ms ở chế độ mock
- [ ] Auth check at top of each protected handler — `DELETE /me` có `JwtAuthGuard`

## Test Checklist

1. **@happy**: `mock:an@vku.edu.vn` → 200, JWT 3 phần, đăng nhập lại (khác hoa thường) → cùng `user.id`; Google ID Token hợp lệ (ký bằng khoá test) → định danh đúng, email chữ thường
2. **@auth**: không header / header sai dạng / không phải JWT / JWT ký bằng secret khác / `alg: none` / thiếu `sub` → 401; `DELETE /me` rồi dùng lại token cũ → 401
3. **@timeout**: mọi route < 5 ms ở chế độ mock; chế độ google chỉ gọi mạng khi tải chứng chỉ lần đầu
4. **@partial-fail**: hai lần đăng nhập đầu tiên chạy đua → không 500, vẫn một user; cấu hình sai → không khởi động, in lý do
5. **@token**: ID Token hết hạn / sai `aud` / sai `iss` / khoá lạ / payload bị sửa / `email_verified: false` → 401; JWT hết hạn → 401; log từ chối không chứa token hay email
6. **@db**: xoá tài khoản xoá luôn plan của người đó, plan người khác còn nguyên

## Tasks

### Task 1 — Cài thư viện

```bash
cd backend_api
npm install @nestjs/jwt@^12.0.2 google-auth-library@^11.1.0
```

`google-auth-library` 11 cần Node ≥ 22 (CI dùng 24 và 26). Không cài Passport: brainstorm chọn guard tự viết (mục 4.3).

### Task 2 — Cấu hình đăng nhập: test trước

`backend_api/src/auth/auth-config.spec.ts`:

```ts
import { AuthMode, DEV_JWT_SECRET, resolveAuthConfig } from './auth-config.js';

const STRONG_SECRET = 'x'.repeat(32);
const resolve = (env: Record<string, string>) => resolveAuthConfig((key) => env[key]);

describe('resolveAuthConfig', () => {
  it('defaults to mock mode, the dev secret and a 7-day token', () => {
    const { config, warnings } = resolve({});
    expect(config).toEqual({
      mode: AuthMode.MOCK,
      jwtSecret: DEV_JWT_SECRET,
      jwtExpiresInSeconds: 7 * 86_400,
      googleClientIds: [],
    });
    expect(warnings).toHaveLength(1);
  });

  it('treats blank values as unset', () => {
    expect(resolve({ AUTH_MODE: ' ', JWT_SECRET: '', JWT_EXPIRES_IN: '' }).config.mode).toBe(AuthMode.MOCK);
  });

  it('accepts google mode with client ids and a long secret', () => {
    const { config, warnings } = resolve({
      AUTH_MODE: 'google',
      GOOGLE_CLIENT_ID: ' web.apps.googleusercontent.com , android.apps.googleusercontent.com ,',
      JWT_SECRET: STRONG_SECRET,
    });
    expect(config.googleClientIds).toEqual([
      'web.apps.googleusercontent.com',
      'android.apps.googleusercontent.com',
    ]);
    expect(config.jwtSecret).toBe(STRONG_SECRET);
    expect(warnings).toEqual([]);
  });

  it.each([
    ['an unknown mode', { AUTH_MODE: 'facebook' }, /AUTH_MODE/],
    ['google without client id', { AUTH_MODE: 'google', JWT_SECRET: STRONG_SECRET }, /GOOGLE_CLIENT_ID/],
    ['google without secret', { AUTH_MODE: 'google', GOOGLE_CLIENT_ID: 'id' }, /JWT_SECRET/],
    ['google with a short secret', { AUTH_MODE: 'google', GOOGLE_CLIENT_ID: 'id', JWT_SECRET: 'short' }, /32/],
    ['mock in production', { NODE_ENV: 'production' }, /ALLOW_MOCK_AUTH/],
    ['mock in production with a non-"true" flag', { NODE_ENV: 'production', ALLOW_MOCK_AUTH: '1' }, /ALLOW_MOCK_AUTH/],
    ['a zero duration', { JWT_EXPIRES_IN: '0d' }, /JWT_EXPIRES_IN/],
    ['a duration without unit', { JWT_EXPIRES_IN: '3600' }, /JWT_EXPIRES_IN/],
  ])('refuses to start with %s', (_label, env, message) => {
    expect(() => resolve(env)).toThrow(message);
  });

  it('allows mock mode in production only with ALLOW_MOCK_AUTH=true', () => {
    const { config, warnings } = resolve({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    expect(config.mode).toBe(AuthMode.MOCK);
    expect(warnings[0]).toMatch(/mock/);
  });

  it.each([
    ['30s', 30],
    ['15m', 900],
    ['12h', 43_200],
    ['7d', 604_800],
  ])('parses JWT_EXPIRES_IN=%s', (value, seconds) => {
    expect(resolve({ JWT_EXPIRES_IN: value }).config.jwtExpiresInSeconds).toBe(seconds);
  });
});
```

```bash
npx vitest run src/auth/auth-config.spec.ts   # đỏ: Cannot find module './auth-config.js'
```

`backend_api/src/auth/auth-config.ts`:

```ts
export enum AuthMode {
  MOCK = 'mock',
  GOOGLE = 'google',
}

export interface AuthConfig {
  mode: AuthMode;
  jwtSecret: string;
  jwtExpiresInSeconds: number;
  googleClientIds: string[];
}

export const AUTH_CONFIG = Symbol('AUTH_CONFIG');

// Chỉ dùng khi AUTH_MODE=mock mà chưa đặt JWT_SECRET. Ai đọc repo cũng biết chuỗi này,
// nhưng ở chế độ mock ai cũng đăng nhập được thành bất kỳ ai, nên secret lộ không mở thêm lỗ hổng nào.
export const DEV_JWT_SECRET = 'smartfit-dev-secret-chi-dung-cho-AUTH_MODE-mock';
export const MIN_JWT_SECRET_LENGTH = 32;
const DEFAULT_JWT_EXPIRES_IN = '7d';
const DURATION_PATTERN = /^([1-9]\d*)([smhd])$/;
const UNIT_SECONDS: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86_400 };

// Kiểm cấu hình đăng nhập lúc khởi động; ném lỗi = backend không khởi động.
export function resolveAuthConfig(env: (key: string) => string | undefined): {
  config: AuthConfig;
  warnings: string[];
} {
  const read = (key: string) => env(key)?.trim() || undefined;
  const warnings: string[] = [];

  const mode = read('AUTH_MODE') ?? AuthMode.MOCK;
  if (!isAuthMode(mode)) {
    throw new Error(`AUTH_MODE phải là "mock" hoặc "google" (đang là "${mode}").`);
  }

  const expiresIn = read('JWT_EXPIRES_IN') ?? DEFAULT_JWT_EXPIRES_IN;
  const match = DURATION_PATTERN.exec(expiresIn);
  if (!match) {
    throw new Error(`JWT_EXPIRES_IN phải có dạng <số><s|m|h|d>, ví dụ 7d (đang là "${expiresIn}").`);
  }
  const jwtExpiresInSeconds = Number(match[1]) * UNIT_SECONDS[match[2]];

  const googleClientIds = (read('GOOGLE_CLIENT_ID') ?? '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);
  let jwtSecret = read('JWT_SECRET');

  if (mode === AuthMode.GOOGLE) {
    if (googleClientIds.length === 0) {
      throw new Error('AUTH_MODE=google cần GOOGLE_CLIENT_ID — xem docs/SETUP_CREDENTIALS.md mục 2.');
    }
    if (!jwtSecret || jwtSecret.length < MIN_JWT_SECRET_LENGTH) {
      throw new Error(
        `AUTH_MODE=google cần JWT_SECRET dài ít nhất ${MIN_JWT_SECRET_LENGTH} ký tự — xem docs/SETUP_CREDENTIALS.md mục 2.`,
      );
    }
  } else {
    if (read('NODE_ENV') === 'production' && read('ALLOW_MOCK_AUTH') !== 'true') {
      throw new Error(
        'Không khởi động với AUTH_MODE=mock khi NODE_ENV=production: ai gửi "mock:<email>" cũng đăng nhập được thành người đó. ' +
          'Dùng AUTH_MODE=google, hoặc đặt ALLOW_MOCK_AUTH=true nếu cố ý chạy demo bằng đăng nhập giả lập.',
      );
    }
    warnings.push(
      'AUTH_MODE=mock: đăng nhập giả lập — ai gửi "mock:<email>" cũng đăng nhập được thành email đó. Chỉ dùng khi phát triển hoặc demo.',
    );
    jwtSecret ??= DEV_JWT_SECRET;
  }

  return { config: { mode, jwtSecret, jwtExpiresInSeconds, googleClientIds }, warnings };
}

function isAuthMode(value: string): value is AuthMode {
  return (Object.values(AuthMode) as string[]).includes(value);
}
```

```bash
npx vitest run src/auth/auth-config.spec.ts   # Tests  16 passed (16)
```

### Task 3 — Xác minh ID Token: test trước

`backend_api/src/auth/id-token-verifier.spec.ts`:

```ts
import { Logger, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import { createSign, generateKeyPairSync } from 'node:crypto';
import { GoogleIdTokenVerifier, MockIdTokenVerifier } from './id-token-verifier.js';

describe('MockIdTokenVerifier', () => {
  const verifier = new MockIdTokenVerifier();

  it('turns "mock:<email>" into a stable identity', async () => {
    await expect(verifier.verify(' mock:An.Nguyen@VKU.edu.vn ')).resolves.toEqual({
      sub: 'mock:an.nguyen@vku.edu.vn',
      email: 'an.nguyen@vku.edu.vn',
      name: 'an.nguyen',
    });
  });

  it.each(['an@vku.edu.vn', 'mock:', 'mock:khong-phai-email', 'mock:a b@vku.edu.vn', 'eyJhbGciOi.x.y'])(
    'rejects %j',
    async (token) => {
      await expect(verifier.verify(token)).rejects.toBeInstanceOf(UnauthorizedException);
    },
  );
});

// Ký token bằng khoá RSA tự tạo và thay chỗ tải chứng chỉ của Google — không gọi mạng (#17),
// nhưng phần kiểm chữ ký, hạn dùng, issuer, audience vẫn là code thật của google-auth-library.
describe('GoogleIdTokenVerifier', () => {
  const CLIENT_IDS = ['web-client.apps.googleusercontent.com', 'android-client.apps.googleusercontent.com'];
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const now = () => Math.floor(Date.now() / 1000);
  const claims = (overrides: Record<string, unknown> = {}) => ({
    iss: 'https://accounts.google.com',
    aud: CLIENT_IDS[0],
    sub: '110248495921238986420',
    email: 'An.Nguyen@gmail.com',
    email_verified: true,
    name: 'Nguyễn Văn An',
    iat: now(),
    exp: now() + 3600,
    ...overrides,
  });
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const sign = (payload: object, kid = 'test-key') => {
    const unsigned = `${encode({ alg: 'RS256', kid, typ: 'JWT' })}.${encode(payload)}`;
    return `${unsigned}.${createSign('RSA-SHA256').update(unsigned).sign(privateKey).toString('base64url')}`;
  };

  let verifier: GoogleIdTokenVerifier;

  beforeEach(() => {
    const client = new OAuth2Client();
    vi.spyOn(client, 'getFederatedSignonCertsAsync').mockResolvedValue({
      certs: { 'test-key': publicKey.export({ type: 'spki', format: 'pem' }).toString() },
    } as Awaited<ReturnType<OAuth2Client['getFederatedSignonCertsAsync']>>);
    verifier = new GoogleIdTokenVerifier(CLIENT_IDS, client);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('accepts a valid token and lowercases the email', async () => {
    await expect(verifier.verify(sign(claims()))).resolves.toEqual({
      sub: '110248495921238986420',
      email: 'an.nguyen@gmail.com',
      name: 'Nguyễn Văn An',
    });
  });

  it('accepts a token issued to any configured client id', async () => {
    await expect(verifier.verify(sign(claims({ aud: CLIENT_IDS[1] })))).resolves.toMatchObject({
      sub: '110248495921238986420',
    });
  });

  it('falls back to the email name when Google sends no name', async () => {
    await expect(verifier.verify(sign(claims({ name: undefined })))).resolves.toMatchObject({ name: 'an.nguyen' });
  });

  it.each([
    ['issued to another app', claims({ aud: 'other-app.apps.googleusercontent.com' })],
    ['expired', claims({ iat: now() - 7200, exp: now() - 3600 })],
    ['from another issuer', claims({ iss: 'https://evil.example' })],
    ['with an unverified email', claims({ email_verified: false })],
    ['without email', claims({ email: undefined })],
  ])('rejects a token %s', async (_label, payload) => {
    await expect(verifier.verify(sign(payload))).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a token signed with an unknown key', async () => {
    await expect(verifier.verify(sign(claims(), 'other-key'))).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a token with a tampered payload', async () => {
    const [header, , signature] = sign(claims()).split('.');
    const forged = `${header}.${encode(claims({ sub: 'someone-else' }))}.${signature}`;
    await expect(verifier.verify(forged)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('never logs the token or the email (NFR-7)', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const token = sign(claims({ exp: now() - 3600, iat: now() - 7200 }));
    await verifier.verify(token).catch(() => undefined);
    expect(warn).toHaveBeenCalledTimes(1);
    const logged = String(warn.mock.calls[0][0]);
    expect(logged).toContain('Token used too late');
    expect(logged).not.toContain('gmail.com');
    expect(logged).not.toContain(token.split('.')[1]);
  });

  it('refuses to be built without a client id, so the audience check can never be skipped', () => {
    expect(() => new GoogleIdTokenVerifier([])).toThrow(/Client ID/);
  });
});
```

```bash
npx vitest run src/auth/id-token-verifier.spec.ts   # đỏ: Cannot find module './id-token-verifier.js'
```

`backend_api/src/auth/id-token-verifier.ts`:

```ts
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
```

```bash
npx vitest run src/auth/id-token-verifier.spec.ts   # Tests  18 passed (18)
```

### Task 4 — `AuthService`: test trước (DB trong RAM thật, không mock repository)

`backend_api/src/auth/auth.service.spec.ts`:

```ts
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { DataSource, Repository } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';
import { MockIdTokenVerifier } from './id-token-verifier.js';

const SECRET = 'test-secret-that-is-at-least-32-chars';

describe('AuthService', () => {
  let dataSource: DataSource;
  let users: Repository<User>;
  let jwt: JwtService;
  let service: AuthService;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
    users = dataSource.getRepository(User);
    jwt = new JwtService({
      secret: SECRET,
      signOptions: { algorithm: 'HS256', expiresIn: 3600 },
      verifyOptions: { algorithms: ['HS256'] },
    });
    service = new AuthService(new MockIdTokenVerifier(), jwt, users);
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    await dataSource.destroy();
  });

  describe('loginWithGoogle', () => {
    it('creates the user on first login and reuses it afterwards', async () => {
      const first = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const second = await service.loginWithGoogle('mock:An@VKU.edu.vn');
      expect(first.user).toEqual({ id: expect.any(String), email: 'an@vku.edu.vn', name: 'an' });
      expect(second.user.id).toBe(first.user.id);
      expect(await users.count()).toBe(1);
    });

    it('puts only the user id in the token', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const payload = jwt.decode<Record<string, unknown>>(access_token);
      expect(Object.keys(payload).sort()).toEqual(['exp', 'iat', 'sub']);
      expect(payload.sub).toBe(user.id);
    });

    it('survives two first logins racing on the same account', async () => {
      const existing = await users.save(users.create({ google_sub: 'mock:an@vku.edu.vn', email: 'an@vku.edu.vn', name: 'an' }));
      // Lần tra đầu không thấy (request kia chưa ghi xong) → insert đụng khoá duy nhất → đọc lại.
      vi.spyOn(users, 'findOneBy').mockResolvedValueOnce(null);
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      expect(user.id).toBe(existing.id);
      expect(await users.count()).toBe(1);
    });

    it('rejects a token the verifier does not accept', async () => {
      await expect(service.loginWithGoogle('an@vku.edu.vn')).rejects.toBeInstanceOf(UnauthorizedException);
      expect(await users.count()).toBe(0);
    });
  });

  describe('authenticate', () => {
    it('returns the user behind a valid token', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await expect(service.authenticate(access_token)).resolves.toMatchObject({ id: user.id, email: 'an@vku.edu.vn' });
    });

    it.each([
      ['an expired token', async (userId: string) => jwt.signAsync({ sub: userId }, { expiresIn: -60 })],
      ['a token signed with another secret', async (userId: string) =>
        new JwtService({ secret: 'another-secret-another-secret-123' }).signAsync({ sub: userId })],
      ['an unsigned token (alg none)', async (userId: string) =>
        `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.${Buffer.from(JSON.stringify({ sub: userId })).toString('base64url')}.`],
      ['a token without sub', async () => jwt.signAsync({ uid: 'x' })],
      ['garbage', async () => 'not-a-jwt'],
    ])('rejects %s', async (_label, makeToken) => {
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await expect(service.authenticate(await makeToken(user.id))).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a valid token whose user no longer exists', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await users.delete({ id: user.id });
      await expect(service.authenticate(access_token)).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('deleteAccount', () => {
    it('deletes the user and every plan they saved', async () => {
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const { user: other } = await service.loginWithGoogle('mock:binh@vku.edu.vn');
      const plans = dataSource.getRepository(PlanRecord);
      const record = (id: string, userId: string) => ({
        id, user_id: userId, target_calories: 1800, plan_json: {} as PlanRecord['plan_json'], created_at: new Date(),
      });
      await plans.insert([
        record('11111111-1111-4111-8111-111111111111', user.id),
        record('22222222-2222-4222-8222-222222222222', other.id),
      ]);

      await service.deleteAccount(user.id);

      expect(await users.findOneBy({ id: user.id })).toBeNull();
      expect((await plans.find()).map((plan) => plan.user_id)).toEqual([other.id]);
    });
  });
});
```

```bash
npx vitest run src/auth/auth.service.spec.ts   # đỏ: Cannot find module './auth.service.js'
```

DTO response (service trả kiểu này):

`backend_api/src/auth/dto/auth-response.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';

export class AuthUserDto {
  @ApiProperty({ format: 'uuid' })
  id: string;

  @ApiProperty({ example: 'sv@vku.edu.vn' })
  email: string;

  @ApiProperty({ example: 'Nguyễn Văn A' })
  name: string;
}

export class AuthResponseDto {
  @ApiProperty({ description: 'JWT của SmartFit; gửi lại qua header Authorization: Bearer <access_token>' })
  access_token: string;

  @ApiProperty({ type: AuthUserDto })
  user: AuthUserDto;
}
```

`backend_api/src/auth/auth.service.ts`:

```ts
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
```

```bash
npx vitest run src/auth/auth.service.spec.ts   # Tests  12 passed (12)
```

### Task 5 — Guard: test trước

`backend_api/src/auth/jwt-auth.guard.spec.ts`:

```ts
import { extractBearerToken } from './jwt-auth.guard.js';

describe('extractBearerToken', () => {
  it.each([
    ['Bearer abc.def.ghi', 'abc.def.ghi'],
    ['bearer abc.def.ghi', 'abc.def.ghi'],
    ['Bearer   abc.def.ghi  ', 'abc.def.ghi'],
  ])('reads %j', (header, token) => {
    expect(extractBearerToken(header)).toBe(token);
  });

  it.each([undefined, '', 'Bearer', 'Bearer ', 'Basic abc', 'abc.def.ghi', 'Bearer a b'])('rejects %j', (header) => {
    expect(extractBearerToken(header)).toBeNull();
  });
});
```

```bash
npx vitest run src/auth/jwt-auth.guard.spec.ts   # đỏ: Cannot find module './jwt-auth.guard.js'
```

`backend_api/src/auth/jwt-auth.guard.ts`:

```ts
import {
  type CanActivate,
  createParamDecorator,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import type { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';

type AuthenticatedRequest = Request & { user?: User };

const BEARER_PATTERN = /^Bearer\s+(\S+)\s*$/i;

export function extractBearerToken(header: string | undefined): string | null {
  return BEARER_PATTERN.exec(header ?? '')?.[1] ?? null;
}

// Bắt buộc đăng nhập (API lịch sử, xoá tài khoản).
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = extractBearerToken(request.headers.authorization);
    if (!token) throw new UnauthorizedException('Cần đăng nhập (header Authorization: Bearer <access_token>).');
    request.user = await this.auth.authenticate(token);
    return true;
  }
}

// Đăng nhập tuỳ chọn (generate-plan, BRD FR-7): không gửi header → chạy như khách;
// có gửi mà sai → 401, để app biết phải đăng nhập lại thay vì âm thầm không lưu lịch sử.
@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (header === undefined) return true;
    const token = extractBearerToken(header);
    if (!token) throw new UnauthorizedException('Header Authorization phải có dạng "Bearer <access_token>".');
    request.user = await this.auth.authenticate(token);
    return true;
  }
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): User | undefined =>
    context.switchToHttp().getRequest<AuthenticatedRequest>().user,
);
```

```bash
npx vitest run src/auth/jwt-auth.guard.spec.ts   # Tests  10 passed (10)
```

### Task 6 — Controller, module

`backend_api/src/auth/dto/google-login.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class GoogleLoginDto {
  @ApiProperty({
    description: 'Google ID Token lấy từ google_sign_in. Chế độ AUTH_MODE=mock nhận "mock:<email>".',
    example: 'mock:sv@vku.edu.vn',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  id_token: string;
}
```

`backend_api/src/auth/auth.controller.ts`:

```ts
import { Body, Controller, Delete, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import type { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';
import { AuthResponseDto } from './dto/auth-response.dto.js';
import { GoogleLoginDto } from './dto/google-login.dto.js';
import { CurrentUser, JwtAuthGuard } from './jwt-auth.guard.js';

@ApiTags('auth')
@Controller('api/v1')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/google')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi Google ID Token lấy JWT của SmartFit (BRD FR-6)' })
  @ApiOkResponse({ type: AuthResponseDto })
  @ApiUnauthorizedResponse({ description: 'ID Token không xác minh được' })
  login(@Body() dto: GoogleLoginDto): Promise<AuthResponseDto> {
    return this.auth.loginWithGoogle(dto.id_token);
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Xoá tài khoản và toàn bộ lịch sử kế hoạch (BRD FR-6.4)' })
  @ApiNoContentResponse({ description: 'Đã xoá' })
  @ApiUnauthorizedResponse({ description: 'Chưa đăng nhập hoặc token sai' })
  async deleteAccount(@CurrentUser() user: User): Promise<void> {
    await this.auth.deleteAccount(user.id);
  }
}
```

`JwtService` được tạo bằng factory từ `AUTH_CONFIG`, không dùng `JwtModule.registerAsync`. Làm vậy thì secret và thời hạn đi đúng một đường: `resolveAuthConfig()`.

`backend_api/src/auth/auth.module.ts`:

```ts
import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity.js';
import { AUTH_CONFIG, type AuthConfig, AuthMode, resolveAuthConfig } from './auth-config.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { GoogleIdTokenVerifier, IdTokenVerifier, MockIdTokenVerifier } from './id-token-verifier.js';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [AuthController],
  providers: [
    {
      provide: AUTH_CONFIG,
      inject: [ConfigService],
      useFactory: (config: ConfigService): AuthConfig => {
        const { config: authConfig, warnings } = resolveAuthConfig((key) => config.get<string>(key));
        const logger = new Logger('AuthConfig');
        for (const warning of warnings) logger.warn(warning);
        return authConfig;
      },
    },
    {
      provide: JwtService,
      inject: [AUTH_CONFIG],
      useFactory: (config: AuthConfig) =>
        new JwtService({
          secret: config.jwtSecret,
          signOptions: { algorithm: 'HS256', expiresIn: config.jwtExpiresInSeconds },
          verifyOptions: { algorithms: ['HS256'] },
        }),
    },
    {
      provide: IdTokenVerifier,
      inject: [AUTH_CONFIG],
      useFactory: (config: AuthConfig): IdTokenVerifier =>
        config.mode === AuthMode.GOOGLE
          ? new GoogleIdTokenVerifier(config.googleClientIds)
          : new MockIdTokenVerifier(),
    },
    AuthService,
  ],
  exports: [AUTH_CONFIG, AuthService],
})
export class AuthModule {}
```

### Task 7 — Nối vào app: `/health`, Swagger, `AppModule`

`backend_api/src/app.service.ts`:

```ts
import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AUTH_CONFIG, type AuthConfig, type AuthMode } from './auth/auth-config.js';

export interface HealthStatus {
  status: 'ok';
  gemini: 'configured' | 'fallback';
  auth_mode: AuthMode;
}

@Injectable()
export class AppService {
  constructor(
    private readonly config: ConfigService,
    @Inject(AUTH_CONFIG) private readonly auth: AuthConfig,
  ) {}

  getHealth(): HealthStatus {
    return {
      status: 'ok',
      gemini: this.config.get<string>('GEMINI_API_KEY') ? 'configured' : 'fallback',
      auth_mode: this.auth.mode,
    };
  }
}
```

`backend_api/src/app.controller.ts` — chỉ sửa mô tả của `@ApiOkResponse`:

```ts
  @ApiOkResponse({
    description:
      'gemini = "configured" khi đã có GEMINI_API_KEY, "fallback" khi đang dùng dữ liệu mẫu; ' +
      'auth_mode = "mock" (đăng nhập giả lập) hoặc "google"',
  })
```

`backend_api/src/app.setup.ts` — thêm `.addBearerAuth()`:

```ts
  const config = new DocumentBuilder()
    .setTitle('SmartFit AI API')
    .setDescription('Backend API cho SmartFit AI — xem BRD.md ở repo gốc')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
```

`backend_api/src/app.module.ts` (bản của F02):

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { DatabaseModule } from './database/database.module.js';
import { PlanModule } from './plan/plan.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), DatabaseModule, AuthModule, PlanModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
```

`backend_api/src/app.controller.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AUTH_CONFIG, AuthMode } from './auth/auth-config.js';

async function createController(env: Record<string, string | undefined>) {
  const app: TestingModule = await Test.createTestingModule({
    controllers: [AppController],
    providers: [
      AppService,
      { provide: ConfigService, useValue: { get: (key: string) => env[key] } },
      { provide: AUTH_CONFIG, useValue: { mode: AuthMode.MOCK } },
    ],
  }).compile();

  return app.get<AppController>(AppController);
}

describe('AppController', () => {
  describe('health', () => {
    it('reports gemini fallback when GEMINI_API_KEY is unset', async () => {
      const controller = await createController({});
      expect(controller.getHealth()).toEqual({ status: 'ok', gemini: 'fallback', auth_mode: 'mock' });
    });

    it('reports gemini configured when GEMINI_API_KEY is set', async () => {
      const controller = await createController({ GEMINI_API_KEY: 'test-key' });
      expect(controller.getHealth()).toEqual({ status: 'ok', gemini: 'configured', auth_mode: 'mock' });
    });
  });
});
```

`backend_api/test/app.e2e-spec.ts`:

```ts
import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

describe('AppController (e2e)', () => {
  let testApp: TestApp;

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('/health (GET)', async () => {
    const res = await request(testApp.app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toEqual({ status: 'ok', gemini: 'fallback', auth_mode: 'mock' });
  });
});
```

### Task 8 — E2E đăng nhập

`backend_api/test/auth.e2e-spec.ts`:

```ts
import request from 'supertest';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

describe('Đăng nhập & tài khoản (e2e, AUTH_MODE=mock, DB trong RAM)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('logs in with a mock token and returns the same account next time', async () => {
    const first = await loginMock(testApp, 'an@vku.edu.vn');
    expect(first.user).toEqual({ id: expect.stringMatching(UUID), email: 'an@vku.edu.vn', name: 'an' });
    expect(first.access_token.split('.')).toHaveLength(3);
    const second = await loginMock(testApp, 'AN@vku.edu.vn');
    expect(second.user.id).toBe(first.user.id);
  });

  it.each([
    [400, 'without id_token', {}],
    [400, 'with a non-string id_token', { id_token: 123 }],
    [401, 'with a token that is not "mock:<email>"', { id_token: 'an@vku.edu.vn' }],
  ])('answers %i to a login %s', async (status, _label, payload) => {
    await http().post('/api/v1/auth/google').send(payload).expect(status);
  });

  it('deletes the account; the old token stops working and the next login is a new account', async () => {
    const { access_token, user } = await loginMock(testApp, 'xoa@vku.edu.vn');
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(204);
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(401);
    const again = await loginMock(testApp, 'xoa@vku.edu.vn');
    expect(again.user.id).not.toBe(user.id);
  });

  it.each([
    ['no header', undefined],
    ['a malformed header', 'Token abc'],
    ['a token that is not a JWT', 'Bearer not-a-jwt'],
  ])('refuses to delete an account with %s', async (_label, header) => {
    const req = http().delete('/api/v1/me');
    if (header) req.set('Authorization', header);
    await req.expect(401);
  });

  it('documents login and account deletion in Swagger with bearer auth', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(expect.arrayContaining(['/api/v1/auth/google', '/api/v1/me']));
    expect(body.components.securitySchemes).toHaveProperty('bearer');
  });
});

describe('Cấu hình đăng nhập lúc khởi động (e2e)', () => {
  it('refuses to start with AUTH_MODE=mock in production', async () => {
    await expect(createTestApp({ NODE_ENV: 'production' })).rejects.toThrow(/ALLOW_MOCK_AUTH/);
  });

  it('starts in production with mock auth only when ALLOW_MOCK_AUTH=true', async () => {
    const testApp = await createTestApp({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    try {
      const { body } = await request(testApp.app.getHttpServer()).get('/health').expect(200);
      expect(body.auth_mode).toBe('mock');
    } finally {
      await testApp.close();
    }
  });

  it('refuses to start in google mode without GOOGLE_CLIENT_ID', async () => {
    await expect(createTestApp({ AUTH_MODE: 'google', JWT_SECRET: 'x'.repeat(32) })).rejects.toThrow(
      /GOOGLE_CLIENT_ID/,
    );
  });
});
```

### Task 9 — `.env.example`

Thêm vào cuối `backend_api/.env.example`:

```
# Đăng nhập — xem docs/SETUP_CREDENTIALS.md mục 2.
# mock = giả lập: id_token là "mock:<email>", không cần Google. google = Google Sign-In thật.
AUTH_MODE=mock
# Bắt buộc khi AUTH_MODE=google. Nhiều Client ID (web/Android/iOS) cách nhau dấu phẩy.
GOOGLE_CLIENT_ID=
# Khoá ký JWT. Bắt buộc khi AUTH_MODE=google, ít nhất 32 ký tự: openssl rand -base64 48
JWT_SECRET=
JWT_EXPIRES_IN=7d
# Backend không khởi động khi NODE_ENV=production mà AUTH_MODE=mock. Chỉ đặt true khi cố ý deploy bản demo giả lập.
ALLOW_MOCK_AUTH=
```

### Task 10 — Cổng kiểm tra F02

```bash
cd backend_api
npm run build
npm test                 # Test Files  14 passed (14) · Tests  120 passed (120)
npm run test:e2e         # Test Files  3 passed (3) · Tests  24 passed (24)
NODE_ENV=production PORT=3999 DATABASE_PATH=':memory:' node dist/main.js; echo "exit=$?"
# → ERROR … Không khởi động với AUTH_MODE=mock khi NODE_ENV=production … ALLOW_MOCK_AUTH=true … / exit=1
PORT=3999 DATABASE_PATH=':memory:' node dist/main.js &
sleep 3
curl -s localhost:3999/health                                   # … "auth_mode":"mock"
curl -s -X POST localhost:3999/api/v1/auth/google -H 'content-type: application/json' \
  -d '{"id_token":"mock:sv@vku.edu.vn"}'                         # {"access_token":"eyJ…","user":{…}}
kill %1
```
