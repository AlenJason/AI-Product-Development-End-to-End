import { randomBytes, scrypt as scryptCallback, type ScryptOptions, timingSafeEqual } from 'node:crypto';

// Mật khẩu Admin (giai đoạn 10, quyết định Q1): chỉ lưu dạng băm scrypt trong biến môi trường ADMIN_PASSWORD_HASH —
// không trong repo, không trong DB. scrypt cố ý chậm và tốn bộ nhớ (~32 MB mỗi lần) để dò ngược mã băm thật đắt.
// Định dạng: scrypt$<N>$<r>$<p>$<salt base64url>$<băm base64url>.
const SCRYPT_N = 2 ** 15;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LENGTH = 32;
const SALT_BYTES = 16;
export const MIN_ADMIN_PASSWORD_LENGTH = 12;
const HASH_PATTERN = /^scrypt\$(\d+)\$(\d+)\$(\d+)\$([A-Za-z0-9_-]{22,})\$([A-Za-z0-9_-]{43})$/;

export interface AdminPasswordHash {
  N: number;
  r: number;
  p: number;
  salt: Buffer;
  key: Buffer;
}

function scrypt(password: string, salt: Buffer, options: { N: number; r: number; p: number }): Promise<Buffer> {
  // maxmem phải lớn hơn 128 × N × r (mặc định của Node chỉ 32 MB — vừa sát mức N = 2^15).
  const scryptOptions: ScryptOptions = { ...options, maxmem: 256 * options.N * options.r };
  return new Promise((resolve, reject) =>
    scryptCallback(password.normalize('NFC'), salt, KEY_LENGTH, scryptOptions, (error, key) => (error ? reject(error) : resolve(key))),
  );
}

export async function hashAdminPassword(password: string, salt: Buffer = randomBytes(SALT_BYTES)): Promise<string> {
  const key = await scrypt(password, salt, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P });
  return ['scrypt', SCRYPT_N, SCRYPT_R, SCRYPT_P, salt.toString('base64url'), key.toString('base64url')].join('$');
}

// null khi sai định dạng hoặc tham số yếu hơn mức tối thiểu — resolveAdminConfig() khi đó không cho khởi động.
export function parseAdminPasswordHash(value: string): AdminPasswordHash | null {
  const match = HASH_PATTERN.exec(value.trim());
  if (!match) return null;
  const [N, r, p] = [match[1], match[2], match[3]].map(Number);
  const isPowerOfTwo = (n: number) => n > 1 && (n & (n - 1)) === 0;
  if (!isPowerOfTwo(N) || N < 2 ** 14 || N > 2 ** 20 || r < 8 || r > 32 || p < 1 || p > 4) return null;
  const salt = Buffer.from(match[4], 'base64url');
  const key = Buffer.from(match[5], 'base64url');
  if (salt.length < SALT_BYTES || key.length !== KEY_LENGTH) return null;
  return { N, r, p, salt, key };
}

// So sánh thời gian hằng — thời gian trả lời không cho biết mật khẩu đúng được bao nhiêu ký tự.
export async function verifyAdminPassword(password: string, hash: AdminPasswordHash): Promise<boolean> {
  const key = await scrypt(password, hash.salt, hash);
  return timingSafeEqual(key, hash.key);
}
