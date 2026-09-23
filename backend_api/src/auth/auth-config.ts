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
