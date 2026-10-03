import { type AdminPasswordHash, parseAdminPasswordHash } from './admin-password.js';

// Một tài khoản Admin cấp sẵn (giai đoạn 10, quyết định Q1, Q2) — chỉ để xem trang thống kê ẩn danh.
export interface AdminConfig {
  username: string;
  // Chuỗi gốc (để sinh khoá ký token: đổi mật khẩu là token cũ mất hiệu lực) và bản đã tách tham số.
  passwordHashText: string;
  passwordHash: AdminPasswordHash;
  tokenTtlSeconds: number;
}

export const ADMIN_CONFIG = Symbol('ADMIN_CONFIG');

const USERNAME_PATTERN = /^[A-Za-z0-9._-]{3,64}$/;
const DEFAULT_TOKEN_TTL = '8h';
const MAX_TOKEN_TTL_SECONDS = 86_400;
const DURATION_PATTERN = /^([1-9]\d*)([smhd])$/;
const UNIT_SECONDS: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86_400 };

// Không đặt ADMIN_USERNAME lẫn ADMIN_PASSWORD_HASH → null: trang Admin tắt, app vẫn chạy. Đặt nửa vời hay sai định
// dạng → ném lỗi, backend không khởi động (như resolveAuthConfig()). Lỗi không bao giờ chép giá trị mã băm.
export function resolveAdminConfig(env: (key: string) => string | undefined): AdminConfig | null {
  const read = (key: string) => env(key)?.trim() || undefined;
  const username = read('ADMIN_USERNAME');
  const passwordHashText = read('ADMIN_PASSWORD_HASH');
  if (!username && !passwordHashText) return null;
  if (!username || !passwordHashText) {
    throw new Error('Trang Admin cần cả ADMIN_USERNAME lẫn ADMIN_PASSWORD_HASH (hoặc bỏ trống cả hai để tắt).');
  }
  if (!USERNAME_PATTERN.test(username)) {
    throw new Error('ADMIN_USERNAME chỉ gồm chữ không dấu, số, dấu chấm, gạch ngang, gạch dưới; dài 3–64 ký tự.');
  }
  const passwordHash = parseAdminPasswordHash(passwordHashText);
  if (!passwordHash) {
    throw new Error('ADMIN_PASSWORD_HASH sai định dạng — tạo bằng: npm run build && npm run admin:hash');
  }
  const ttl = read('ADMIN_TOKEN_TTL') ?? DEFAULT_TOKEN_TTL;
  const match = DURATION_PATTERN.exec(ttl);
  const tokenTtlSeconds = match ? Number(match[1]) * UNIT_SECONDS[match[2]] : 0;
  if (!match || tokenTtlSeconds > MAX_TOKEN_TTL_SECONDS) {
    throw new Error(`ADMIN_TOKEN_TTL phải có dạng <số><s|m|h|d>, tối đa 1 ngày (đang là "${ttl}").`);
  }
  return { username, passwordHashText, passwordHash, tokenTtlSeconds };
}
