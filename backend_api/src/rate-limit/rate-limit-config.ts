// Giới hạn tần suất cho các endpoint có thể gọi Gemini mà không cần đăng nhập (PLAN 9.7, quyết định Q2 giai đoạn 9):
// gói miễn phí của Gemini chỉ 20 lượt/ngày (#9) — không giới hạn thì một người tiêu hết lượt của mọi người.
export interface RateLimit {
  limit: number;
  ttlMs: number;
}

export interface RateLimitConfig {
  // generate-plan
  plan: RateLimit | null;
  // đổi món, đổi bài, feedback — dùng chung một hạn mức
  adjust: RateLimit | null;
  // đăng nhập trang quản trị — chống dò mật khẩu (giai đoạn 10)
  admin: RateLimit | null;
  // Số proxy đứng trước app mà ta tin `X-Forwarded-For` của chúng: 0 khi chạy máy, 1 trên Vercel (Vercel ghi đè
  // header này bằng IP thật). Đặt cao hơn thực tế → người gọi tự ghi X-Forwarded-For là đổi được IP.
  trustProxyHops: number;
}

const DEFAULT_PLAN = '5/10m';
const DEFAULT_ADJUST = '30/10m';
const DEFAULT_ADMIN = '5/15m';
const LIMIT_PATTERN = /^([1-9]\d*)\/([1-9]\d*)([smhd])$/;
const UNIT_MS: Record<string, number> = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 };

function parseLimit(key: string, value: string): RateLimit | null {
  if (value === 'off') return null;
  const match = LIMIT_PATTERN.exec(value);
  if (!match) {
    throw new Error(`${key} phải có dạng <số lần>/<số><s|m|h|d> (ví dụ ${DEFAULT_PLAN}) hoặc off (đang là "${value}").`);
  }
  return { limit: Number(match[1]), ttlMs: Number(match[2]) * UNIT_MS[match[3]] };
}

// Sai cấu hình → ném lỗi, backend không khởi động (như CORS_ORIGINS, AUTH_MODE).
export function resolveRateLimitConfig(env: (key: string) => string | undefined): RateLimitConfig {
  const read = (key: string, fallback: string) => env(key)?.trim() || fallback;
  const hops = read('TRUST_PROXY_HOPS', '0');
  if (!/^\d$/.test(hops)) throw new Error(`TRUST_PROXY_HOPS phải là số proxy từ 0 tới 9 (đang là "${hops}").`);
  return {
    plan: parseLimit('RATE_LIMIT_PLAN', read('RATE_LIMIT_PLAN', DEFAULT_PLAN)),
    adjust: parseLimit('RATE_LIMIT_ADJUST', read('RATE_LIMIT_ADJUST', DEFAULT_ADJUST)),
    admin: parseLimit('RATE_LIMIT_ADMIN', read('RATE_LIMIT_ADMIN', DEFAULT_ADMIN)),
    trustProxyHops: Number(hops),
  };
}

// Token DI cho RateLimitConfig (RateLimitModule) — interface không dùng làm token được.
export const RATE_LIMIT_CONFIG = Symbol('RATE_LIMIT_CONFIG');
